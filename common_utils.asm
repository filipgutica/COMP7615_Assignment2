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
    push rcx                ; save rcx
.push_chars:
    xor rdx, rdx            ; clear rdx
    cmp rax, 0              ; check less then 0
    jl .handle_negative     ; handle negative number
.continue_push_chars:
    mov rcx, 10             ; rcx is divisor, devide by 10
    div rcx                 ; devide rax by rcx, result in rax remainder in rdx
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
    mov rax, 0              ; add line feed
    stosb                   ; write line feed to rdi => &num
    pop rcx                 ; restore rcx
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
  push rcx                  ; save rcx
  call _strlen              ; load length of string into rdx
  mov rax, SYS_WRITE        ; write flag
  mov rdi, STDOUT           ; write to stdout
  syscall
  pop rcx                   ; restore rcx
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
; converts 16 bit integer from network -> host byte order and vice versa
; 
; Input
; rax = value to convert
; Output
; rax = host or network byte order of input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_ntohs:
_htons: 
rol ax, 8       ; see documentation for explination

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
rol ax, 8       ; see documentation for explination
rol eax, 16
rol ax, 8

ret