; $     -> Current line addr
; $$    -> Beginning of current section addr (think .text, .data, etc...)

[warning -reloc-abs]
USE16           ; 16-bit assembly
ORG 0x7c00      ; Compute labels and offsets from this load address

; Create "defines" for our segment selectors for easy use
CODE_SEG equ 0b0000000000001000     ; GDT Index = 0b0000000000001 = 1
                                    ; TI        = 0b0 = 0 = GDT
                                    ; RPL       = 0b00 = 0 = Highest Privilege Level
DATA_SEG equ 0b0000000000010000     ; GDT Index = 0b0000000000010 = 2
                                    ; TI        = 0b0 = 0 = GDT
                                    ; RPL       = 0b00 = 0 = Highest Privilege Level


; Setup a fake BIOS Parameter Block
jmp short end_bpb
nop
times 33 db 0x00    ; fill BPB with junk
end_bpb:

; ---------------------------------------------------------------------------------------------------
; Code Section
; ---------------------------------------------------------------------------------------------------

; Ensure our CS register is properly updated to 0x00 by making a far jump(only far jmp's change CS reg)
jmp 0x00:entry
entry:
    ; Setup rest of segment registers (zero them as we are using org 0x7c00)
    cli         ; Disable interrupts while we do critical setup
    xor ax, ax
    mov ds, ax
    mov es, ax

    ; Setup stack at 0x7c00 (grows down towards 0x0000)
    mov ss, ax      ; SS = 0x00
    mov sp, 0x7c00  ; Stack Pointer = SS:SP = 0x000:0x7c00 = 0x7c00
    sti


    ; TODO: Do real mode stuff here...

    ; Clear Screen
    ; ------------
    xor ah, ah
    mov al, 3
    int 0x10
    

    ; Identify ATA drive
    ; ------------------

    ; Select Master Drive on ATA Primary Bus
    mov al, 0xA0
    mov dx, 0x1F6
    out dx, al              ; Write 0xA0(Master Drive) to 0x1F6(Primary bus - drive/head register)

    ; zero out sector, LBAlo, LBAmid, LBAhi registers
    mov dx, 0x1F5
    .loop:
        xor al, al
        out dx, al              ; Write 0x00 to dx (sector, LBAlo, LBAmid, LBAhi)

        dec dx
        cmp dx, 0x1F1
        jne .loop

    ; Send IDENTIFY command (0xEC) to Command IO port (0x1F7)
    mov al, 0xEC
    mov dx, 0x1F7
    out dx, al

    ; Read status register
    mov dx, 0x1F7
    in al, dx

    cmp al, 0x00
    je .bad

    ; Something is on this port, poll status reg until bit 7 clears
    .loop_2:
        ; Read status reg
        mov dx, 0x1F7
        in al, dx
        
        ; TODO: Break poll at some point when it's determined that this is a non-comforming
        ;       ATAPI drive, and check LBAmid and LBAhi. If they are non-zero this is not
        ;       an ATA drive. If they are zero, this is an ATA drive.

        ; Check BSY bit until it clears
        shr al, 7
        cmp al, 1
        je .loop_2

    ; NO longer busy, check for DRQ or ERR bits
    in al, dx

    ; Check ERR bit
    mov cl, al
    and cl, 0b00000001
    cmp cl, 1
    je .bad_errbit      ; ERR bit set, not good

    ; Check DRQ bit
    and al, 0b00001000
    shr al, 3
    cmp al, 1
    jne .loop_2         ; Something is wrong, try polling again and redo
    ; DRQ set, ready to read IDENTIFY info, but we don't care, ATA good to go!
    
    ; print ata status message
    .good:
        mov ax, word msg_g
        mov cx, msg_g.len
        jmp .print
    .bad:
        mov ax, word msg_b
        mov cx, msg_b.len
        jmp .print
    .bad_errbit:
        mov ax, word msg_b_errbit
        mov cx, msg_b_errbit.len

    .print:
        xor dx, dx
        call print_str
    

    ; Display message that we are switching to Pmode and loading Kernel
    ; -----------------------------------------------------------------
    ; TODO: should we do this???

    jmp $

    ; Done with real mode, jump to pMode
    jmp enable_pMode

; --------------------------
; Real Mode Helper Functions
; --------------------------

; Prints string to screen in real mode
; ax -> pointer to string
; cx -> string len
; dh -> row
; dl -> col
print_str:
    mov bp, ax
    mov al, 1
    mov bl, 0x07
    mov ah, 0x13
    int 0x10
    ret


; Enters protected mode and jumps to the kernel loading function
enable_pMode:
    cli
    ; TODO: disable NMI

    ; WARN: The below method is not portable and should only be used as a last resort
    ;       See OSDev wiki for more information
    ; TODO: Implement a better A20 enabling method

    ; Enable A20 using fast method
    in al, 0x92
    or al, 2
    out 0x92, al
    
    ; Load the GDT Descriptor into the GDTR
    lgdt [dword GDT_descriptor]

    ; Enable Protected Mode
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax

    ; Do far jump to set CS to correct segment selector value
    jmp CODE_SEG:load_kernel



; ---------------------------------------------------------------------------------------------------
; Protected Mode Section
; ---------------------------------------------------------------------------------------------------
use32
load_kernel:

    ; Setup Segment Selectors now that we are in 32-bit pMode
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov ebp, 0x00200000
    mov esp, ebp


    ; Load our kernel into memory
    mov eax, 1              ; Start reading at sector 1 (the sector after our bootlaoder on the disk)
    mov ecx, 100            ; Read 100 secotrs
    mov edi, 0x0100000      ; Load data to address 0x0100000 = 1MiB
    call ata_lba_read



    jmp $



; No more instructions past here...
; ---------------------------------

ata_lba_read:
    jmp $


; ---------------------------------------------------------------------------------------------------
; Data Section
; ---------------------------------------------------------------------------------------------------
; Global Descriptor Table
; -----------------------
GDT_start:

; offset 0x00
GDT_null:
    times 8 db 0x00 ; NULL GDT entry

; offset 0x08
GDT_code:           ; CS should point to this
    ; Base  = 0x00000000    (32-bits)
    ; Limit = 0xfffff       (20-bits)
    ;   0xfffff * 4 KiB page granularity
    ;   0xfffff * 0x1000 = 0xfffff000
    ;   0xfffff000 addresses 4GiB of 4KiB pages
    ;
    dw 0xffff       ; Segment limit first 0-15 bits
    dw 0x0000       ; Base - first 0-15 bits
    db 0x00         ; Base - mid  16-23 bits
    db 0x9a         ; Access byte
                    ; 0x9a = 0b10011010
                    ;   - P   = 1   -> Valid segment
                    ;   - DPL = 00  -> Highest privilege
                    ;   - S   = 1   -> This is a code/data segment
                    ;   - E   = 1   -> This is a code segment (can execute)
                    ;   - DC  = 0   -> Code in this segment can only be executed from ring set in DPL
                    ;   - RW  = 1   -> Read access allowed
                    ;   - A   = 0   -> CPU will set this bit when first accessed
    db 0xcf         ; First 4-bits (0xc -> 0b1100) -> flags
                    ;   - G   = 1   -> Page granularity; Limit is in 4 KiB blocks
                    ;   - DB  = 1   -> This is a defining a 32-bit protected mode segment
                    ;   - L   = 0   -> This is NOT a long mode 64-bit code segment
                    ;   - reserved
                    ; last 4-bits  (0b1111) -> remaining limit bits
    db 0x00         ; Base - last 24-31 bits

; offset 0x10
GDT_data:           ; DS, SS, ES, FS, GS should point to this
    ; Base  = 0x00000000    (32-bits)
    ; Limit = 0xfffff       (20-bits)
    ;   - Limit is 4 GiB
    ;
    dw 0xffff       ; Segment limit first 0-15 bits
    dw 0x0000       ; Base - first 0-15 bits
    db 0x00         ; Base - mid  16-23 bits
    db 0x92         ; Access byte
                    ; 0x92 = 0b10010010
                    ;   - P   = 1   -> Valid segment
                    ;   - DPL = 00  -> Highest privilege
                    ;   - S   = 1   -> This is a code/data segment
                    ;   - E   = 0   -> This is a data segment (cannot execute)
                    ;   - DC  = 0   -> Data section grows up
                    ;   - RW  = 1   -> Write access allowed
                    ;   - A   = 0   -> CPU will set this bit when first accessed
    db 0xcf         ; First 4-bits (0xc -> 0b1100) -> flags
                    ;   - G   = 1   -> Page granularity; Limit is in 4 KiB blocks
                    ;   - DB  = 1   -> This is a defining a 32-bit protected mode segment
                    ;   - L   = 0   -> This is NOT a long mode 64-bit code segment
                    ;   - reserved
                    ; Last 4-bits (0xf -> 0b1111) -> remaining limit bits
    db 0x00         ; Base - last 24-31 bits

GDT_end:

; Define the GDT Descriptor sturcture that is loaded into GDTR to tell the CPU where to find our GDT
GDT_descriptor:
    .size:      dw GDT_end - GDT_start - 1  ; size of GDT in bytes - 1
    .offset:    dd GDT_start                ; linear address of the GDT(not physical, paging applies)



msg_b: db "[ERR] No ATA Drives"
    .len equ $-msg_b

msg_b_errbit: db "[ERR] ATA err bit set"
    .len equ $-msg_b_errbit

msg_g: db "[MSG] ATA Drive Found"
    .len equ $-msg_g

msg_notata: db "[ERR] Drive is not ATA"
    .len equ $-msg_notata



; Pad bootloader and define boot signature
times 510 - ($-$$) db 0x00
dw 0xAA55

