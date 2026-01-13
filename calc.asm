; file: calculator64.asm
; 64-bit Linux NASM calculator: reads two integers + operator, prints result, handles errors.

; ===== BUILD / RUN (x86_64 Linux) =====
; nasm -f elf64 calculator64.asm -o calculator64.o
; ld calculator64.o -o calculator64
; ./calculator64

BITS 64                                ; Assemble for 64-bit mode
GLOBAL _start                          ; Program entry symbol for the linker

SECTION .data                          ; Initialized data (strings)

prompt1:        db "Enter first integer: "         ; Prompt 1 text
prompt1_len:    equ $ - prompt1                    ; Byte length of prompt 1

prompt2:        db "Enter second integer: "        ; Prompt 2 text
prompt2_len:    equ $ - prompt2                    ; Byte length of prompt 2

promptOp:       db "Enter operator (+ - * /): "    ; Operator prompt text
promptOp_len:   equ $ - promptOp                   ; Byte length of operator prompt

result_lbl:     db "Result: "                      ; Label before printing the number
result_lbl_len: equ $ - result_lbl                 ; Length of label

err_num:        db "Error: invalid integer input.", 10 ; Error + newline
err_num_len:    equ $ - err_num                        ; Length

err_op:         db "Error: unsupported operator.", 10  ; Error + newline
err_op_len:     equ $ - err_op                          ; Length

err_div0:       db "Error: division by zero.", 10       ; Error + newline
err_div0_len:   equ $ - err_div0                         ; Length

nl:             db 10                                   ; Newline byte

SECTION .bss                          ; Uninitialized storage

inbuf:   resb 256                     ; Input line buffer
outbuf:  resb 32                      ; Output buffer for int->string (64-bit)

a:       resq 1                       ; First integer (64-bit)
b:       resq 1                       ; Second integer (64-bit)
res:     resq 1                       ; Result (64-bit)
op:      resb 1                       ; Operator character

SECTION .text                         ; Code section

; ----------------------------
; write_stdout
; Inputs:
;   RSI = pointer to bytes
;   RDX = length
; Uses Linux x86_64 syscall: write(1, buf, len)
; Clobbers: RAX, RDI
write_stdout:
    mov rax, 1                        ; syscall number 1 = write
    mov rdi, 1                        ; fd = 1 (stdout)
    syscall                           ; perform write
    ret                               ; return to caller

; ----------------------------
; read_stdin
; Inputs:
;   RSI = pointer to buffer
;   RDX = max bytes
; Output:
;   RAX = bytes read
; Uses syscall: read(0, buf, max)
; Clobbers: RDI
read_stdin:
    mov rax, 0                        ; syscall number 0 = read
    mov rdi, 0                        ; fd = 0 (stdin)
    syscall                           ; perform read
    ret                               ; return

; ----------------------------
; read_line
; Reads up to (len-1) bytes into inbuf and null-terminates.
; Output:
;   RAX = bytes read (0 = EOF)
read_line:
    lea rsi, [rel inbuf]              ; RSI = address of inbuf
    mov rdx, 255                      ; read up to 255 so we can add a terminator
    call read_stdin                   ; RAX = number of bytes read
    cmp rax, 0                        ; check EOF/error
    jle .done                         ; if <=0, skip termination
    lea rbx, [rel inbuf]              ; RBX = base of buffer
    mov byte [rbx + rax], 0           ; write null terminator at end
.done:
    ret                               ; return

; ----------------------------
; parse_int64
; Input:
;   RSI = pointer to null-terminated string
; Output:
;   RAX = parsed signed 64-bit integer (valid if RDX=0)
;   RDX = 0 success, 1 failure
; Behavior:
;   - skips leading spaces/tabs
;   - optional +/-
;   - requires at least one digit
;   - allows trailing whitespace/newline
parse_int64:
    xor rdx, rdx                      ; RDX=0 => assume success
    mov r8, 1                         ; R8 = sign (+1 by default)

.skip_ws:
    mov bl, [rsi]                     ; BL = current char
    cmp bl, ' '                       ; space?
    je .ws_advance                    ; skip
    cmp bl, 9                         ; tab?
    je .ws_advance                    ; skip
    jmp .sign_check                   ; otherwise check sign/digits
.ws_advance:
    inc rsi                           ; move to next char
    jmp .skip_ws                      ; keep skipping

.sign_check:
    mov bl, [rsi]                     ; BL = current char
    cmp bl, '+'                       ; plus sign?
    je .got_plus                      ; handle
    cmp bl, '-'                       ; minus sign?
    je .got_minus                     ; handle
    jmp .digits                       ; otherwise digits
.got_plus:
    inc rsi                           ; skip '+'
    jmp .digits                       ; parse digits
.got_minus:
    mov r8, -1                        ; sign = -1
    inc rsi                           ; skip '-'
    jmp .digits                       ; parse digits

.digits:
    xor rax, rax                      ; RAX = value = 0
    xor rcx, rcx                      ; RCX = seen_digit flag = 0

.digit_loop:
    mov bl, [rsi]                     ; BL = char
    cmp bl, '0'                       ; below '0'?
    jb .after_digits                  ; stop digits
    cmp bl, '9'                       ; above '9'?
    ja .after_digits                  ; stop digits
    sub bl, '0'                       ; ASCII -> number 0..9
    movzx rbx, bl                     ; RBX = digit (zero-extend)
    imul rax, rax, 10                 ; value *= 10
    add rax, rbx                      ; value += digit
    inc rsi                           ; next char
    mov rcx, 1                        ; seen at least one digit
    jmp .digit_loop                   ; continue

.after_digits:
    cmp rcx, 1                        ; saw any digit?
    jne .fail                         ; if not, invalid

.trailing:
    mov bl, [rsi]                     ; BL = current trailing char
    cmp bl, 0                         ; end of string?
    je .apply_sign                    ; ok
    cmp bl, 10                        ; '\n'?
    je .apply_sign                    ; ok
    cmp bl, 13                        ; '\r'?
    je .apply_sign                    ; ok
    cmp bl, ' '                       ; space?
    je .trail_advance                 ; skip
    cmp bl, 9                         ; tab?
    je .trail_advance                 ; skip
    jmp .fail                         ; anything else => invalid
.trail_advance:
    inc rsi                           ; next char
    jmp .trailing                     ; keep checking

.apply_sign:
    cmp r8, 1                         ; sign +1?
    je .ok                            ; if yes, keep value
    neg rax                           ; otherwise negate
.ok:
    xor rdx, rdx                      ; RDX=0 success
    ret                               ; return

.fail:
    mov rdx, 1                        ; RDX=1 failure
    xor rax, rax                      ; clear result
    ret                               ; return

; ----------------------------
; read_operator
; Reads a line then returns first non-whitespace character in AL.
; Output:
;   AL = operator
;   RDX = 0 success, 1 failure
read_operator:
    call read_line                    ; read line into inbuf
    cmp rax, 0                        ; any bytes?
    jle .fail                         ; if not, fail
    lea rsi, [rel inbuf]              ; RSI = start of buffer
.skip:
    mov al, [rsi]                     ; AL = current char
    cmp al, ' '                       ; space?
    je .adv                           ; skip
    cmp al, 9                         ; tab?
    je .adv                           ; skip
    cmp al, 10                        ; newline?
    je .fail                          ; empty operator line
    cmp al, 13                        ; CR?
    je .fail                          ; treat as empty
    cmp al, 0                         ; end?
    je .fail                          ; treat as empty
    xor rdx, rdx                      ; success
    ret                               ; return with operator in AL
.adv:
    inc rsi                           ; next char
    jmp .skip                         ; keep skipping
.fail:
    mov rdx, 1                        ; failure
    xor rax, rax                      ; clear
    ret                               ; return

; ----------------------------
; int64_to_str
; Input:
;   RAX = signed 64-bit integer
; Output:
;   RSI = pointer to start of string (inside outbuf)
;   RDX = length in bytes
; Why:
;   write() needs pointer+length.
int64_to_str:
    lea rdi, [rel outbuf + 31]        ; RDI = last byte of outbuf
    mov byte [rdi], 0                 ; null terminator (not required by write, but safe)
    mov rbx, 10                       ; base 10 divisor
    xor r8, r8                        ; r8 = negative flag (0 no, 1 yes)

    cmp rax, 0                        ; is value 0?
    jne .nz                           ; if not, normal convert
    dec rdi                           ; move left
    mov byte [rdi], '0'               ; store '0'
    jmp .finish                       ; done

.nz:
    cmp rax, 0                        ; negative?
    jge .conv                         ; if >=0, convert
    mov r8, 1                         ; remember negative
    neg rax                           ; make positive for conversion

.conv:
.loop:
    xor rdx, rdx                      ; required for DIV: RDX:RAX / RBX
    div rbx                           ; quotient -> RAX, remainder -> RDX (0..9)
    add dl, '0'                       ; remainder to ASCII
    dec rdi                           ; move left
    mov [rdi], dl                     ; write digit
    test rax, rax                     ; quotient == 0?
    jne .loop                         ; if not, keep going

    cmp r8, 1                         ; was negative?
    jne .finish                       ; if not, finish
    dec rdi                           ; space for '-'
    mov byte [rdi], '-'               ; write '-'

.finish:
    mov rsi, rdi                      ; RSI = start pointer
    lea rdx, [rel outbuf + 31]        ; RDX = end pointer
    sub rdx, rdi                      ; RDX = length
    ret                               ; return

; ----------------------------
; exit
; Input:
;   RDI = exit code
; syscall: exit(code)
exit:
    mov rax, 60                       ; syscall number 60 = exit
    syscall                           ; terminate process

; ============================
; Program entry
; ============================
_start:
    ; Prompt first integer
    lea rsi, [rel prompt1]            ; RSI = prompt1 address
    mov rdx, prompt1_len              ; RDX = prompt1 length
    call write_stdout                 ; print prompt

    call read_line                    ; read into inbuf
    lea rsi, [rel inbuf]              ; RSI = buffer
    call parse_int64                  ; parse -> RAX, status -> RDX
    cmp rdx, 0                        ; success?
    jne .bad_number                   ; if not, error
    mov [rel a], rax                  ; save first integer

    ; Prompt second integer
    lea rsi, [rel prompt2]            ; RSI = prompt2
    mov rdx, prompt2_len              ; RDX = length
    call write_stdout                 ; print prompt

    call read_line                    ; read line
    lea rsi, [rel inbuf]              ; RSI = buffer
    call parse_int64                  ; parse
    cmp rdx, 0                        ; success?
    jne .bad_number                   ; if not, error
    mov [rel b], rax                  ; save second integer

    ; Prompt operator
    lea rsi, [rel promptOp]           ; RSI = operator prompt
    mov rdx, promptOp_len             ; RDX = length
    call write_stdout                 ; print prompt

    call read_operator                ; AL = operator, RDX status
    cmp rdx, 0                        ; success?
    jne .bad_operator                 ; if not, error
    mov [rel op], al                  ; save operator

    ; Load operands
    mov rax, [rel a]                  ; RAX = a
    mov rbx, [rel b]                  ; RBX = b
    mov dl, [rel op]                  ; DL = operator

    ; Choose operation
    cmp dl, '+'                       ; plus?
    je .do_add                        ; add
    cmp dl, '-'                       ; minus?
    je .do_sub                        ; subtract
    cmp dl, '*'                       ; times?
    je .do_mul                        ; multiply
    cmp dl, '/'                       ; divide?
    je .do_div                        ; divide
    jmp .bad_operator                 ; otherwise unsupported

.do_add:
    add rax, rbx                      ; RAX = a + b
    jmp .store                        ; go store/print

.do_sub:
    sub rax, rbx                      ; RAX = a - b
    jmp .store                        ; go store/print

.do_mul:
    imul rax, rbx                     ; RAX = a * b (signed)
    jmp .store                        ; go store/print

.do_div:
    cmp rbx, 0                        ; divisor == 0?
    je .div_zero                      ; if yes, error
    cqo                               ; sign-extend RAX into RDX:RAX for IDIV
    idiv rbx                          ; quotient -> RAX
    jmp .store                        ; go store/print

.store:
    mov [rel res], rax                ; save result

    ; Print "Result: "
    lea rsi, [rel result_lbl]         ; RSI = "Result: "
    mov rdx, result_lbl_len           ; RDX = length
    call write_stdout                 ; print label

    ; Print number
    mov rax, [rel res]                ; RAX = result
    call int64_to_str                 ; RSI pointer, RDX length
    call write_stdout                 ; print number

    ; Print newline
    lea rsi, [rel nl]                 ; RSI points to newline byte
    mov rdx, 1                        ; print 1 byte
    call write_stdout                 ; print newline

    mov rdi, 0                        ; exit code 0
    jmp exit                          ; exit

.bad_number:
    lea rsi, [rel err_num]            ; error string address
    mov rdx, err_num_len              ; error string length
    call write_stdout                 ; print error
    mov rdi, 1                        ; exit code 1
    jmp exit                          ; exit

.bad_operator:
    lea rsi, [rel err_op]             ; error string address
    mov rdx, err_op_len               ; error string length
    call write_stdout                 ; print error
    mov rdi, 1                        ; exit code 1
    jmp exit                          ; exit

.div_zero:
    lea rsi, [rel err_div0]           ; error string address
    mov rdx, err_div0_len             ; error string length
    call write_stdout                 ; print error
    mov rdi, 1                        ; exit code 1
    jmp exit                          ; exit
