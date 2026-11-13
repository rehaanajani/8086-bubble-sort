"""Translate src/BUBBLE.ASM (MASM syntax, small model) into an equivalent
NASM .COM program so it can be assembled on Linux with `nasm -f bin`.

Only the MASM constructs used by BUBBLE.ASM are handled. The translation is
mechanical, so testing the NASM output tests the logic of the MASM source.
"""
import re
import sys

WORD_VARS = {"PASSES", "COMPS", "SWAPS"}


def strip_comment(line):
    out, q = [], None
    for ch in line:
        if q:
            out.append(ch)
            if ch == q:
                q = None
        elif ch in "'\"":
            q = ch
            out.append(ch)
        elif ch == ";":
            break
        else:
            out.append(ch)
    return "".join(out).rstrip()


def translate(src):
    data, code, section = [], [], None
    for raw in src.splitlines():
        line = strip_comment(raw)
        s = line.strip()
        u = s.upper()
        if not s:
            continue
        if u.startswith((".MODEL", ".STACK")) or u.startswith("END "):
            continue
        if u == ".DATA":
            section = data
            continue
        if u == ".CODE":
            section = code
            continue
        m = re.match(r"^(\w+)\s+PROC\b", s, re.I)
        if m:
            section.append(f"{m.group(1)}:")
            continue
        if re.match(r"^\w+\s+ENDP\b", s, re.I):
            continue
        # data label without colon:  NAME  DW/DB ...
        m = re.match(r"^(\w+)\s+(DW|DB)\b(.*)$", s, re.I)
        if m:
            section.append(f"{m.group(1)}: {m.group(2)}{m.group(3)}")
            continue
        s = re.sub(r"MOV\s+AX\s*,\s*@DATA", "MOV AX, DS", s, flags=re.I)
        s = re.sub(r"\bOFFSET\s+(\w+)", r"\1", s, flags=re.I)
        s = re.sub(r"\bLEA\s+(\w+)\s*,\s*(\w+)\s*$", r"LEA \1, [\2]", s, flags=re.I)
        for v in WORD_VARS:
            s = re.sub(rf"\bINC\s+{v}\b", f"INC WORD [{v}]", s, flags=re.I)
            s = re.sub(rf",\s*{v}\b", f", [{v}]", s, flags=re.I)
        section.append(s)
    head = ["bits 16", "cpu 8086", "org 100h", "JMP MAIN"]
    return "\n".join(head + code + data) + "\n"


if __name__ == "__main__":
    src = open(sys.argv[1], encoding="ascii").read()
    open(sys.argv[2], "w").write(translate(src))
