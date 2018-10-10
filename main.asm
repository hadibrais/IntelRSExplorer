; There are two input parameters. One of these macros must be defined: ADD, LOAD, JUMPFORE, JUMPBACK, or STORE.
; The RS macro can be used to pass the number of RS entries to test for. It must be at least 4.
; The SIZE macro specifies the number of iterations. It's statically defined as 10 million, which is a good default value.
 
%define SIZE 10000000

%ifdef IACA_MARKS
%macro IACA_start 0
     mov ebx, 111
     db 0x64, 0x67, 0x90
%endmacro
%macro IACA_end 0
     mov ebx, 222
     db 0x64, 0x67, 0x90
%endmacro
%else
%define IACA_start
%define IACA_end
%endif

%ifdef ADD
%define LAT 1
%elifdef LOAD
%define LAT 4
%elifdef JUMPFORE
%define LAT 1
%elifdef JUMPBACK
%define LAT 1
%elifdef STORE
%define LAT 1
%endif


BITS 64
DEFAULT REL

section .bss
align 64
bufsrc: resb 16

section .text

global _start
_start:

    lea rsi, [bufsrc]
    mov [bufsrc], rsi
    nop
    nop
    
    mov ebp, SIZE
    nop
    nop
    nop

; The alignment has two affects:
; (1) The RS value at which the RS stalls counter value becomes larger than zero.
; (2) The absolute RS stalls values. The way these change does not follow an obvious pattern, but the difference is not significant.
; An alignment of 4 or larger increases effect (1) by 1.
align 4
.loop:
    ; Wait for the previous instructions to leave the RS.
    lfence
    nop
    nop
    nop
    
    ; The RS must be empty now.
    
    ; Start a new repetition with an empty RS.
%ifdef ADD
%rep 1+(RS-4)/(4-1)
    add rax, rax
    add rax, rax
    add rax, rax
    add rax, rax
%endrep

%elifdef LOAD
%rep (RS + (RS/16))/2
    mov rdi, qword [rsi]
    mov rsi, qword [rdi]
%endrep
%rep (RS + (RS/16))% 2
    mov rdi, qword [rsi]
%endrep
%rep (4 - ((RS + (RS/16))% 4)% 4)
    nop
%endrep

%elifdef JUMPFORE
%macro  jmpmacro 0 
    jmp     %%label  
%%label:
%endmacro
%rep 1+(RS-2)/(2-1)
jmpmacro
jmpmacro
%endrep

%elifdef JUMPBACK
%assign tnumlast 2*(1+(RS-2)/(2-1))
%xdefine tlast .target %+ tnumlast
jmp tlast
%assign tnum 0
%rep 1+(RS-2)/(2-1)
%xdefine t0 .target %+ tnum
%assign tnum (tnum + 1)
%xdefine t1 .target %+ tnum
%assign tnum (tnum + 1)
%xdefine t2 .target %+ tnum
t1:
    jmp t0
t2:
    jmp t1
%endrep
.target0:

%elifdef STORE
%rep 1+(RS-4)/(4-3)
    mov qword [rsi], rax
    mov qword [rsi], rax
    nop
    nop
%endrep
%endif

%ifdef ADD
%rep 1+((RS-4)% (4-1)) ; The modulo operator must be followed by a white space.
    add rax, rax       ; When the result of the modulo is zero, there will be one unecessary instruction, but that's OK since the latency is 1.
%endrep
%rep 4-(1+((RS-4)% (4-1)))
    nop
%endrep
%endif

    ; Now the RS has exactly the specified number of entries.
    ; See if we can allocate different uops without penalty.

    ;add rbx, rbx
    ;add rbx, rbx
    ;add rbx, rbx
    ;add rbx, rbx
    ;mov rsi, qword [rsi]
    ;mov qword [rsi+8], rbx
    ;mov rsi, qword [rsi]
    ;nop
    ;mov rsi, qword [rsi]

; Single-byte NOPs on Sandy Brdige and later and Goldmont and later do not require any RS entries but only ROB entries.
; Therefore to wait until the RS is completely empty before begining the next iteration and witohut interfering with the execution engine unit, NOPs can be used.
; Using NOPs may cause additional ROB stalls, but I don't think this matters. LFENCE could also be used, but the results are a bit different and I think it's less reliable.

%rep (RS*4*LAT)-4 ; Wait until RS is empty without triggering RS stalls. The -4 is because of the next set of uops.
    nop
%endrep

    nop
    nop
    nop
    dec ebp
    jg .loop
    
    xor edi,edi
    mov eax,231
    syscall
