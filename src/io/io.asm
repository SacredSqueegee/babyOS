bits 32
section .asm

global inb, inw, ind
global outb, outw, outd

; Remember we are using the 32-Bit x86 calling convention
;   *also remember, the stack grows DOWN
;
; Calling Convention:
; -----------------------------------------
; Return Value:     eax, edx
; Parameters:       stck (right to left)
; Scratch regs:     eax, ecx, edx
; Preserved regs:   ebx, esi, edi, ebp, esp
;
; When calling a function you push the parameters onto the stack
;   and start by pushing the last parameter first.
;
; What the stack looks like when calling a function:
;
; High addr |   ...
;   .       |   param_3                 [ebp + 16]
;   .       |   param_2                 [ebp + 12]
;   .       |   param_1                 [ebp + 8]
;   .       |   (return addr)           [ebp + 4]
;   .       |   (saved value of ebp)    [ebp]
;   .       |   (local stack var)       [ebp - 4]
;   .       |   ...
; Low addr  |   ...


; uintX_t inX(uint8_t port)
;   - *where X is size: 8(b), 16(w), 32(d)
;   - Reads in data from specified port
;
; Parameters:
;   param_1: uint8_t port
;
; Returns:
;   uintX_t
;       where X is the bit size: 8, 16, 32
; ----------------------------------------------------
inb:
    ; prologue
    push ebp
    mov ebp, esp

    xor eax, eax
    mov dx, word[ebp + 8]   ; dx = param_1
    in al, dx

    ; epilogue
    pop ebp
    ret

inw:
    push ebp
    mov ebp, esp

    xor eax, eax
    mov dx, word[ebp + 8]
    in ax, dx

    pop ebp
    ret

ind:
    push ebp
    mov ebp, esp

    xor eax, eax
    mov dx, word[ebp + 8]
    in eax, dx

    pop ebp
    ret


; void outX(uint8_t port, uintX_t data)
;   - *where X is size: b(8), w(16), d(32)
;   - Outputs data to a specified port
;
; Parameters:
;   param_1: uint8_t port
;   param_2: uintX_t data
;       where X is the bit size: 8, 16, 32
; ----------------------------------------------------
outb:
    push ebp
    mov ebp, esp

    mov dx, word[ebp + 8]
    mov al, byte[ebp+12]
    out dx, al

    pop ebp
    ret

outw:
    push ebp
    mov ebp, esp

    mov dx, word[ebp + 8]
    mov ax, word[ebp + 12]
    out dx, ax

    pop ebp
    ret

outd:
    push ebp
    mov ebp, esp

    mov dx, word[ebp + 8]
    mov eax, dword[ebp + 12]
    out dx, eax

    pop ebp
    ret

