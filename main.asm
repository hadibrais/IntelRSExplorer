; There are two input parameters. One of these macros must be defined: ADD, LOADSPEC, LOADSPECREPLAY, LOADNONSPEC, JUMPFORE, JUMPBACK, JUMPFORECOND, STORE1, STORE2, or BSWAP.
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
%elifdef LOADSPEC
%define LAT 4
%elifdef LOADSPECREPLAY
%define LAT 9
%elifdef LOADNONSPEC
%define LAT 5
%elifdef JUMPFORE
%define LAT 1
%elifdef JUMPBACK
%define LAT 1
%elifdef JUMPFORECOND
%define LAT 1
%elifdef STORE1
%define LAT 1
%elifdef STORE2
%define LAT 1
%elifdef BSWAP
%define LAT 2
%endif


BITS 64
DEFAULT REL

section .bss
align 4096
bufsrc: resb 8192

section .text

global _start
_start:

    lea rsi, [bufsrc]
    mov [bufsrc], rsi
    mov [bufsrc+2048], rsi
    nop
    
    lea rdi, [bufsrc-8]
    mov [bufsrc], rdi
    nop
    nop    
    
    mov ebp, SIZE
    mov r8d, SIZE+1
    nop
    nop

; The alignment has two affects:
; (1) The RS value at which the RS stalls counter value becomes larger than zero.
; (2) The absolute RS stalls values. The way these change does not follow an obvious pattern, but the difference is not significant.
; An alignment of 4 or larger increases effect (1) by 1.
align 4
.loop:
    ; Wait for the previous instructions to leave the RS.
    ; It turned out that the lfence doesn't really matter. It can be replaced with a nop.
    lfence
    nop
    nop
    nop
    
    ; The RS must be empty now.
    
    ; Start a new repetition with an empty RS.
;--------------------------------------------------ADD--------------------------------------------------
%ifdef ADD
; We can also use two adds and two NOPs, but it seems that a group of 4 uops some which are NOPs
; make the allocator wait longer, which is weird. So it's important to put the padding NOPs are the very end.
    add rax, rax
    add rax, rax
    add rax, rax
    add rax, rax
%if RS > 4
%rep (RS-4)/3
    add rax, rax
    add rax, rax
    add rax, rax
    add rax, rax
%endrep
%if ((RS-4)% 3) > 0
%rep 1 + ((RS-4)% 3)
    add rax, rax
%endrep
%rep 3 - ((RS-4)% 3)
    nop
%endrep
%endif
%endif
;--------------------------------------------------LOADSPEC--------------------------------------------------
%elifdef LOADSPEC
%rep RS
    mov rsi, qword [rsi]
%endrep

%if (RS% 4) > 0
%rep 4 - (RS% 4)
nop
%endrep
%endif
;--------------------------------------------------LOADSPECREPLAY--------------------------------------------------
%elifdef LOADSPECREPLAY
%rep RS
    mov rdi, qword [rdi+8]
%endrep

%if (RS% 4) > 0
%rep 4 - (RS% 4)
nop
%endrep
%endif
;--------------------------------------------------LOADNONSPEC--------------------------------------------------
%elifdef LOADNONSPEC
%rep RS
    mov rsi, qword [rsi+2048]
%endrep

%if (RS% 4) > 0
%rep 4 - (RS% 4)
nop
%endrep
%endif
;--------------------------------------------------JUMPFORE--------------------------------------------------
%elifdef JUMPFORE
%macro  jmpmacro 0 
    jmp     %%label  
%%label:
%endmacro
%rep 1+(RS-2)
    jmpmacro
    jmpmacro
%endrep

%if (((1+(RS-2))*2)% 4) > 0
%rep 4 - (((1+(RS-2))*2)% 4)
nop
%endrep
%endif
;--------------------------------------------------JUMPBACK--------------------------------------------------
%elifdef JUMPBACK
%assign tnumlast 2*(1+(RS-2))
%xdefine tlast .target %+ tnumlast
    jmp tlast
%assign tnum 0
%rep 1+(RS-2)
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

%if (((1+(RS-2))*2)% 4) > 0
%rep 4 - (((1+(RS-2))*2)% 4)
nop
%endrep
%endif
;--------------------------------------------------JUMPFORECOND--------------------------------------------------
%elifdef JUMPFORECOND

%macro  jmpmacro 0 
    jg     %%label  
%%label:
%endmacro

    dec r8d
    nop
    nop
    nop

    nop
    nop
    nop
    nop

%rep 1+(RS-2)
    jmpmacro
    jmpmacro
%endrep

%if (((1+(RS-2))*2)% 4) > 0
%rep 4 - (((1+(RS-2))*2)% 4)
nop
%endrep
%endif
;--------------------------------------------------STORE1--------------------------------------------------
; Hits the store buffer occupancy limit (RESOURCE_STALLS.SB) but not that of the RS.
; 3 STA uops and 1 STD uop can be dispatched per cycle.
%elifdef STORE1
%rep RS
    mov qword [rsi], rax
    mov qword [rsi], rax
    nop
    nop
%endrep
;--------------------------------------------------STORE2--------------------------------------------------
; Hits the RS occupancy limit before that of the SB.
; 3 STA uops and 1 STD uop can be dispatched per cycle.
; Odd RS occupancy is not supported and is rounded to even.
%elifdef STORE2
%if (RS% 2) > 0
%assign RS (RS-1)
%endif

%if RS = 4
    mov qword [rsi], rax
    mov qword [rsi], rax
    nop
    nop
%elif
%rep (RS - 4)
    mov qword [rsi], rax
%endrep
%if (RS% 4) > 0
    mov qword [rsi], rax
    nop
    nop
    nop
%endif
%endif

;--------------------------------------------------BSWAP--------------------------------------------------
%elifdef BSWAP

%if RS < 12
%rep RS/2
    bswap rax
%endrep
%if ((RS/2)% 4) > 0
%rep 4 - ((RS/2)% 4)
    nop
%endrep  
%endif  
%elif
%rep (RS/2) + ((RS-12)/14)
    bswap rax
%endrep
%if (((RS/2) + ((RS-12)/14))% 4) > 0
%rep 4 - (((RS/2) + ((RS-12)/14))% 4)
    nop
%endrep
%endif 
%endif

%endif
;---------------------------------------------------------------------------------------------------------
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
; This is a conservative estimate since it does not account for ROB stalls.
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
