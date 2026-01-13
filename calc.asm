; =====================================================
; Program Setup
; =====================================================
; This section prepares everything the program needs
; BEFORE it starts running any logic.
; Think of this like the DATA + VARIABLES section in LMC.
; =====================================================

global _start
; Makes the label "_start" visible to the OS
; This is where Linux will begin executing the program

; -------------------------
; Data Section
; -------------------------
section .data
; This section stores fixed data (text/messages)
; Similar to having predefined constants in LMC

msg_num1 db "Enter first integer: ", 0
; db = define byte
; This stores the text shown to the user when asking
; for the first number
; The 0 marks the end of the string

msg_num2 db "Enter second integer: ", 0
; Prompt shown when asking for the second number

msg_op db "Enter operation (+ - * /): ", 0
; Prompt asking the user which arithmetic operation to use

msg_result db "Result: ", 0
; Text printed before showing the calculated result

msg_div0 db "Error: Division by zero", 10, 0
; Error message for division by zero
; 10 = newline character

msg_badop db "Error: Invalid operation", 10, 0
; Error message if user enters an unsupported operator

newline db 10, 0
; A newline character used when formatting output

; -------------------------
; BSS Section
; -------------------------
section .bss
; This section reserves memory for variables
; Similar to reserving mailboxes in LMC
; The values here are NOT initialised

input_buf resb 16
; resb = reserve bytes
; Temporary buffer used to store user input from keyboard

num1 resq 1
; resq = reserve quadword (8 bytes)
; Stores the first integer entered by the user

num2 resq 1
; Stores the second integer entered by the user

op resb 1
; Stores the arithmetic operator (+ - * /)

result resq 1
; Stores the final calculation result

; -------------------------
; Text Section
; -------------------------
section .text
; This section contains the actual instructions
; Think of this like the instruction list in LMC

_start:
; Program execution begins here
; Similar to the first instruction in LMC
