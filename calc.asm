; ============================================================
; NASM x86-64 Console Calculator (Linux)
; ============================================================
; Implements:
;  - Input: two integers + operator
;  - Ops: +, -, *, /
;  - Error handling: invalid operator, invalid integer, div by 0
;  - Output: integer result
;
; This aligns with the portfolio brief requirement for a NASM
; console-line calculator prototype. 
; ============================================================

global _start                          ; Make _start visible to the linker (program entry point)

; ------------------------------------------------------------
; Constants (system call numbers for Linux x86-64)
; ------------------------------------------------------------
%define SYS_READ   0                   ; syscall number for read()
%define SYS_WRITE  1                   ; syscall number for write()
%define SYS_EXIT   60                  ; syscall number for exit()

%define STDIN      0                   ; file descriptor 0 = keyboard input
%define STDOUT     1                   ; file descriptor 1 = terminal output

; ------------------------------------------------------------
; Data Section (fixed strings / prompts)
; ------------------------------------------------------------
section .data                          ; Begin data section (static data)

prompt_num1 db "Enter first integer: " ; Prompt text for first number
prompt_num1_len equ $ - prompt_num1    ; Length of prompt_num1 in bytes

prompt_num2 db "Enter second integer: "; Prompt text for second number
prompt_num2_len equ $ - prompt_num2    ; Length of prompt_num2 in bytes

prompt_op db "Enter operation (+ - * /): " ; Prompt text for operator
prompt_op_len equ $ - prompt_op        ; Length of prompt_op in bytes

msg_result db "Result: "               ; Label printed before the result
msg_result_len equ $ - msg_result      ; Length of msg_result in bytes

err_badint db "Error: invalid integer input", 10 ; Error + newline
err_badint_len equ $ - err_badint      ; Length of err_badint in bytes

err_badop db "Error: invalid operator", 10 ; Error + newline
err_badop_len equ $ - err_badop        ; Length of err_badop in bytes

err_div0 db "Error: division by zero", 10 ; Error + newline
err_div0_len equ $ - err_div0          ; Length of err_div0 in bytes

newline db 10                          ; ASCII 10 = newline character

; ------------------------------------------------------------
; BSS Section (buffers / variables allocated at runtime)
; ------------------------------------------------------------
section .bss                           ; Begin BSS section (uninitialised storage)

inbuf resb 64                          ; Input buffer for reading lines (up to 63 chars + newline)
outbuf resb 64                         ; Output buffer for printing integer as text

; ------------------------------------------------------------
; Text Section (code)
; ------------------------------------------------------------
section .text                          ; Begin code section

; ============================================================
; _start: program entry point (like START in LMC)
; ============================================================
_start:                                ; Label where OS starts execution

    ; -------------------------
    ; Ask for first integer
    ; -------------------------
    lea rsi, [rel prompt_num1]         ; rsi = address of prompt_num1
    mov rdx, prompt_num1_len           ; rdx = length of prompt_num1
    call print_string                  ; Print the prompt

    call read_line                     ; Read a line into inbuf
    lea rsi, [rel inbuf]               ; rsi = pointer to inbuf
    call parse_int                     ; Convert ASCII to integer
    cmp rax, 0x7fffffffffffffff        ; Did parse_int return "error sentinel"?
    je bad_integer                     ; If yes, jump to invalid integer error
    mov r12, rax                       ; r12 = first integer (store safely)

    ; -------------------------
    ; Ask for second integer
    ; -------------------------
    lea rsi, [rel prompt_num2]         ; rsi = address of prompt_num2
    mov rdx, prompt_num2_len           ; rdx = length of prompt_num2
    call print_string                  ; Print the prompt

    call read_line                     ; Read a line into inbuf
    lea rsi, [rel inbuf]               ; rsi = pointer to inbuf
    call parse_int                     ; Convert ASCII to integer
    cmp rax, 0x7fffffffffffffff        ; Check error sentinel
    je bad_integer                     ; If error, jump to invalid integer error
    mov r13, rax                       ; r13 = second integer

    ; -------------------------
    ; Ask for operator
    ; -------------------------
    lea rsi, [rel prompt_op]           ; rsi = address of prompt_op
    mov rdx, prompt_op_len             ; rdx = length of prompt_op
    call print_string                  ; Print the prompt

    call read_line                     ; Read a line into inbuf
    lea rsi, [rel inbuf]               ; rsi = pointer to inbuf
    call get_operator                  ; Extract first non-space operator char
    cmp al, 0                          ; If al==0 then no operator found
    je bad_operator                    ; Jump to invalid operator

    ; -------------------------
    ; Compute result based on operator
    ; -------------------------
    mov rax, r12                       ; rax = first integer (like ACC in LMC)
    mov rbx, r13                       ; rbx = second integer (like a stored value)

    cmp al, '+'                        ; Is operator '+'?
    je do_add                          ; If yes, jump to add

    cmp al, '-'                        ; Is operator '-'?
    je do_sub                          ; If yes, jump to subtract

    cmp al, '*'                        ; Is operator '*'?
    je do_mul                          ; If yes, jump to multiply

    cmp al, '/'                        ; Is operator '/'?
    je do_div                          ; If yes, jump to divide

    jmp bad_operator                   ; If none matched, invalid operator

do_add:                                ; Addition branch
    mov rax, r12                       ; rax = first integer
    add rax, r13                       ; rax = rax + second integer
    jmp print_result                   ; Go print result

do_sub:                                ; Subtraction branch
    mov rax, r12                       ; rax = first integer
    sub rax, r13                       ; rax = rax - second integer
    jmp print_result                   ; Go print result

do_mul:                                ; Multiplication branch
    mov rax, r12                       ; rax = first integer
    imul rax, r13                      ; rax = rax * second integer (signed multiply)
    jmp print_result                   ; Go print result

do_div:                                ; Division branch
    cmp r13, 0                         ; Is divisor (second integer) zero?
    je division_by_zero                ; If yes, jump to div0 error

    mov rax, r12                       ; rax = dividend (first integer)
    cqo                                 ; Sign-extend rax into rdx:rax for idiv
    idiv r13                           ; rax = quotient (integer division), rdx = remainder
    jmp print_result                   ; Go print result

; ============================================================
; Print the final result (FR4)
; ============================================================
print_result:                          ; Label to output the result

    lea rsi, [rel msg_result]          ; rsi = "Result: "
    mov rdx, msg_result_len            ; rdx = length of that label
    call print_string                  ; Print "Result: "

    ; rax currently holds the computed integer result
    lea rsi, [rel outbuf]              ; rsi = output buffer start
    call int_to_string                 ; Convert rax into ASCII in outbuf, returns length in rdx

    lea rsi, [rel outbuf]              ; rsi = address of converted number string
    call print_string                  ; Print the number

    lea rsi, [rel newline]             ; rsi = newline char
    mov rdx, 1                         ; rdx = 1 byte
    call print_string                  ; Print newline

    mov rdi, 0                         ; rdi = exit code 0 (success)
    call exit_program                  ; Exit cleanly

; ============================================================
; Error handlers (FR5)
; ============================================================
bad_integer:                           ; Invalid integer input
    lea rsi, [rel err_badint]          ; rsi = error message
    mov rdx, err_badint_len            ; rdx = message length
    call print_string                  ; Print error
    mov rdi, 1                         ; rdi = exit code 1
    call exit_program                  ; Exit

bad_operator:                          ; Invalid operator
    lea rsi, [rel err_badop]           ; rsi = error message
    mov rdx, err_badop_len             ; rdx = message length
    call print_string                  ; Print error
    mov rdi, 1                         ; rdi = exit code 1
    call exit_program                  ; Exit

division_by_zero:                      ; Division by zero
    lea rsi, [rel err_div0]            ; rsi = error message
    mov rdx, err_div0_len              ; rdx = message length
    call print_string                  ; Print error
    mov rdi, 1                         ; rdi = exit code 1
    call exit_program                  ; Exit

; ============================================================
; print_string(rsi=ptr, rdx=len)
; Uses sys_write to STDOUT.
; ============================================================
print_string:                          ; Function label
    mov rax, SYS_WRITE                 ; rax = syscall number write
    mov rdi, STDOUT                    ; rdi = file descriptor (stdout)
    syscall                            ; Do the system call
    ret                                ; Return to caller

; ============================================================
; read_line()
; Reads up to 63 bytes into inbuf, null-terminates.
; ============================================================
read_line:                             ; Function label
    mov rax, SYS_READ                  ; rax = syscall number read
    mov rdi, STDIN                     ; rdi = file descriptor stdin
    lea rsi, [rel inbuf]               ; rsi = buffer address
    mov rdx, 63                        ; rdx = max bytes to read
    syscall                            ; Perform read()

    ; rax now contains number of bytes read
    lea rbx, [rel inbuf]               ; rbx = base address of buffer
    add rbx, rax                       ; rbx = address right after last byte read
    mov byte [rbx], 0                  ; Add null terminator at end
    ret                                ; Return

; ============================================================
; parse_int(rsi=ptr_to_string) -> rax=integer
; Returns error sentinel 0x7fffffffffffffff on invalid input.
; Supports optional leading spaces and optional '+' or '-' sign.
; ============================================================
parse_int:                             ; Function label
    xor rax, rax                       ; rax = 0 (will hold the number result)
    xor rbx, rbx                       ; rbx = 0 (used as sign flag: 0=positive, 1=negative)

skip_spaces_int:                       ; Loop label
    mov dl, byte [rsi]                 ; dl = current character
    cmp dl, ' '                        ; Is it a space?
    jne check_sign                     ; If not space, go check sign
    inc rsi                            ; Move pointer to next char
    jmp skip_spaces_int                ; Repeat

check_sign:                            ; Label
    mov dl, byte [rsi]                 ; dl = current character
    cmp dl, '-'                        ; Is it '-'?
    jne check_plus                     ; If not, check '+'
    mov bl, 1                          ; bl = 1 means negative
    inc rsi                            ; Move past '-'
    jmp parse_digits                   ; Start digit parsing

check_plus:                            ; Label
    cmp dl, '+'                        ; Is it '+'?
    jne parse_digits                   ; If not, start digit parsing
    inc rsi                            ; Move past '+'

parse_digits:                          ; Label
    mov dl, byte [rsi]                 ; dl = current character
    cmp dl, 0                          ; End of string?
    je invalid_int                     ; If empty/no digits, invalid
    cmp dl, 10                         ; Newline?
    je invalid_int                     ; If newline immediately, invalid (no digits)

digit_loop:                            ; Loop label
    mov dl, byte [rsi]                 ; dl = current character
    cmp dl, 0                          ; End of string?
    je finish_int                      ; If yes, finish
    cmp dl, 10                         ; Newline?
    je finish_int                      ; If yes, finish
    cmp dl, ' '                        ; Space?
    je finish_int                      ; Allow trailing spaces (finish)
    cmp dl, '0'                        ; Below '0'?
    jb invalid_int                     ; If yes, invalid
    cmp dl, '9'                        ; Above '9'?
    ja invalid_int                     ; If yes, invalid

    ; rax = rax*10 + (dl - '0')
    imul rax, rax, 10                  ; Multiply current total by 10
    movzx rcx, dl                      ; rcx = zero-extended digit char
    sub rcx, '0'                       ; rcx = numeric digit value
    add rax, rcx                       ; Add digit to total

    inc rsi                            ; Move to next character
    jmp digit_loop                     ; Continue parsing digits

finish_int:                            ; Label
    cmp bl, 1                          ; Was sign negative?
    jne ok_int                         ; If not, number is already correct
    neg rax                            ; rax = -rax (apply negative sign)

ok_int:                                ; Label
    ret                                ; Return with valid integer in rax

invalid_int:                           ; Label
    mov rax, 0x7fffffffffffffff        ; Return sentinel to signal invalid input
    ret                                ; Return

; ============================================================
; get_operator(rsi=ptr) -> al = operator char or 0 if none
; Skips spaces, returns first non-space char.
; ============================================================
get_operator:                          ; Function label
skip_spaces_op:                        ; Label
    mov al, byte [rsi]                 ; al = current character
    cmp al, 0                          ; End of string?
    je no_op                           ; If yes, no operator found
    cmp al, 10                         ; Newline?
    je no_op                           ; If yes, no operator found
    cmp al, ' '                        ; Space?
    jne got_op                         ; If not space, we found operator
    inc rsi                            ; Move to next char
    jmp skip_spaces_op                 ; Keep skipping spaces

got_op:                                ; Label
    ret                                ; Return with operator in al

no_op:                                 ; Label
    xor al, al                         ; al = 0 (means none)
    ret                                ; Return

; ============================================================
; int_to_string(rax=value, rsi=outbuf) -> rdx=len
; Converts signed integer in rax into ASCII string at outbuf.
; Returns length in rdx.
; ============================================================
int_to_string:                         ; Function label
    mov rcx, 0                         ; rcx = length counter
    mov rbx, rax                       ; rbx = copy of value (we will modify it)
    mov r8, rsi                        ; r8 = start of buffer

    ; Handle negative: write '-' then convert absolute value
    cmp rbx, 0                         ; Is value negative?
    jge convert_abs                    ; If >=0, skip minus handling
    mov byte [rsi], '-'                ; Write '-' to buffer
    inc rsi                            ; Advance buffer pointer
    inc rcx                            ; Increase length count
    neg rbx                            ; Make value positive for conversion

convert_abs:                           ; Label
    ; Special case: if value is 0, output "0"
    cmp rbx, 0                         ; Is absolute value zero?
    jne convert_loop_setup             ; If not, proceed normally
    mov byte [rsi], '0'                ; Write '0'
    inc rsi                            ; Move pointer
    inc rcx                            ; Increase length
    jmp done_convert                   ; Finish

convert_loop_setup:                    ; Label
    ; We will build digits in reverse into a temporary area at end of outbuf
    lea r9, [rel outbuf + 63]          ; r9 = pointer to end of outbuf
    mov byte [r9], 0                   ; Null terminator at end
    mov r10, 0                         ; r10 = number of digits

convert_loop:                          ; Loop label
    xor rdx, rdx                       ; Clear rdx for division (rdx:rax form)
    mov rax, rbx                       ; rax = current value
    mov r11, 10                        ; r11 = divisor 10
    div r11                            ; Unsigned div: rax=quotient, rdx=remainder
    add dl, '0'                        ; Convert remainder to ASCII
    dec r9                             ; Move backward
    mov byte [r9], dl                  ; Store digit
    inc r10                            ; digit count++
    mov rbx, rax                       ; rbx = quotient
    cmp rbx, 0                         ; Done when quotient is 0
    jne convert_loop                   ; If not zero, keep looping

    ; Copy reversed digits into final buffer position (after optional '-')
copy_digits:                           ; Label
    mov al, byte [r9]                  ; al = digit from temp
    mov byte [rsi], al                 ; write digit to output
    inc rsi                            ; advance output pointer
    inc rcx                            ; length++
    inc r9                             ; move through temp digits
    dec r10                            ; one fewer digit to copy
    cmp r10, 0                         ; finished copying?
    jne copy_digits                    ; if not finished, keep copying

done_convert:                          ; Label
    ; Null-terminate the output string
    mov byte [rsi], 0                  ; end string with null terminator
    mov rdx, rcx                       ; rdx = final length
    ret                                ; Return

; ============================================================
; exit_program(rdi=exit_code)
; ============================================================
exit_program:                          ; Function label
    mov rax, SYS_EXIT                  ; rax = syscall number exit
    syscall                            ; Exit process with code in rdi
