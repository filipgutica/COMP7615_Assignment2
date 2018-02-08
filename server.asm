;; TCP echo server using x86_64 Linux syscalls
;; Assemble and link as follows:
;;        nasm -f elf64 -g -o server.o server.asm
;;        ld server.o -o server
;;
;;


%include "server_utils.asm"
%include "common_utils.asm"

global _start


section .text

;; Sever main entry point
_start:

     ; Get PORT from user
    mov rsi, enterPortnum
    call _prints

    ;Read and store the user input into port
    mov rax, SYS_READ       ; read flag
    mov rdi, STDIN          ; read from stdin
    mov rsi, port           ; read into nvalportue
    mov rdx, MAX_LEN        ; number bytes to be read
    syscall

    mov rdx, port         ; put value to convert into rdx
    call _atoi            ; convert contents of rdx to int, result in rax
    call _ntohs           ; convert rax (port) to host byte order

    mov [pop_sa + sockaddr_in.sin_port], rax        ; write port to the struct

    ;; Initialize listening and client socket values to 0, used for cleanup
    mov word [sock], 0
    mov word [client], 0

    ;; Initialize socket
    call     _socket

    ;; Bind and Listen
    call     _listen

    ;; Main loop handles connection requests (accept()) then echoes data back to client
    .mainloop:
        call     _accept

        ;; Read and echo string back to the client
        ;; up the connection on their end.
        .readloop:
            call     _read
            call     _echo

            ;; read_count is set to zero when client hangs up
            mov     rax, [read_count]
            cmp     rax, 0
            je      .read_complete

            ; Print messages received from the client
            mov rsi, clientMessage
            call _prints
            mov rsi, echobuf
            call _prints
        jmp .readloop

        .read_complete:
        ;; Close client socket
        mov    rdi, [client]
        call   _close_sock
        mov    word [client], 0
    jmp    .mainloop

    ;; Exit with success (return 0)
    mov     rdi, 0
    call     _exit

;; Performs a sys_socket call to initialise a TCP/IP listening socket.
;; Stores the socket file descriptor in the sock variable
_socket:
    mov         rax, 41     ; SYS_SOCKET
    mov         rdi, 2      ; AF_INET
    mov         rsi, 1      ; SOCK_STREAM
    mov         rdx, 0
    syscall

    ;; Check if socket was created successfully
    cmp        rax, 0
    jle        _socket_fail

    ;; Store the new socket descriptor
    mov        [sock], rax

    ret

;; Calls sys_bind and sys_listen to start listening for connections
_listen:
    mov        rax, 49                  ; SYS_BIND
    mov        rdi, [sock]              ; listening socket fd
    mov        rsi, pop_sa              ; sockaddr_in struct
    mov        rdx, sockaddr_in_len     ; length of sockaddr_in
    syscall

    ;; Check call succeeded
    cmp        rax, 0
    jl         _bind_fail

    ;; Bind succeeded, call sys_listen
    mov        rax, 50          ; SYS_LISTEN
    mov        rsi, 5           ; backlog
    syscall

    ;; Check for success
    cmp        rax, 0
    jl         _listen_fail

    ret

;; Accept a cleint connection and store the new client socket descriptor
_accept:
    ;; Call sys_accept
    mov       rax, 43                   ; SYS_ACCEPT
    mov       rdi, [sock]               ; listening socket fd
    mov       rsi, client_addr          ; client addr
    lea       rdx, [client_addr_len]    ; client addr length
    syscall

    ;; Check if call succeeded
    cmp       rax, 0
    jl        _accept_fail

    ;; Store returned client socket descriptor
    mov     [client], rax


    mov rsi, accept_msg
    call _prints

    mov rax, [client_addr + sockaddr_in.sin_addr]   ; put the client ip address into rax
    call _htonl                                     ; convert ip address to network byte order
    mov rsi, rax                                    ; put the ip into RSI
    mov rdi, client_ip                              ; address of client_ip into RDI
    call _printip                                   ; print the IP

    ret

;; Reads up to 256 bytes from the client into echobuf and sets the read_count variable
;; to be the number of bytes read by sys_read
_read:
    ; clear echobuf if previously written to
    mov rcx, ECHO_BUF_LEN
    lea rdx, [echobuf]
    xor al, al                  ; load 0 into al
    clearBuffer:
    mov byte [rdx+rcx], al      ; start clearing at the end of the buffer
    loop clearBuffer

    ;; Call sys_read
    mov     rax, 0              ; SYS_READ
    mov     rdi, [client]       ; client socket fd
    mov     rsi, echobuf        ; buffer
    mov     rdx, ECHO_BUF_LEN   ; read 256 bytes
    syscall

    ;; Copy number of bytes read to variable
    mov     [read_count], rax

    ret

;; Sends up to the value of read_count bytes from echobuf to the client socket
;; using sys_write
_echo:
    mov     rax, 1               ; SYS_WRITE
    mov     rdi, [client]        ; client socket fd
    mov     rsi, echobuf         ; buffer
    mov     rdx, [read_count]    ; number of bytes received in _read
    syscall

    ret

;; Performs sys_close on the socket in rdi
_close_sock:
    mov     rax, 3        ; SYS_CLOSE
    syscall

    ret

;; Error Handling code
;; _*_fail loads the rsi and rdx registers with the appropriate
;; error messages for given system call. Then call _fail to display the
;; error message and exit the application.
_socket_fail:
    mov     rsi, sock_err_msg
    call    _fail

_bind_fail:
    mov     rsi, bind_err_msg
    call    _fail

_listen_fail:
    mov     rsi, lstn_err_msg
    call    _fail

_accept_fail:
    mov     rsi, accept_err_msg
    call    _fail

;; Calls the sys_write syscall, writing an error message to stderr, then exits
;; the application. rsi and rdx must be loaded with the error message and
;; length of the error message before calling _fail
_fail:
    call _printerr

    mov        rdi, 1
    call       _exit

;; Exits cleanly, checking if the listening or client sockets need to be closed
;; before calling sys_exit
_exit:
    mov        rax, [sock]
    cmp        rax, 0
    je         .client_check
    mov        rdi, [sock]
    call       _close_sock

    .client_check:
    mov        rax, [client]
    cmp        rax, 0
    je         .perform_exit
    mov        rdi, [client]
    call       _close_sock

    .perform_exit:
    mov        rax, 60
    syscall



