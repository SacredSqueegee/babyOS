; WARN: ATA commands in this bootloader really aren't compliant and do not adhear
;       to recomended best practices.

; $     -> Current line addr
; $$    -> Beginning of current section addr (think .text, .data, etc...)

; INFO: NASM is not a fan when we use far jumps to set the CS register, suppress this
;       warning as warnings are set as errors
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
; Code Section - Real Mode
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
    
    ; BUG: Something in the below code breaks qemu
    ;       When reading the ATA drive later on we get an error if we used this code to check for a drive
    ;       Bochs works just fine for some reason...
    ;       Maybe we need to reset the drive or check something for qemu???

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

    ; INFO: When using QEMU you have to read the sector of data from the identify command otherwise
    ;       the ATA read of the kernel data breaks later on. It will read the first sector just fine, but
    ;       any subsequent secotr read just breaks for some reason...
    ;       
    ;       Bochs does not care about this...

    ; Read IDENTIFY info - 256 16-bit data values
    .read_ident_info:
        ; Check if data is ready to read (See if DRQ bit is set)
        .poll:
            ; TODO: add time out error check
            mov dx, 0x1F7
            in al, dx           ; read status into al
            test al, 0b00001000 ; Test if DRQ bit is set
            jz .poll            ; Keep looping till DRQ is set(ready to read data)

        ; Read in sector of data
        mov cx, 256
        mov dx, 0x1F0
        mov di, 0x7e00  ; Read IDENTIFY sector into 0x7e00 (es:di)
        rep insw        ; Read ECX bytes from port DX into memory address ES:EDI
                        ; this reads 256 16-bit values(1 sector) from port 0x1F0 into the address as ES:EDI


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

    ; Done reading kernel to memory! :)
    ; Start kernel execution
    jmp CODE_SEG:0x0100000



; No more instructions past here...
; ---------------------------------

; Reads data from ATA disk into memroy
; *** Only works with MASTER drive on primary ATA Bus
; *** Utilizes 28-bit PIO
; *** Also assumes standard port addresses for ATA
; ***   I/O ports:      0x1F0 - 0x1f7
; ***   Control ports:  0x3F6 - 0x3F7
; ***   Maybe enumerate PCI to verify this???
;
;   eax -> LBA - Read start sector
;   ecx -> Number of sectors to read [max 255] -> sending 0 reads 256 sectors
;   edi -> Address in memory to write sectors to
ata_lba_read:
    ; Save LBA
    mov ebx, eax

    ; Select MASTER drive and send highest 4-bits of LBA to the drive/head register
    ; Top 4 bits are configurstions; Bottom 4 bits are the highest 4-bits of LBA
    ; set port 0x1F6 = (LBA >> 24) | 0xE0
    shr eax, 24
    or  eax, 0xE0    ; 0xE? -> selects master drive for LBA addressing, ? -> high 4-bits of LBA
    mov dx, 0x1F6
    out dx, al

    ; Clear Features Register
    xor al, al
    mov dx, 0x1F1
    out dx, al

    ; Send Number of Secotrs to read
    mov eax, ecx
    mov dx, 0x1F2
    out dx, al

    ; Restore LBA
    mov eax, ebx

    ; Send low 8-bits of LBA
    mov dx, 0x1F3   ; LBAlo
    out dx, al

    ; Send next 8-bits of LBA
    shr eax, 8
    mov dx, 0x1F4   ; LBAmid
    out dx, al

    ; Send next 8-bits of LBA
    shr eax, 8
    mov dx, 0x1F5   ; LBAhi
    out dx, al

    ; Send Read Sectors Command
    mov al, 0x20
    mov dx, 0x1F7
    out dx, al

    .read_another_sector:
        ; Save remaining sector count
        push ecx

        ; Check if data is ready to read
        .poll:
            mov dx, 0x1F7
            in al, dx           ; read status into al
            test al, 0b00001000 ; Test if DRQ bit is set
            jz .poll            ; Keep looping till DRQ is set(ready to read data)

        ; Read in sector of data
        mov ecx, 256
        mov dx, 0x1F0
        rep insw        ; Read ECX bytes from port DX into memory address ES:EDI
                        ; this reads 256 16-bit values(1 sector) from port 0x1F0 into the address as ES:EDI

        ; delay ~400ns because spec sheet says to
        mov dx, 0x1F7
        mov ecx, 15
        .delay:
            in al, dx   ; Read status register
            loop .delay

        ; re-load remaining sector count and keep reading if there are more sectors to read
        pop ecx
        loop .read_another_sector

    ; done reading secotrs to memory!
    ret


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
