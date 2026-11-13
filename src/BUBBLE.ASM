;=======================================================================
;  FILE      : BUBBLE.ASM
;  AIM       : Sort an array of twenty 16-bit UNSIGNED numbers in
;              ascending order using the Bubble Sort algorithm.
;  PROCESSOR : Intel 8086 (real mode), MS-DOS INT 21h services
;
;  HOW TO RUN
;     MASM    :  MASM BUBBLE.ASM;     LINK BUBBLE.OBJ;     BUBBLE
;     TASM    :  TASM BUBBLE.ASM      TLINK BUBBLE.OBJ     BUBBLE
;     emu8086 :  File > Open BUBBLE.ASM > Emulate > Run
;
;  At start-up the program asks for a data source:
;     [1] the 20 built-in sample numbers (declared in ARR below)
;     [2] 20 numbers typed at the keyboard (0 .. 65535, decimal)
;  It then prints the array before and after sorting (decimal + hex),
;  the number of passes, comparisons and swaps, and checks the result.
;-----------------------------------------------------------------------
;  REGISTER USAGE INSIDE BUBBLE_SORT
;     CX : number of comparisons in the current pass (outer counter)
;     DX : inner loop counter
;     SI : pointer to ARR[j]
;     AX : holds ARR[j] during the compare / swap
;     BL : swap flag for the pass (0 at the end = already sorted)
;-----------------------------------------------------------------------
;  WHY JBE AND NOT JLE ?
;     The data is UNSIGNED. After CMP, JBE/JA look at CF and ZF, which
;     is the unsigned comparison. JLE/JG look at SF and OF (signed) and
;     would treat 8000h..FFFFh as negative numbers, giving wrong order.
;=======================================================================

.MODEL SMALL
.STACK 100H

.DATA
N           EQU 20                      ; number of elements

; ---- the array : 20 words (16-bit unsigned) --------------------------
ARR         DW 0F2A1H, 0034H, 9C40H, 1234H, 0FFFFH
            DW 0000H,  7D00H, 2710H, 03E8H, 8000H
            DW 0ABCDH, 0001H, 4E20H, 0C350H, 0063H
            DW 5A5AH,  1388H, 0EA60H, 00FFH, 3039H

; ---- statistics collected while sorting ------------------------------
PASSES      DW 0                        ; outer-loop passes executed
COMPS       DW 0                        ; CMP instructions on elements
SWAPS       DW 0                        ; exchanges performed

; ---- messages ('$' terminated for INT 21h / AH = 09h) ---------------
MSG_HEAD    DB ' ==============================================================',13,10
            DB '   BUBBLE SORT  :  20 UNSIGNED 16-BIT NUMBERS  (ASCENDING)',13,10
            DB '   Intel 8086 Assembly                         MASM / TASM',13,10
            DB ' ==============================================================',13,10,'$'
MSG_MENU    DB 13,10,'   [1] Use the 20 built-in sample numbers'
            DB 13,10,'   [2] Enter 20 numbers from the keyboard'
            DB 13,10,13,10,'   Choice : $'
MSG_ENTER   DB 13,10,13,10,'   Type each number (0 - 65535) and press ENTER.'
            DB 13,10,'   BACKSPACE corrects a digit.',13,10,'$'
MSG_NUM     DB 13,10,'   Number $'
MSG_COLON   DB ' : $'
MSG_BS      DB 8,' ',8,'$'
MSG_BEFORE  DB 13,10,'  BEFORE SORTING$'
MSG_AFTER   DB 13,10,13,10,'  AFTER SORTING (ASCENDING)$'
MSG_DEC     DB 13,10,'   DEC :$'
MSG_HEX     DB 13,10,'   HEX :$'
MSG_INDENT  DB 13,10,'        $'
MSG_STATS   DB 13,10,13,10,'  STATISTICS$'
MSG_PASS    DB 13,10,'   Passes       : $'
MSG_COMP    DB 13,10,'   Comparisons  : $'
MSG_SWAP    DB 13,10,'   Swaps        : $'
MSG_CHECK   DB 13,10,'   Verification : $'
MSG_OK      DB 'array is in ascending order$'
MSG_FAIL    DB 'ERROR - array is NOT sorted$'
MSG_EXIT    DB 13,10,13,10,'  Press any key to exit...$'

.CODE
;=======================================================================
; MAIN : program entry point
;=======================================================================
MAIN PROC
            MOV  AX, @DATA
            MOV  DS, AX                 ; DS -> data segment

            CALL CLS
            LEA  DX, MSG_HEAD
            CALL PUTS
            LEA  DX, MSG_MENU
            CALL PUTS

GET_CHOICE: MOV  AH, 08H                ; read key, no echo
            INT  21H
            CMP  AL, '1'
            JE   USE_SAMPLE
            CMP  AL, '2'
            JNE  GET_CHOICE             ; ignore any other key

            MOV  DL, AL                 ; echo '2'
            CALL PUTC
            CALL READ_ARRAY             ; fill ARR from keyboard
            JMP  SHOW

USE_SAMPLE: MOV  DL, AL                 ; echo '1'
            CALL PUTC

SHOW:       CALL CLS
            LEA  DX, MSG_HEAD
            CALL PUTS

            LEA  DX, MSG_BEFORE
            CALL PUTS
            CALL SHOW_ARRAY             ; original order

            CALL BUBBLE_SORT            ; ---- the sort ----

            LEA  DX, MSG_AFTER
            CALL PUTS
            CALL SHOW_ARRAY             ; sorted order

            CALL SHOW_STATS

            LEA  DX, MSG_EXIT
            CALL PUTS
            MOV  AH, 08H                ; wait for a key
            INT  21H

            MOV  AH, 4CH                ; terminate, return to DOS
            INT  21H
MAIN ENDP

;=======================================================================
; BUBBLE_SORT : sorts ARR (N words, unsigned) in ascending order.
;   Pass k compares ARR[0..N-k]: after each pass the largest remaining
;   value has "bubbled" to the end, so each pass is one comparison
;   shorter. If a pass makes no swap the array is sorted and we stop.
;=======================================================================
BUBBLE_SORT PROC
            PUSH AX
            PUSH BX
            PUSH CX
            PUSH DX
            PUSH SI

            MOV  CX, N-1                ; first pass: N-1 comparisons

OUTER:      MOV  SI, OFFSET ARR         ; j = 0
            MOV  DX, CX                 ; inner counter = CX
            XOR  BL, BL                 ; swapped = 0
            INC  PASSES

INNER:      MOV  AX, [SI]               ; AX = ARR[j]
            INC  COMPS
            CMP  AX, [SI+2]             ; compare with ARR[j+1]
            JBE  NO_SWAP                ; unsigned: ARR[j] <= ARR[j+1]

            XCHG AX, [SI+2]             ; ARR[j+1] = old ARR[j]
            MOV  [SI], AX               ; ARR[j]   = old ARR[j+1]
            MOV  BL, 1                  ; swapped = 1
            INC  SWAPS

NO_SWAP:    ADD  SI, 2                  ; j = j + 1 (words are 2 bytes)
            DEC  DX
            JNZ  INNER                  ; next pair in this pass

            OR   BL, BL                 ; any swap in this pass?
            JZ   SORTED                 ; no -> array already sorted
            LOOP OUTER                  ; CX = CX - 1, next pass

SORTED:     POP  SI
            POP  DX
            POP  CX
            POP  BX
            POP  AX
            RET
BUBBLE_SORT ENDP

;=======================================================================
; SHOW_ARRAY : prints ARR as two rows of 10 in decimal, then in hex
;=======================================================================
SHOW_ARRAY PROC
            PUSH AX
            PUSH BX
            PUSH CX
            PUSH DX
            PUSH SI

            LEA  DX, MSG_DEC
            CALL PUTS
            MOV  SI, OFFSET ARR
            MOV  CX, N
            XOR  BX, BX                 ; BX = column counter
SA_DEC:     CMP  BX, 10
            JNE  SA_D1
            LEA  DX, MSG_INDENT         ; start the second row
            CALL PUTS
            XOR  BX, BX
SA_D1:      MOV  DL, ' '
            CALL PUTC
            MOV  AX, [SI]
            CALL PRINT_DEC5
            ADD  SI, 2
            INC  BX
            LOOP SA_DEC

            LEA  DX, MSG_HEX
            CALL PUTS
            MOV  SI, OFFSET ARR
            MOV  CX, N
            XOR  BX, BX
SA_HEX:     CMP  BX, 10
            JNE  SA_H1
            LEA  DX, MSG_INDENT
            CALL PUTS
            XOR  BX, BX
SA_H1:      MOV  DL, ' '
            CALL PUTC
            MOV  AX, [SI]
            CALL PRINT_HEX4
            MOV  DL, 'H'
            CALL PUTC
            ADD  SI, 2
            INC  BX
            LOOP SA_HEX

            POP  SI
            POP  DX
            POP  CX
            POP  BX
            POP  AX
            RET
SHOW_ARRAY ENDP

;=======================================================================
; SHOW_STATS : prints PASSES, COMPS, SWAPS and verifies the order
;=======================================================================
SHOW_STATS PROC
            PUSH AX
            PUSH CX
            PUSH DX
            PUSH SI

            LEA  DX, MSG_STATS
            CALL PUTS
            LEA  DX, MSG_PASS
            CALL PUTS
            MOV  AX, PASSES
            CALL PRINT_DEC5
            LEA  DX, MSG_COMP
            CALL PUTS
            MOV  AX, COMPS
            CALL PRINT_DEC5
            LEA  DX, MSG_SWAP
            CALL PUTS
            MOV  AX, SWAPS
            CALL PRINT_DEC5

            LEA  DX, MSG_CHECK          ; independent check:
            CALL PUTS                   ; ARR[i] <= ARR[i+1] for all i
            MOV  SI, OFFSET ARR
            MOV  CX, N-1
SS_LOOP:    MOV  AX, [SI]
            CMP  AX, [SI+2]
            JA   SS_BAD                 ; unsigned greater -> not sorted
            ADD  SI, 2
            LOOP SS_LOOP
            LEA  DX, MSG_OK
            JMP  SS_OUT
SS_BAD:     LEA  DX, MSG_FAIL
SS_OUT:     CALL PUTS

            POP  SI
            POP  DX
            POP  CX
            POP  AX
            RET
SHOW_STATS ENDP

;=======================================================================
; READ_ARRAY : reads N unsigned decimal numbers into ARR
;=======================================================================
READ_ARRAY PROC
            PUSH AX
            PUSH CX
            PUSH DX
            PUSH SI

            LEA  DX, MSG_ENTER
            CALL PUTS
            MOV  SI, OFFSET ARR
            MOV  CX, 1                  ; element number 1..N
RA_NEXT:    LEA  DX, MSG_NUM
            CALL PUTS
            MOV  AX, CX
            CALL PRINT_DEC2             ; "01".."20"
            LEA  DX, MSG_COLON
            CALL PUTS
            CALL READ_NUM               ; AX = number typed
            MOV  [SI], AX
            ADD  SI, 2
            INC  CX
            CMP  CX, N
            JBE  RA_NEXT

            POP  SI
            POP  DX
            POP  CX
            POP  AX
            RET
READ_ARRAY ENDP

;=======================================================================
; READ_NUM : reads one unsigned decimal number (0..65535)
;   OUT : AX = value.  Digits only, ENTER accepts, BACKSPACE deletes.
;         A key that is not a digit, or a digit that would make the
;         number larger than 65535, is refused with a beep.
;=======================================================================
READ_NUM PROC
            PUSH BX
            PUSH CX
            PUSH DX
            PUSH DI

            XOR  BX, BX                 ; BX = value so far
            XOR  CX, CX                 ; CX = digits typed
RN_KEY:     MOV  AH, 08H
            INT  21H                    ; AL = key, no echo
            CMP  AL, 13
            JE   RN_ENTER
            CMP  AL, 8
            JE   RN_BACK
            CMP  AL, '0'
            JB   RN_BAD
            CMP  AL, '9'
            JA   RN_BAD

            SUB  AL, '0'
            XOR  AH, AH
            MOV  DI, AX                 ; DI = digit value
            MOV  AX, 10
            MUL  BX                     ; DX:AX = value * 10
            JC   RN_BAD                 ; CF = 1 -> result > FFFFh
            ADD  AX, DI
            JC   RN_BAD                 ; carry -> result > FFFFh
            MOV  BX, AX                 ; accept the digit
            INC  CX
            MOV  DX, DI
            ADD  DL, '0'
            CALL PUTC                   ; echo it
            JMP  RN_KEY

RN_BACK:    JCXZ RN_KEY                 ; nothing to delete
            MOV  AX, BX
            XOR  DX, DX
            MOV  DI, 10
            DIV  DI                     ; value = value / 10
            MOV  BX, AX
            DEC  CX
            LEA  DX, MSG_BS             ; erase the digit on screen
            CALL PUTS
            JMP  RN_KEY

RN_BAD:     MOV  DL, 7                  ; BEL
            CALL PUTC
            JMP  RN_KEY

RN_ENTER:   JCXZ RN_BAD                 ; ENTER needs at least one digit
            MOV  AX, BX

            POP  DI
            POP  DX
            POP  CX
            POP  BX
            RET
READ_NUM ENDP

;=======================================================================
; PRINT_DEC5 : prints AX as unsigned decimal, right-aligned in 5 columns
;=======================================================================
PRINT_DEC5 PROC
            PUSH AX
            PUSH BX
            PUSH CX
            PUSH DX

            XOR  CX, CX                 ; CX = number of digits
            MOV  BX, 10
PD_DIV:     XOR  DX, DX                 ; DX:AX / 10
            DIV  BX                     ; AX = quotient, DX = remainder
            PUSH DX                     ; save digit (least significant first)
            INC  CX
            OR   AX, AX
            JNZ  PD_DIV

            MOV  BX, 5                  ; leading spaces = 5 - digits
            SUB  BX, CX
            JZ   PD_OUT
PD_PAD:     MOV  DL, ' '
            CALL PUTC
            DEC  BX
            JNZ  PD_PAD

PD_OUT:     POP  DX                     ; most significant digit first
            ADD  DL, '0'
            CALL PUTC
            LOOP PD_OUT

            POP  DX
            POP  CX
            POP  BX
            POP  AX
            RET
PRINT_DEC5 ENDP

;=======================================================================
; PRINT_DEC2 : prints AL (0..99) as two decimal digits, using AAM
;=======================================================================
PRINT_DEC2 PROC
            PUSH AX
            PUSH DX
            AAM                         ; AH = AL / 10, AL = AL MOD 10
            ADD  AX, 3030H              ; both to ASCII
            PUSH AX
            MOV  DL, AH
            CALL PUTC
            POP  AX
            MOV  DL, AL
            CALL PUTC
            POP  DX
            POP  AX
            RET
PRINT_DEC2 ENDP

;=======================================================================
; PRINT_HEX4 : prints AX as 4 hexadecimal digits
;=======================================================================
PRINT_HEX4 PROC
            PUSH AX
            PUSH BX
            PUSH CX
            PUSH DX

            MOV  BX, AX
            MOV  CH, 4                  ; 4 nibbles
PH_NEXT:    MOV  CL, 4
            ROL  BX, CL                 ; top nibble -> bottom
            MOV  DL, BL
            AND  DL, 0FH
            ADD  DL, '0'
            CMP  DL, '9'
            JBE  PH_OUT
            ADD  DL, 7                  ; 'A'..'F'
PH_OUT:     CALL PUTC
            DEC  CH
            JNZ  PH_NEXT

            POP  DX
            POP  CX
            POP  BX
            POP  AX
            RET
PRINT_HEX4 ENDP

;=======================================================================
; PUTS : prints the '$'-terminated string at DS:DX
; PUTC : prints the character in DL
; CLS  : clears the screen (BIOS video mode 3, 80x25 text)
;=======================================================================
PUTS PROC
            PUSH AX
            MOV  AH, 09H
            INT  21H
            POP  AX
            RET
PUTS ENDP

PUTC PROC
            PUSH AX
            MOV  AH, 02H
            INT  21H
            POP  AX
            RET
PUTC ENDP

CLS PROC
            PUSH AX
            MOV  AX, 0003H
            INT  10H
            POP  AX
            RET
CLS ENDP

END MAIN
