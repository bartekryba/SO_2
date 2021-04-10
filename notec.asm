section .bss
spin_lock   resq 1
stack_addr  resq 1
wait_table  resd N

section .text
global notec
extern debug

; uint64_t notec(uint32_t n, char const *calc);
; edi - n
; rsi - calc
notec:
    push    rbp
    push    r12                     ; calc iterator
    push    r13                     ; reading number mode
    push    r14                     ; notec number n (rdi backup)
    push    r15                     ; calc pointer (rsi backup)
    xor     r12, r12
    xor     r13, r13
    mov     r14, rdi
    mov     r15, rsi

    mov     rbp, rsp

main_loop:
    xor     eax, eax                ; value of loaded number
    mov     al, byte [r15 + r12]    ; load current byte from calc
    inc     r12                     ; advance iterator to next byte

    cmp     al, 'A'                 ; check if given byte is between A and F
    jb      parse_digit
    cmp     al, 'F'
    ja      parse_lowercase

    sub     al, 55                  ; sub 55 to get 10 from A, 11 form B etc.
    jmp     after_num_load

parse_digit:
    cmp     al, 0
    je      exit

    cmp     al, '0'                 ; check is given byte between 0 and 9
    jb      parse_other
    cmp     al, '9'
    ja      parse_other

    sub     al, '0'                 ; sub ascii value of 0 to get digit value
    jmp     after_num_load

parse_lowercase:
    cmp     al, 'a'                 ; same as with uppercase letters
    jb      parse_other
    cmp     al, 'f'
    ja      parse_other

    sub     al, 55

after_num_load:
    test    r13b, r13b              ; check if program is in reading mode
    jnz     reading_mode
    mov     r13b, 1                 ; set reading mode to 1
    push    rax                     ; push loaded value onto the stack   
    jmp     main_loop

reading_mode:
    pop     rdx                     ; pop current value from the stack
    shl     rdx, 4                  ; shift it left by 4 bits
    add     rdx, rax                ; add calculated value
    push    rdx                     ; push it back onto the stack
    jmp     main_loop

parse_other:
    xor     r13b, r13b              ; disable reading mode

    ; 0 arg operations:
    cmp     al, '='                 
    je      main_loop
    cmp     al, 'n'
    je      _n
    cmp     al, 'N'
    je      _N

    ; 1 arg operations:
    pop     r9

    cmp     al, '-'
    je      _neg
    cmp     al, '~'
    je      _not
    cmp     al, 'Z'                 ; remove top value from the stack
    je      main_loop
    cmp     al, 'Y'
    je      _Y
    cmp     al, 'W'
    je      _W

    ; 2 arg operations:
    pop     r10

    cmp     al, '+'
    je      _add
    cmp     al, '*'
    je      _mul
    cmp     al, '&'
    je      _and
    cmp     al, '|'
    je      _or
    cmp     al, '^'
    je      _xor
    cmp     al, 'X'
    je      _X

; push current notec number onto the stack
_n:    
    push    r14
    jmp     main_loop

; push total number of notecs onto the stack
_N:
    push    N
    jmp     main_loop

; call debug function
_g:
    mov     rdi, r14                        ; first arg - notec number
    mov     r13, rsp                        ; I know im not in reading mode, so i can use r13 register
    mov     rsi, rsp                        ; second arg - stack pointer
    ;;;;;;;;;;;;; align stosu
    call    debug
    mov     rsp, r13
    xor     r13, r13                        ; reset reading mode to 0
    sal     rax, 3                          ; multiply rax by 8
    test    rax, rax
    js      _g_negative                     ; test if returned shift value is negative
    add     rsp, rax
    jmp     main_loop

_g_negative:
    neg     rax
    sub     rsp, rax
    jmp     main_loop

; perform arithmetic negation of value on top of the stack
_neg:
    neg     r9
    push    r9
    jmp     main_loop

; perform logical netgation of value on top of the stack
_not:
    not     r9
    push    r9
    jmp     main_loop

; pop two values from top of the stack, add them and push result onto the stack
_add:
    add     r9, r10
    push    r9
    jmp     main_loop

; the same, but with multiplication
_mul:
    mov     rax, r9
    mul     r10    
    push    rax
    jmp     main_loop

; the same, but with and operation
_and:
    and     r9, r10    
    push    r9
    jmp     main_loop

; the same, but with or operation
_or:
    or      r9, r10 
    push    r9
    jmp     main_loop

; the same, but with xor operation
_xor:
    xor     r9, r10
    push    r9
    jmp     main_loop

; duplicate value on top of the stack
_Y:
    push    r9
    push    r9
    jmp     main_loop

; switch places of the first two values on the stack
_X:
    push    r9
    push    r10

_W:
    mov     eax, 1                          ; value to lock spin_lock
    mov     rdx, spin_lock                  ; load address of spin_lock to rdx
_W_busy_wait:
    xchg    [rdx], eax                      ; swap content of spin_lock and eax
    test    eax, eax                        ; check if lock was opened
    jnz     _W_busy_wait                    ; if not, return to waiting

    mov     r11d, dword [wait_table + r9]   ; load wait_table value for desired notec
    sub     r11d, 1
    cmp     r11d, r14d
    je      _W_connected                    ; if its equal to current notec, jump to _W_connected

    mov     [wait_table + r14d], dword r9d  ; if not, set wait_table value for current notec to desired notec value
    mov     qword [rdx], 0                  ; unlock spin_lock

_W_wait_for_second:                         ; wait for desired notec to connect
    mov     eax, 1                          ; same locking mechanism
    xchg    [rdx], eax
    test    eax, eax
    jnz     _W_wait_for_second

    mov     r11d, dword [wait_table + r9]   ; load wait_table value for desired notec
    sub     r11d, 1
    cmp     r11d, r14d                      ; wait until desired notec sets its wait_table
    jne     _W_wait_for_second              ; value to r9d

                                            ; after desired notec updated its wait_table value 
                                            ; it means that it has also loaded its rsp into stack_addr    
    mov     r8, [stack_addr]                ; load it into r8
    mov     rcx, [r8]                       ; load desired notec's stack value into rcx
    mov     [r8], r9                        ; set desired notec's stack value to stack value of current notec
    push    rcx                             ; push desired notec's stack value onto current stack

    mov     [wait_table + r14d], dword 0    ; update wait_table values to 0
    mov     [wait_table + r9], dword 0
    mov     qword [rdx], 0                  ; unlock spin_lock

    jmp     main_loop

_W_connected:
    mov     [stack_addr], rsp               ; save current thread's stack position in stack_addr
    mov     r11d, r9d
    inc     r11d
    mov     [wait_table + r14d], dword r11d ; save desired notec number for position of current notec in wait_table
    mov     qword [rdx], 0                  ; free lock

_W_wait_after_connected:
    mov     eax, 1                          ; wait for own value in wait_table to be set to 0
    xchg    [rdx], eax
    test    eax, eax
    jnz     _W_wait_after_connected
    mov     r11d, dword [wait_table + r14d]
    test    r11d, r11d
    jnz     _W_wait_after_connected

    jmp     main_loop

exit:
    pop     rax
    mov     rsp, rbp        
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp

    ret