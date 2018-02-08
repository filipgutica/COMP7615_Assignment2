global utils

SYS_EXIT            equ 60
SYS_READ            equ 0
SYS_WRITE           equ 1
STDIN               equ 0
STDOUT              equ 1
STDERR              equ 2
MAX_LEN             equ 6
ECHO_BUF_LEN        equ 256


; Data definitions
struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .bss
    sock            resw 2      ; connection socket descriptor
    socketBuffer    resb 256    ; buffer to store data received by the socket
    readCount       resw 2      ; keeps track of how much data was read from socketBuffer
    port            resb 6      ; get port from user
    ip_addr         resb 16     ; get ip from user
    messageBuffer   resb 256    ; buffer to store the message sent to server
    numOfMessages   resw 2      ; buffer to store number of times to send message
    ip_addr_buffer  resb 16     ; buffer to use when converting ip

section .data
    sock_err_msg        db "Failed to initialize socket", 0x0a, 0
    connect_err_msg     db "Accept Failed", 0x0a, 0
    sendMsgPrompt       db "Enter message to send: ", 0
    sendNumOfTimesPrompt    db "Number of times to send message: ", 0
    enterPortnum        db "Enter Port Number: ", 0
    enterIP             db "Enter IP Address: ", 0
    separator           db " response: ", 0

    ; sockaddr_in structure for the server the socket connects to
    connectionSocket istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2           ; AF_INET
        at sockaddr_in.sin_port, dw 0xce56        ; port 22222 in host byte order
        at sockaddr_in.sin_addr, dd 0             ; localhost - INADDR_ANY
        at sockaddr_in.sin_zero, dd 0, 0
    iend
    sockaddrInLen     equ $ - connectionSocket

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
