; =====================================================
; CPU Feature Showcase Program
; Author: Alisson Jaime Sales Barros
;
; Description:
; This program demonstrates various features of the CPU:
; 1. Arithmetic: Calculates 100 / 10.
; 2. Logic: Calculates 7 AND 12.
; 3. Control Flow: Uses JMP to skip an instruction.
;
; --- Data Section (values stored in memory) ---
; Value 100 at address 30 (0x1E)
; Value 10  at address 31 (0x1F)
; Value 7   at address 32 (0x20)
; Value 12  at address 33 (0x21)
; =====================================================

; --- Code Section ---

; 1. Perform 100 / 10 (Result should be 10)
DIV
00011110    ; Argument 1: Address of value 100
00011111    ; Argument 2: Address of value 10

; 2. Perform 7 AND 12 (Result should be 4, as 0111 & 1100 = 0100)
AND
00100000    ; Argument 1: Address of value 7
00100001    ; Argument 2: Address of value 12

; 3. Jump over the next two lines (the NOT instruction and its operand)
JMP
00000010    ; Argument 1: Jump offset of 2 lines

; 4. This is dead code that will be skipped by the JMP instruction
NOT
00011110    ; This operand will be ignored

; 5. This is where the program continues after the jump
;    Perform 10 - 7 (Result should be 3)
SUB
00011111    ; Argument 1: Address of value 10
00100000    ; Argument 2: Address of value 7
