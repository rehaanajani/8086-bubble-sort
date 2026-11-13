"""End-to-end tests for src/BUBBLE.ASM.

1. Translate the MASM source to NASM (tests/masm2nasm.py).
2. Assemble with `nasm -f bin` using `cpu 8086`, which rejects any
   instruction newer than the 8086 and any out-of-range short jump.
3. Run the .COM image in the Unicorn CPU emulator (16-bit real mode),
   servicing the INT 21h / INT 10h calls the program makes.
4. Compare the printed arrays and statistics with a Python reference.

Run:  pip install unicorn  &&  python3 tests/test_bubble.py
"""
import os
import random
import re
import subprocess
import sys
import tempfile

from unicorn import Uc, UcError, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn.x86_const import (UC_X86_REG_AX, UC_X86_REG_DX, UC_X86_REG_CS,
                               UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS,
                               UC_X86_REG_SP)

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from masm2nasm import translate  # noqa: E402

SRC = os.path.join(HERE, "..", "src", "BUBBLE.ASM")
SAMPLE = [0xF2A1, 0x0034, 0x9C40, 0x1234, 0xFFFF, 0x0000, 0x7D00, 0x2710,
          0x03E8, 0x8000, 0xABCD, 0x0001, 0x4E20, 0xC350, 0x0063, 0x5A5A,
          0x1388, 0xEA60, 0x00FF, 0x3039]
SEG, BASE = 0x1000, 0x10000


def build():
    tmp = tempfile.mkdtemp()
    asm, com = os.path.join(tmp, "b.asm"), os.path.join(tmp, "b.com")
    open(asm, "w").write(translate(open(SRC).read()))
    subprocess.run(["nasm", "-f", "bin", "-o", com, asm], check=True)
    return open(com, "rb").read()


def run(image, keys):
    keys = list(keys)
    out, state = [], {"done": False, "beeps": 0}
    mu = Uc(UC_ARCH_X86, UC_MODE_16)
    mu.mem_map(0, 0x100000)
    mu.mem_write(BASE + 0x100, image)
    for r in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS):
        mu.reg_write(r, SEG)
    mu.reg_write(UC_X86_REG_SP, 0xFFFE)

    def on_int(uc, intno, _):
        ax = uc.reg_read(UC_X86_REG_AX)
        ah = ax >> 8
        if intno == 0x10:
            out.append("\f")                      # screen cleared
            return
        if intno != 0x21:
            raise RuntimeError(f"unexpected INT {intno:02X}h")
        if ah == 0x09:
            p = BASE + uc.reg_read(UC_X86_REG_DX)
            s = bytearray()
            while (b := uc.mem_read(p, 1)[0]) != ord("$"):
                s.append(b)
                p += 1
            out.append(s.decode("ascii"))
        elif ah == 0x02:
            ch = uc.reg_read(UC_X86_REG_DX) & 0xFF
            if ch == 7:
                state["beeps"] += 1
            else:
                out.append(chr(ch))
            uc.reg_write(UC_X86_REG_AX, (ax & 0xFF00) | ch)
        elif ah == 0x08:
            if not keys:
                raise RuntimeError("program waited for more input than given")
            uc.reg_write(UC_X86_REG_AX, (ax & 0xFF00) | ord(keys.pop(0)))
        elif ah == 0x4C:
            state["done"] = True
            uc.emu_stop()
        else:
            raise RuntimeError(f"unexpected INT 21h AH={ah:02X}h")

    mu.hook_add(UC_HOOK_INTR, on_int)
    try:
        mu.emu_start(BASE + 0x100, 0, count=5_000_000)
    except UcError as e:
        raise RuntimeError(f"CPU fault: {e}")
    assert state["done"], "program did not exit through INT 21h/4Ch"
    assert not keys, f"unused keys left: {keys!r}"
    return "".join(out), state["beeps"]


def reference(a):
    a, n = list(a), len(a)
    passes = comps = swaps = 0
    cx = n - 1
    while True:
        passes += 1
        swapped = False
        for j in range(cx):
            comps += 1
            if a[j] > a[j + 1]:
                a[j], a[j + 1] = a[j + 1], a[j]
                swaps += 1
                swapped = True
        cx -= 1
        if not swapped or cx == 0:
            return a, passes, comps, swaps


def parse(screen):
    screen = screen.split("\f")[-1]               # text after the last CLS
    def block(title):
        part = screen.split(title, 1)[1]
        dec = part.split("DEC :", 1)[1].split("HEX :", 1)[0]
        hx = part.split("HEX :", 1)[1].split("\r\n\r\n", 1)[0]
        return ([int(t) for t in dec.split()],
                [int(t[:-1], 16) for t in hx.split()])
    stat = lambda k: int(re.search(k + r"\s*:\s*(\d+)", screen).group(1))
    return (block("BEFORE SORTING"), block("AFTER SORTING"),
            stat("Passes"), stat("Comparisons"), stat("Swaps"),
            "array is in ascending order" in screen)


def check(image, data, keys, label):
    screen, beeps = run(image, keys)
    (bd, bh), (ad, ah), p, c, s, ok = parse(screen)
    exp, ep, ec, es = reference(data)
    assert bd == list(data) and bh == list(data), f"{label}: before differs"
    assert ad == exp and ah == exp, f"{label}: after differs\n{ad}\n{exp}"
    assert (p, c, s) == (ep, ec, es), f"{label}: stats {(p, c, s)} != {(ep, ec, es)}"
    assert ok, f"{label}: verification line missing"
    return screen, beeps, (p, c, s)


def typed(nums):
    return "2" + "".join(f"{v}\r" for v in nums) + " "


def main():
    image = build()
    print(f"assembled OK for cpu 8086: {len(image)} bytes")

    screen, _, st = check(image, SAMPLE, "1 ", "built-in sample")
    print(f"PASS built-in sample            passes/comps/swaps = {st}")
    print(screen.split("\f")[-1].replace("\r", ""))

    cases = {
        "already sorted": sorted(SAMPLE),
        "reverse sorted": sorted(SAMPLE, reverse=True),
        "all equal": [4242] * 20,
        "zeros and maxima": [0, 65535] * 10,
        "signed trap 7FFF/8000": [0x8000, 0x7FFF] * 10,
    }
    for name, data in cases.items():
        _, _, st = check(image, data, typed(data), name)
        print(f"PASS {name:<26} passes/comps/swaps = {st}")

    # keyboard editing: letter refused, backspace, overflow refused, empty ENTER refused
    data = [65535] + SAMPLE[1:]
    keys = "2" + "\rx65535\b5\r" + "".join(f"{v}\r" for v in SAMPLE[1:]) + " "
    _, beeps, _ = check(image, data, keys, "editing keys")
    assert beeps == 2, f"expected 2 beeps (empty ENTER, 'x'), got {beeps}"
    keys = "2" + "6553" + "6" + "5\r" + "".join(f"{v}\r" for v in SAMPLE[1:]) + " "
    _, beeps, _ = check(image, data, keys, "overflow digit")
    assert beeps == 1, f"expected 1 beep for 65536, got {beeps}"
    print("PASS keyboard input: bad key, backspace, overflow and empty ENTER")

    rng = random.Random(8086)
    for i in range(300):
        data = [rng.choice([rng.randrange(65536), rng.randrange(16), 65535 - rng.randrange(16)])
                for _ in range(20)]
        check(image, data, typed(data), f"random #{i}")
    print("PASS 300 random arrays")
    print("ALL TESTS PASSED")


if __name__ == "__main__":
    main()
