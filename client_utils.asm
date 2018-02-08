global utils

SYS_EXIT            equ 60
SYS_READ            equ 0
SYS_WRITE           equ 1
STDIN               equ 0
STDOUT              equ 1
STDERR              equ 2
MAX_LEN             equ 6
ECHO_BUF_LEN        equ 256


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _iptoint
; converts ip string to integer representation
;
; Input
; rsi = ip addr
; Output
; rax = ip in hex
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_iptoint:
    xor rax,rax                 ; clear rax which will hold the result
.next_one:
    movzx rax ,byte[rsi]        ; get one character at a time
    inc rsi                     ; move pointer to next byte (increment)
    cmp rax, '.'                ; check for a '.' 
    je .handle_octet            ; handle the current octet
    cmp rax, '0'                ; check less than '0'
    jl .done
    cmp rax, '9'                ; check greater than '9'
    jg .done
    stosb                       ; write a character to the ip addr buffer
    jmp .next_one               ; keep going until done
.handle_octet:
    mov rdx, ip_addr_buffer     ; we have one octet in the buffer, put into rdx
    call _atoi                  ; convert octet to int, result in rax
    push rax                    ; push result to stack
    
    ; Clear Buffer
    mov rdi, ip_addr_buffer     ; get buffer ready for next octet
    xor rax, rax
    mov rcx, 16
    rep stosb

    mov rdi, ip_addr_buffer     ; reload address of buffer into rdi to continue writing to it
    jmp .next_one


.done:
    mov rdx, ip_addr_buffer     ; get the last octet
    call _atoi                  ; convert to int
    push rax                    ; save result to stack

    ; claer buffer
    mov rdi, ip_addr_buffer     ; get buffer ready for result
    xor rax, rax
    mov rcx, 16
    rep stosb

    mov rdi, ip_addr_buffer

    pop rax                     ; pop first octet
    stosb                       ; write to buffer
    pop rax                     ; pop second octet
    stosb                       ; write to buffer
    pop rax                     ; pop third octet
    stosb                       ; write to buffer
    pop rax                     ; pop fourth octet
    stosb

    mov rax, [ip_addr_buffer]   ; move result to rax
    ret
