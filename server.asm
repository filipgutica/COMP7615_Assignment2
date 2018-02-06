;; TCP echo server using x86_64 Linux syscalls
;; Assemble and link as follows:
;;        nasm -f elf64 -o server.o server.asm
;;        ld server.o -o server
;;
;;



global _start

SYS_EXIT            equ 60
SYS_READ            equ 0
SYS_WRITE           equ 1
STDIN               equ 0
STDOUT              equ 1
STDERR              equ 2
MAX_LEN             equ 6
SYS_GETPEERNAME     equ 52

;; Data definitions
struc sockaddr_in
    .sin_family resw 1
    .sin_port   resw 1
    .sin_addr   resd 1
    .sin_zero   resb 8
endstruc

section .bss
    sock                resw 2
    client              resw 2
    echobuf             resb 256
    read_count          resw 2
    port                resb 6
    client_addr         resb 32  
    client_addr_len     resw 2

             

section .data
    sock_err_msg        db "Failed to initialize socket", 0x0a, 0
    sock_err_msg_len    equ $ - sock_err_msg

    bind_err_msg        db "Failed to bind socket", 0x0a, 0
    bind_err_msg_len    equ $ - bind_err_msg

    lstn_err_msg        db "Socket Listen Failed", 0x0a, 0
    lstn_err_msg_len    equ $ - lstn_err_msg

    accept_err_msg      db "Accept Failed", 0x0a, 0
    accept_err_msg_len  equ $ - accept_err_msg

    accept_msg          db "Client Connected!", 0x0a, 0
    accept_msg_len      equ $ - accept_msg

    enterPortnum    db "Enter Port Number: ", 0

  
    ;; sockaddr_in structure for the address the listening socket binds to
    pop_sa istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2           ; AF_INET
        at sockaddr_in.sin_port, dw 0xce56        ; port 22222 in host byte order
        at sockaddr_in.sin_addr, dd 0             ; localhost - INADDR_ANY
        at sockaddr_in.sin_zero, dd 0, 0
    iend
    sockaddr_in_len     equ $ - pop_sa


section .text

;; Sever main entry point
_start:

     ; Get PORT from user
    mov rsi, enterPortnum
    call _prints

    ;Read and store the user input into nvalue
    mov rax, SYS_READ       ; read flag
    mov rdi, STDIN          ; read from stdin
    mov rsi, port           ; read into nvalue
    mov rdx, MAX_LEN        ; number bytes to be read
    syscall

    mov rdx, port         ; put value to convert into rdx
    call _atoi            ; convert contents of rdx to int, result in rax
    call _ntohs           ; convert rax (port) to host byte order

    mov [pop_sa + sockaddr_in.sin_port], rax
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
    mov       rdx, client_addr_len      ; client addr length
    syscall

    ;; Check if call succeeded
    cmp       rax, 0
    jl        _accept_fail

    ;; Store returned client socket descriptor
    mov     [client], rax

    mov rax, [client_addr + sockaddr_in.sin_addr]

    ;; Print connection message to stdout
    mov       rax, 1             ; SYS_WRITE
    mov       rdi, 1             ; STDOUT
    mov       rsi, accept_msg
    mov       rdx, accept_msg_len
    syscall

    ret

;; Reads up to 256 bytes from the client into echobuf and sets the read_count variable
;; to be the number of bytes read by sys_read
_read:
    ;; Call sys_read
    mov     rax, 0          ; SYS_READ
    mov     rdi, [client]   ; client socket fd
    mov     rsi, echobuf    ; buffer
    mov     rdx, 256        ; read 256 bytes
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
    mov     rdx, sock_err_msg_len
    call    _fail

_bind_fail:
    mov     rsi, bind_err_msg
    mov     rdx, bind_err_msg_len
    call    _fail

_listen_fail:
    mov     rsi, lstn_err_msg
    mov     rdx, lstn_err_msg_len
    call    _fail

_accept_fail:
    mov     rsi, accept_err_msg
    mov     rdx, accept_err_msg_len
    call    _fail

;; Calls the sys_write syscall, writing an error message to stderr, then exits
;; the application. rsi and rdx must be loaded with the error message and
;; length of the error message before calling _fail
_fail:
    mov        rax, 1 ; SYS_WRITE
    mov        rdi, 2 ; STDERR
    syscall

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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _atoi
; converts the provided ascii string to an integer
;
; Input:
; rdx = pointer to the string to convert
; Output:
; rax = integer value
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_atoi:
    push rdi              ; save rdi, I will use as negative flag
    xor rax,rax           ; clear rax which will hold the result
.next_digit:
    movzx rcx ,byte[rdx]  ; get one character
    inc rdx               ; move pointer to next byte (increment)
    cmp rcx, '-'          ; check for handle_negative
    je .neg
    cmp rcx, '0'          ; check less than '0'
    jl .done
    cmp rcx, '9'          ; check greater than '9'
    jg .done
    sub rcx,  '0'         ; convert to ascii by subtracting '0' or 0x30
    imul rax, 10          ; prepare the result for the next character
    add rax, rcx          ; append current digit
    jmp .next_digit       ; keep going until done
.done:
    cmp rdi, 0            ; rdi less than 0?
    jl .done_neg          ; its a negative number jump to done_neg
    pop rdi               ; restore rdi
    ret
.neg:
    mov rdi, -1
    jmp .next_digit
.done_neg:
    neg rax               ; 2's complement result, make negative
    pop rdi               ; restore rdi
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _itoa
; converts provided integer to ascii string
; Example of an in/out parameter function
;
; Input
; rax = pointer to the int to convert
; rdi = address of the result
; Output:
; None
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_itoa:
    xor   rbx, rbx          ; clear the rbx, I will use as counter for stack pushes
.push_chars:
    xor rdx, rdx            ; clear rdx
    cmp rax, 0              ; check less then 0
    jl .handle_negative     ; handle negative number
.continue_push_chars:
    mov rcx, 10             ; rcx is divisor, devide by 10
    div rcx                 ; devide rdx by rcx, result in rax remainder in rdx
    add rdx, '0'            ; add '0' or 0x30 to rdx convert int => ascii
    push rdx                ; push result to stack
    inc rbx                 ; increment my stack push counter
    cmp rax, 0              ; is rax 0?
    jg .push_chars          ; if rax not 0 repeat
    xor rdx, rdx

.pop_chars:
    pop rax                 ; pop result from stack into rax

    stosb                   ; store contents of rax in rdi, which holds the address of num... From stosb documentation:
                            ; After the byte, word, or doubleword is transferred from the AL, AX, or rax register to
                            ; the memory location, the (E)DI register is incremented or decremented automatically
                            ; according to the setting of the DF flag in the EFLAGS register. (If the DF flag is 0,
                            ; the (E)DI register is incremented; if the DF flag is 1, the (E)DI register is decremented.)
                            ; The (E)DI register is incremented or decremented by 1 for byte operations,
                            ; by 2 for word operations, or by 4 for ; doubleword operations.
    dec rbx                 ; decrement my stack push counter
    cmp rbx, 0              ; check if stack push counter is 0
    jg .pop_chars           ; not 0 repeat
    mov rax, 0x0a           ; add line feed
    stosb                   ; write line feed to rdi => &num
    ret                     ; return to main

.handle_negative:
  neg rax                   ; make rax positive
  mov rsi, rax              ; save rax into rsi
  xor rax, rax              ; clear rax
  mov rax, '-'              ; put '-' into rax
  stosb                     ; write to rdi => num memory location
  mov rax, rsi              ; put original rax value back to rax
  xor rsi, rsi              ; clear rsi
  jmp .continue_push_chars  ; continue pushing characters

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _prints
; writes provided string to stdout
;
; Input
; rsi = string to Display to STDOUT
; Output:
; None
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_prints:
  call _strlen               ; load length of string into rdx
  mov rax, SYS_WRITE        ; write flag
  mov rdi, STDOUT           ; write to stdout
  syscall
  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _prints
; writes provided string to stdout
;
; Input
; rsi = string to Display to STDOUT
; Output:
; None
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_printerr:
  call _strlen               ; load length of string into rdx
  mov rax, SYS_WRITE        ; write flag
  mov rdi, STDERR           ; write to stdout
  syscall
  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _strlen
; counts the number of characters in provided string
;
; Input
; rsi = string to asess
; Output
; rdx = length of string
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_strlen:
  push rax                  ; save and clear counter
  xor rax, rax              ; clear counter
  push rsi                  ; save contents of rsi
next:
  cmp [rsi], byte 0         ; check for null character
  jz null_char              ; exit if null character
  inc rax                   ; increment counter
  inc rsi                   ; increment string pointer
  jmp next                  ; keep going
null_char:
  mov rdx, rax              ; put value of counter into rdx (length of string)
  pop rsi                   ; restore rsi (original string)
  pop rax                   ; restore rax
  ret                       ; return




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _ntohs, _htons
; counts the number of characters in provided string
;
; Input
; rax = int
; Output
; rax = host or network byte order of input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_ntohs:
_htons:
rol ax, 8

ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _ntohl, _htonl
; converts network -> host byte order and vice versa
;
; Input
; rax = value to convert
; Output
; rax = host or network byte order of input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_ntohl:
_htonl: 
rol ax, 8   
rol eax, 16
rol ax, 8

ret