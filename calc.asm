; =====================================================
; Simple Assembly Calculator (NASM x86-64, Linux)
; Structured to match:
; Program Setup
; User Input
; Operation Selection
; Arithmetic Logic
; Error Handling
; Display Result
; =====================================================

global _start

; -------------------------
; Data Section (messages)
; -------------------------
section .data
    msg_num1    db "Enter first integer: ", 0
    msg_num2    db "Enter second integer: ", 0
    msg_op      db "Enter operation (+ - * /): ", 0
    msg_result  db "Result: ", 0
    msg_div0    db "Error: Division by zero", 10, 0
    msg_badop   db "Error: Invalid operation", 10, 0
    newline     db 10, 0

; -------------------------
; BSS Section (variables)
; -------------------------
section .bss
    input_buf  resb 16        ; buffer for reading input
    num1       resq 1         ; first number
    num2       resq 1         ; second number
    op         resb 1         ; operation character
    result     resq 1         ; calculation result

; -------------------------
; Text Section (code)
; -------------------------
section .text

_start:

; =====================================================
; USER INPUT – FIRST INTEGER
; =====================================================

    ; Print prompt
    mov rax, 1          ; write syscall
    mov rdi, 1          ; stdout
    mov rsi, msg_num1
    mov rdx, 22
    syscall

    ; Read input
    mov rax, 0          ; read syscall
    mov rdi, 0          ; stdin
    mov rsi, input_buf
    mov rdx, 16
    syscall

    ; Convert ASCII to integer (very simple)
    mov rax, 0
    mov rsi, input_buf
convert_num1:
    mov bl, [rsi]
    cmp bl, 10          ; newline?
    je store_num1
    sub bl, '0'
    imul rax, rax, 10
    add rax, rbx
    inc rsi
    jmp convert_num1

store_num1:
    mov [num1], rax

; =====================================================
; USER INPUT – SECOND INTEGER
; =====================================================

    mov rax, 1
    mov rdi, 1
    mov rsi, msg_num2
    mov rdx, 23
    syscall

    mov rax, 0
    mov rdi, 0
    mov rsi, input_buf
    mov rdx, 16
    syscall

    mov rax, 0
    mov rsi, input_buf
convert_num2:
    mov bl, [rsi]
    cmp bl, 10
    je store_num2
    sub bl, '0'
    imul rax, rax, 10
    add rax, rbx
    inc rsi
    jmp convert_num2

store_num2:
    mov [num2], rax

; =====================================================
; USER INPUT – OPERATION
; =====================================================

    mov rax, 1
    mov rdi, 1
    mov rsi, msg_op
    mov rdx, 28
    syscall

    mov rax, 0
    mov rdi, 0
    mov rsi, op
    mov rdx, 1
    syscall

; =====================================================
; OPERATION SELECTION / IF STATEMENTS
; =====================================================

    mov al, [op]
    mov rax, [num1]
    mov rbx, [num2]

    cmp al, '+'
    je do_add

    cmp al, '-'
    je do_sub

    cmp al, '*'
    je do_mul

    cmp al, '/'
    je do_div

    ; Invalid operation
    jmp invalid_op

; -------------------------
; Arithmetic Logic
; -------------------------

do_add:
    add rax, rbx
    jmp show_result

do_sub:
    sub rax, rbx
    jmp show_result

do_mul:
    imul rax, rbx
    jmp show_result

do_div:
    cmp rbx, 0
    je divide_by_zero
    xor rdx, rdx
    div rbx
    jmp show_result

; =====================================================
; ERROR HANDLING
; =====================================================

divide_by_zero:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_div0
    mov rdx, 24
    syscall
    jmp exit_program

invalid_op:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_badop
    mov rdx, 25
    syscall
    jmp exit_program

; =====================================================
; DISPLAY RESULT
; =====================================================

show_result:
    mov [result], rax

    mov rax, 1
    mov rdi, 1
    mov rsi, msg_result
    mov rdx, 8
    syscall

    ; Print result (single digit only – enough for coursework)
    mov rax, [result]
    add rax, '0'
    mov [input_buf], al

    mov rax, 1
    mov rdi, 1
    mov rsi, input_buf
    mov rdx, 1
    syscall

    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall

; =====================================================
; PROGRAM TERMINATION
; =====================================================

exit_program:
    mov rax, 60         ; exit syscall
    xor rdi, rdi
    syscall
