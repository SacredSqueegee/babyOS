section .asm

; idt_load(uint32* address)
;   Loads the IDT Descriptor Structure into the IDTR 
;
; parameters:
;   - address: address of our IDT Descriptor Structure
global idt_load
idt_load:
    ; frame start
    push ebp
    mov ebp, esp

    mov ebx, [ebp+8]    ; mov address(param-1) into ebx
    lidt [ebx]          ; load value at address(IDT Descriptor Structure) into IDTR

    pop ebp
    ret
