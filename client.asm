; A TCP/IP client using x86_64 Linux syscalls
; Assemble and link as follows:
;   nasm -f elf64 -g -F dwarf -o client.o client.asm
;   ld client.o -o client

%include "client_utils.asm"
%include "common_utils.asm"

global _start


section .text

; Client main entry point
_start:
    ; GET IP from user
    mov rsi, enterIP
    call _prints

    ; Read adn store user input into ip_addr
    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, ip_addr
    mov rdx, 16
    syscall

    ; search for the linefeed in ip_addr and remove it
    mov rcx, 16                 ; IP address input in ASCII is maximum 15 chars plus the linefeed char
    lea rdx, [ip_addr]
    checkLinefeed:
        cmp byte [rdx+rcx], 0x0a      ; start clearing at the end of the buffer
        je removeLinefeed
        loop checkLinefeed
    removeLinefeed:
    mov byte [rdx+rcx], 0

    mov rsi, ip_addr            ; rsi will hold the ip address to be converted to int
    mov rdi, ip_addr_buffer     ; get the buffer ready that will be used for ip to int conversion
    call _iptoint               ; convert ip to int, result in rax
    call _ntohl                 ; convert the ip, stored in rax to host byte order

    mov [connectionSocket + sockaddr_in.sin_addr], eax

    ; Get PORT from user
    mov rsi, enterPortnum
    call _prints

    ;Read and store the user input into port
    mov rax, SYS_READ       ; read flag
    mov rdi, STDIN          ; read from stdin
    mov rsi, port           ; read into nvalue
    mov rdx, MAX_LEN        ; number bytes to be read
    syscall

    mov rdx, port         ; put value to convert into rdx
    call _atoi            ; convert contents of rdx to int, result in rax
    call _ntohs           ; convert rax to host byte order

    mov [connectionSocket + sockaddr_in.sin_port], ax

    ; prompt user for message to send to server
    mov rsi, sendMsgPrompt
    call _prints

    ; Read and store user input into messageBuffer
    mov rax, SYS_READ       ; read flag
    mov rdi, STDIN          ; read from stdin
    mov rsi, messageBuffer
    mov rdx, 256            ; number bytes to be read
    syscall

    ; prompt user for number of times to send message
    mov rsi, sendNumOfTimesPrompt
    call _prints

    ; Read and store user input into numOfMessages 
    mov rax, SYS_READ       ; read flag
    mov rdi, STDIN          ; read from stdin
    mov rsi, numOfMessages
    mov rdx, 8              ; number bytes to be read
    syscall

    mov      word [sock], 0     ; Initialize socket value to 0, used for cleanup
    call _socket                ; Create and initialize socket
    call _connect               ; Use socket to connect to server


    ; Send message to server multiple times and print out whatever the server sends back

    ; convert numOfMessages from ASCII to int to be used by loop
    mov rdx, numOfMessages
    call _atoi
    mov rcx, rax        ; use a loop counter to control the number of times to send message
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
    mov rdx, sockaddrInLen      ; length of sockaddr_in
    syscall

    ; Check if call succeeded
    cmp rax, 0
    jl _connect_fail

    ret

; Uses socket to send the message contained in testMsg to the server using SYS_WRITE
_send:
    mov rax, SYS_WRITE
    mov rdi, [sock]
    mov rsi, messageBuffer      ; send our test message
    call _strlen                ; get length of test message
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

    ; print echo received from server
    mov rsi, ip_addr
    call _prints
    mov rsi, separator
    call _prints
    mov rsi, socketBuffer
    call _prints

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
    call _fail

_connect_fail:
    mov rsi, connect_err_msg
    call _fail



; Calls the SYS_WRITE syscall, writing an error message to stderr, then exits
; the application. rsi and rdx must be loaded with the error message and
; length of the error message before calling _fail
_fail:
    call _printerr

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

