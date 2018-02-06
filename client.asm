; A TCP/IP client using x86_64 Linux syscalls
; Assemble and link as follows:
;   nasm -f elf64 -g -F dwarf -o client.o client.asm
;   ld client.o -o client

global _start

SYS_EXIT  equ 60
SYS_READ  equ 0
SYS_WRITE equ 1
STDIN     equ 0
STDOUT    equ 1
STDERR    equ 2
MAX_LEN   equ 6


; Data definitions
struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .bss
    sock            resw 2      ; connection socket descriptor
    socketBuffer    resb 256    ; buffer to store data sent to the socket
    readCount       resw 2      ; keeps track of how much data was read from socketBuffer
    port            resb 6      ; get port from user
    ip_addr         resb 16     ; get ip from user    
    ip_addr_buffer  resb 16     ; buffer to use when converting ip

section .data
    sock_err_msg        db "Failed to initialize socket", 0x0a, 0
    connect_err_msg     db "Accept Failed", 0x0a, 0
    testMsg             db "comp 7615 assignment 2 test message", 0x0a, 0
    enterPortnum        db "Enter Port Number: ", 0
    enterIP             db "Enter IP Address: ", 0

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

    mov [connectionSocket + sockaddr_in.sin_port], rax

    ; GET IP from user
    mov rsi, enterIP
    call _prints

    ; Read adn store user input into ip_addr
    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, ip_addr
    mov rdx, 16
    syscall

    mov rsi, ip_addr            ; rsi will hold the ip address to be converted to int
    mov rdi, ip_addr_buffer     ; get the buffer ready that will be used for ip to int conversion
    call _iptoint               ; convert ip to int, result in rax
    call _ntohl                 ; convert the ip, stored in rax to host byte order

    mov [connectionSocket + sockaddr_in.sin_addr], rax


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
    mov rsi, testMsg            ; send our test message
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

    ; Call sys_write
    mov rsi, socketBuffer   ; buffer
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
  call _strlen              ; load length of string into rdx
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
  call _strlen              ; load length of string into rdx
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
; function _iptoint
; counts the number of characters in provided string
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




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _ntohs, _htons
; converts 16 bit integer from network -> host byte order and vice versa
; 
; Input
; rax = value to convert
; Output
; rax = host or network byte order of input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_ntohs:
_htons: 
rol ax, 8   

ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; function _ntohl, _htonl
; converts 32 bit integer from network -> host byte order and vice versa
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