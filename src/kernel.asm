; INFO: NASM is not a fan when we use far jumps to set the CS register, suppress this
;       warning as warnings are set as errors
[warning -reloc-rel]

bits 32

CODE_SEG equ 0x08
DATA_SEG equ 0x10

extern kernel_main      ; Entry into the C portion of our kernel


global _start
_start:
    ; Set up data sgement selectors before we access memory so we don't generate a panic
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov ebp, 0x00200000
    mov esp, ebp


    call kernel_main


    jmp $


; Ensure kernel.asm is alinged on a 16-byte boundary so we don't screw up our jump into C
ALIGNMENT_BOUNDARY equ 16
times ALIGNMENT_BOUNDARY - (($-$$) % ALIGNMENT_BOUNDARY) db 0x00

