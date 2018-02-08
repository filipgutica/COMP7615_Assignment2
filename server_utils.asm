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
; function _printip
; prints out IP address in human readable format
;
; Input
; rsi = ip as an integer
; rdi = address of buffer to store each octet as ascii
; Output
; none
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_printip:
    xor rax,rax                 ; clear rax which will hold the result
    
    mov rcx, 4                      ; loop 4 times, 4 octets
    octetloop:
        mov al, sil                 ; take one octet at a time off the end of rsi (last 8 bits)
        mov rdi, client_ip          ; load address of client_ip info rdi
        call _itoa                  ; convert client_ip contents to ascii
        mov rax, [client_ip]        ; move result into rax
        push rax                    ; save the result on the stack
        xor rax, rax                ; clear rax

        shr rsi, 8                  ; shift rsi right by 8 bits, to get the next octet ready
    loop octetloop

    mov rcx, 3                      ; loop 3 times, print last octet outside of loop
    printloop:
        pop rax                     ; take an octet off of the stack (stored as ascii)
        mov [client_ip], rax        ; put it into &client_ip
        mov rsi, client_ip          ; print out the octet
        call _prints            

        mov rax, '.'                ; print a dot
        mov [client_ip], rax        
        mov rsi, client_ip
        call _prints
    loop printloop
  
    ; Print the final octet (no dot + line feed thats why it's outtside of loop)
    pop rax
    mov [client_ip], rax
    mov rsi, client_ip
    call _prints

    mov rax, 0xa
    mov [client_ip], rax
    mov rsi, client_ip
    call _prints

    ret



