; ===============================================================
; FULL NASM x86-64 CONSOLE CALCULATOR (Linux / WSL)
; Every line commented for understanding (LMC-style thinking)
; ===============================================================

global _start                          ; Export _start so Linux can begin execution here

; ---------------------------------------------------------------
; DATA SECTION: fixed messages (like constants / prompt strings)
; ---------------------------------------------------------------
section .data                          ; Begin data section for constant bytes

msg_num1    db "Enter first integer: " ; Prompt text for first number
len_num1    equ $ - msg_num1           ; Length of prompt (bytes) = current position - label

msg_num2    db "Enter second integer: "; Prompt text for second number
len_num2    equ $ - msg_num2           ; Length of prompt 2

msg_op      db "Enter operation (+ - * /): " ; Prompt text for operator input
len_op      equ $ - msg_op             ; Length of operator prompt

msg_result  db "Result: "              ; Text printed before result
len_result  equ $ - msg_result         ; Length of "Result: "

msg_div0    db "Error: Division by zero", 10 ; Error message + newline (10)
len_div0    equ $ - msg_div0           ; Length of div-by-zero message

msg_badop   db "Error: Invalid operation", 10 ; Error message + newline
len_badop   equ $ - msg_badop          ; Length of invalid-op message

newline     db 10                      ; A single newline character
len_newline equ $ - newline            ; Length of newline (1)

; ---------------------------------------------------------------
; BSS SECTION: reserved memory for variables (like LMC mailboxes)
; ---------------------------------------------------------------
section .bss                           ; Begin uninitialized storage section

inbuf       resb 64                    ; Buffer for reading user input text
opchar      resb 1                     ; Storage for operator character
num1        resq 1                     ; Storage for first integer (8 bytes)
num2        resq 1                     ; Storage for second integer (8 bytes)
result      resq 1                     ; Storage for result integer (8 bytes)
outbuf      resb 64                    ; Buffer for printing integer as ASCII

; ---------------------------------------------------------------
; TEXT SECTION: program instructions (the "code")
; ---------------------------------------------------------------
section .text                          ; Begin code section

_start:                                 ; Program entry point (Linux jumps here)

; ===============================================================
; PROGRAM FLOW (matches your headings):
; 1) Program Setup (done above)
; 2) User Input (num1, num2, operator)
; 3) Operation Selection (if statements)
; 4) Arithmetic Logic
; 5) Error Handling
; 6) Display Result
; 7) Exit
; ===============================================================

; -------------------------
; USER INPUT: FIRST INTEGER
; -------------------------

    mov rdi, msg_num1                  ; rdi = address of first prompt message
    mov rsi, len_num1                  ; rsi = length of first prompt message
    call print_string                  ; print the prompt to the console

    mov rdi, inbuf                     ; rdi = buffer to store user input text
    mov rsi, 64                        ; rsi = max bytes to read into buffer
    call read_line                     ; read a line from stdin into inbuf

    mov rdi, inbuf                     ; rdi = pointer to string to parse
    call parse_uint                    ; rax = parsed unsigned integer from the string
    mov [num1], rax                    ; store parsed value into num1 mailbox

; --------------------------
; USER INPUT: SECOND INTEGER
; --------------------------

    mov rdi, msg_num2                  ; rdi = address of second prompt message
    mov rsi, len_num2                  ; rsi = length of second prompt message
    call print_string                  ; print the prompt

    mov rdi, inbuf                     ; rdi = buffer for input
    mov rsi, 64                        ; rsi = max bytes
    call read_line                     ; read second number line

    mov rdi, inbuf                     ; rdi = pointer to text
    call parse_uint                    ; rax = parsed integer
    mov [num2], rax                    ; store into num2

; -----------------------
; USER INPUT: OPERATION
; -----------------------

    mov rdi, msg_op                    ; rdi = address of operator prompt
    mov rsi, len_op                    ; rsi = length of operator prompt
    call print_string                  ; print operator prompt

    call read_operator                 ; al = operator character (+ - * /) (skips whitespace/newlines)
    mov [opchar], al                   ; store operator in memory

; -----------------------------
; OPERATION SELECTION + LOGIC
; -----------------------------

    mov al, [opchar]                   ; al = operator chosen by user
    mov rax, [num1]                    ; rax = first number (we will compute in rax)
    mov rbx, [num2]                    ; rbx = second number

    cmp al, '+'                        ; compare operator with '+'
    je do_add                          ; if equal, jump to addition

    cmp al, '-'                        ; compare operator with '-'
    je do_sub                          ; if equal, jump to subtraction

    cmp al, '*'                        ; compare operator with '*'
    je do_mul                          ; if equal, jump to multiplication

    cmp al, '/'                        ; compare operator with '/'
    je do_div                          ; if equal, jump to division

    jmp invalid_operation              ; otherwise operator not supported

; -------------------------
; ARITHMETIC: ADDITION
; -------------------------
do_add:                                 ; label for addition block
    add rax, rbx                        ; rax = rax + rbx
    jmp show_result                     ; jump to result printing

; -------------------------
; ARITHMETIC: SUBTRACTION
; -------------------------
do_sub:                                 ; label for subtraction block
    sub rax, rbx                        ; rax = rax - rbx
    jmp show_result                     ; jump to result printing

; -------------------------
; ARITHMETIC: MULTIPLICATION
; -------------------------
do_mul:                                 ; label for multiplication block
    imul rax, rbx                       ; rax = rax * rbx (signed multiply)
    jmp show_result                     ; jump to result printing

; -------------------------
; ARITHMETIC: DIVISION
; -------------------------
do_div:                                 ; label for division block
    cmp rbx, 0                          ; check if divisor (num2) is zero
    je division_by_zero                 ; if zero, jump to error handling
    xor rdx, rdx                        ; clear rdx (required before div for 64-bit unsigned division)
    div rbx                             ; rax = rax / rbx, rdx = remainder
    jmp show_result                     ; jump to result printing

; -------------------------
; ERROR HANDLING: DIV BY ZERO
; -------------------------
division_by_zero:                       ; label for division by zero error
    mov rdi, msg_div0                   ; rdi = address of div-by-zero message
    mov rsi, len_div0                   ; rsi = length of div-by-zero message
    call print_string                   ; print error message
    jmp exit_program                    ; exit program

; -------------------------
; ERROR HANDLING: INVALID OPERATOR
; -------------------------
invalid_operation:                      ; label for invalid operator error
    mov rdi, msg_badop                  ; rdi = address of invalid operator message
    mov rsi, len_badop                  ; rsi = length of invalid operator message
    call print_string                   ; print error message
    jmp exit_program                    ; exit program

; -------------------------
; DISPLAY RESULT
; -------------------------
show_result:                             ; label for printing final result
    mov [result], rax                    ; store computed result into memory

    mov rdi, msg_result                  ; rdi = address of "Result: "
    mov rsi, len_result                  ; rsi = length of "Result: "
    call print_string                    ; print "Result: "

    mov rax, [result]                    ; rax = result value to print
    call print_uint                      ; print integer in rax as decimal text

    mov rdi, newline                     ; rdi = address of newline char
    mov rsi, len_newline                 ; rsi = length of newline (1)
    call print_string                    ; print newline

; -------------------------
; EXIT PROGRAM
; -------------------------
exit_program:                            ; label for clean exit
    mov rax, 60                          ; rax = syscall number 60 (exit)
    xor rdi, rdi                         ; rdi = exit status 0
    syscall                              ; perform exit syscall

; ===============================================================
; FUNCTIONS (small reusable blocks like subroutines)
; ===============================================================

; ---------------------------------------------------------------
; print_string
; Inputs:
;   rdi = address of bytes to print
;   rsi = length of bytes to print
; Output:
;   none
; ---------------------------------------------------------------
print_string:                            ; function label
    mov rax, 1                           ; rax = syscall number 1 (write)
    mov rdx, rsi                         ; rdx = length to write
    mov rsi, rdi                         ; rsi = buffer address
    mov rdi, 1                           ; rdi = file descriptor 1 (stdout)
    syscall                              ; write(stdout, buffer, length)
    ret                                  ; return to caller

; ---------------------------------------------------------------
; read_line
; Inputs:
;   rdi = destination buffer
;   rsi = max bytes to read
; Output:
;   rax = number of bytes read
; Notes:
;   Reads raw bytes from stdin. User typically ends with Enter.
; ---------------------------------------------------------------
read_line:                               ; function label
    mov rax, 0                           ; rax = syscall number 0 (read)
    mov rdx, rsi                         ; rdx = max bytes
    mov rsi, rdi                         ; rsi = destination buffer
    mov rdi, 0                           ; rdi = file descriptor 0 (stdin)
    syscall                              ; read(stdin, buffer, max)
    ret                                  ; return to caller

; ---------------------------------------------------------------
; parse_uint
; Inputs:
;   rdi = pointer to ASCII digits ending with newline or non-digit
; Output:
;   rax = parsed unsigned integer (base 10)
; Notes:
;   This is like LMC: start at 0, multiply by 10, add next digit.
; ---------------------------------------------------------------
parse_uint:                              ; function label
    xor rax, rax                         ; rax = 0 (accumulator)
    mov rsi, rdi                         ; rsi = pointer walking through characters
parse_loop:                              ; loop label
    mov bl, [rsi]                        ; bl = current character
    cmp bl, '0'                          ; if char < '0' then stop
    jb parse_done                        ; jump if below '0'
    cmp bl, '9'                          ; if char > '9' then stop
    ja parse_done                        ; jump if above '9'
    sub bl, '0'                          ; convert ASCII digit to numeric 0..9
    imul rax, rax, 10                    ; rax = rax * 10 (shift left in decimal)
    movzx rcx, bl                        ; rcx = digit (zero-extended)
    add rax, rcx                         ; rax = rax + digit
    inc rsi                              ; move to next character
    jmp parse_loop                       ; repeat loop
parse_done:                              ; end label
    ret                                  ; return with rax holding number

; ---------------------------------------------------------------
; read_operator
; Output:
;   al = operator character (+ - * /)
; Notes:
;   Reads from stdin until it finds a non-space, non-newline char.
; ---------------------------------------------------------------
read_operator:                           ; function label
read_op_again:                           ; label to retry reading
    mov rdi, inbuf                       ; rdi = buffer to store input
    mov rsi, 64                          ; rsi = max bytes
    call read_line                       ; read a line (e.g., "+\n")
    mov al, [inbuf]                      ; al = first character from buffer
    cmp al, ' '                          ; if it's a space, ignore
    je read_op_again                     ; read again
    cmp al, 10                           ; if it's newline, ignore
    je read_op_again                     ; read again
    ret                                  ; return with al holding operator

; ---------------------------------------------------------------
; print_uint
; Input:
;   rax = unsigned integer to print
; Output:
;   none
; Notes:
;   Converts number to ASCII by repeated division by 10,
;   stores digits in reverse, then prints them.
; ---------------------------------------------------------------
print_uint:                              ; function label
    mov rbx, 10                          ; rbx = 10 (base for decimal conversion)
    lea rdi, [outbuf + 63]               ; rdi = pointer to end of output buffer
    mov byte [rdi], 0                    ; store null terminator (not required, but harmless)
    cmp rax, 0                           ; check if number is zero
    jne pu_loop                          ; if not zero, convert normally
    dec rdi                              ; move left one byte
    mov byte [rdi], '0'                  ; store ASCII '0'
    jmp pu_print                         ; jump to print
pu_loop:                                 ; conversion loop label
    xor rdx, rdx                         ; clear rdx before division
    div rbx                              ; rax = rax / 10, rdx = remainder (0..9)
    add dl, '0'                          ; remainder -> ASCII digit
    dec rdi                              ; move left in buffer
    mov [rdi], dl                        ; store digit
    cmp rax, 0                           ; are we finished (quotient == 0)?
    jne pu_loop                          ; if not, keep converting
pu_print:                                ; label for printing
    ; Calculate length = (end_ptr - current_ptr)
    lea rsi, [outbuf + 63]               ; rsi = pointer to end of buffer
    sub rsi, rdi                         ; rsi = length (bytes) from rdi to end
    ; Now print the digits stored at rdi with length rsi
    mov rdx, rsi                         ; rdx = length
    mov rsi, rdi                         ; rsi = buffer pointer
    mov rdi, 1                           ; rdi = stdout
    mov rax, 1                           ; rax = write syscall
    syscall                              ; write(stdout, digits, length)
    ret                                  ; return to caller
