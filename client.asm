; A TCP/IP client using x86_64 Linux syscalls
; Assemble and link as follows:
;   nasm -f elf64 -g -o client.o client.asm
;   ld client.o -o client

global _start

; Data definitions
struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .bss
    sock resw 2                 ; connection socket descriptor
    socketBuffer resb 256       ; buffer to store data sent to the socket
    readCount resw 2           ; keeps track of how much data was read from socketBuffer
    inputBuffer                 ; buffer to store keyboard input from console

section .data
    sock_err_msg        db "Failed to initialize socket", 0x0a, 0
    sock_err_msg_len    equ $ - sock_err_msg

    connect_err_msg      db "Accept Failed", 0x0a, 0
    connect_err_msg_len  equ $ - connect_err_msg

    testMsg          db "comp 7615 assignment 2 test message", 0x0a, 0
    testMsgLen      equ $ - testMsg

    ; sockaddr_in structure for the server the socket connects to
    connectionSocket istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2           ; AF_INET
        at sockaddr_in.sin_port, dw 0xce56        ; port 22222 in host byte order
        at sockaddr_in.sin_addr, dd 0             ; localhost - INADDR_ANY
        at sockaddr_in.sin_zero, dd 0, 0
    iend
    sockaddrInLen     equ $ - connectionSocket

section .text

; Client main entry point
_start:    
    mov      word [sock], 0     ; Initialize socket value to 0, used for cleanup
    call _socket                ; Create and initialize socket
    call _connect               ; Use socket to connect to server

    ; Send message to server multiple times and print out whatever the server sends back
    mov rcx, 3          ; use a loop counter to control the number of times to send message
    sendLoop:           
        push rcx        ; preserve the value in rcx to ensure loop works properly
        call _send      ; send message to the server
        call _receive   ; print the response that the server sends back
        pop rcx         ; restore the value of rcx, as it was modified by the previous function calls
    loop sendLoop;

    ; Close socket file descriptor
    mov rdi, [sock]
    call _close_sock
    mov word [sock], 0

    ; Exit with success (return 0)
    mov rdi, 0
    call _exit

; Performs a SYS_SOCKET call to initialize a TCP/IP socket. Stores the socket 
; file descriptor in the sock variable
_socket:
    mov rax, 41     ; SYS_SOCKET
    mov rdi, 2      ; AF_INET
    mov rsi, 1      ; SOCK_STREAM
    mov rdx, 0    
    syscall
    
    ; Check if socket was created successfully
    cmp rax, 0
    jle _socket_fail

    ; Store the new socket descriptor 
    mov [sock], rax

    ret

; Use the socket previously created to establish a connection to the specified server
_connect:
    mov rax, 42                 ; SYS_CONNECT
    mov rdi, [sock]             ; connecting socket file descriptor
    mov rsi, connectionSocket   ; sockaddr_in struct
    mov rdx, sockaddrInLen    ; length of sockaddr_in
    syscall

    ; Check if call succeeded
    cmp rax, 0
    jl _connect_fail

    ret

; Uses socket to send the message contained in testMsg to the server using SYS_WRITE 
_send:
    mov rax, 1                  ; SYS_WRITE
    mov rdi, [sock]             ; connecting socket file descriptor
    mov rsi, testMsg           ; send our test message
    mov rdx, testMsgLen       ; length of test message
    syscall

    ret

; Reads up to 256 bytes from the socket and sets the readCount variable to the
;  number of bytes read by SYS_RECEIVE
_receive:
    ; Call SYS_RECEIVE
    mov rax, 0               ; SYS_RECEIVE
    mov rdi, [sock]          ; connection socket fd
    mov rsi, socketBuffer    ; buffer
    mov rdx, 256             ; read 256 bytes
    syscall 

    ; Copy number of bytes read to variable readCount
    mov [readCount], rax

    ; Call sys_write
    mov rax, 1              ; SYS_WRITE
    mov rdi, 1              ; STDOUT
    mov rsi, socketBuffer   ; buffer
    mov rdx, [readCount]    ; number of bytes read from specified buffer
    syscall

    ret 

; Performs SYS_CLOSE on the socket specified in rdi
_close_sock:
    mov     rax, 3        ; SYS_CLOSE
    syscall

    ret

; Error Handling code
; _*_fail loads the rsi and rdx registers with the appropriate
; error messages for given system call. Then call _fail to display the
; error message and exit the application.
_socket_fail:
    mov rsi, sock_err_msg
    mov rdx, sock_err_msg_len
    call _fail

_connect_fail:
    mov rsi, connect_err_msg
    mov rdx, connect_err_msg_len
    call _fail

; Calls the SYS_WRITE syscall, writing an error message to stderr, then exits
; the application. rsi and rdx must be loaded with the error message and
; length of the error message before calling _fail
_fail:
    mov rax, 1 ; SYS_WRITE
    mov rdi, 2 ; STDERR
    syscall

    mov rdi, 1
    call _exit

; Exits cleanly, checking if the server socket needs to be closed
; before calling sys_exit
_exit:
    mov rax, [sock]
    cmp rax, 0
    mov rdi, [sock]
    call _close_sock

    .perform_exit:
    mov rax, 60
    syscall