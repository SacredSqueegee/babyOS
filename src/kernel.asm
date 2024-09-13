; Enter Protected mode here...
bits 32

CODE_SEG equ 0x08
DATA_SEG equ 0x10


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





    jmp $
