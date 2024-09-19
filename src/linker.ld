ENTRY(_start)
OUTPUT_FORMAT(binary)
SECTIONS
{
    . = 1M;
    .text : ALIGN(4096)
    {
        /*KEEP(*(.text._start))      Ensure that our kernel.asm _start symbol is the first thing in the object file. Otherwise shit will break when the bootloader tries to hand over control to addr 0x100000 if our kenrel.asm _start isn't there */
        *(.text)
    }

    .rodata : ALIGN(4096)
    {
        *(.rodata)
    }

    .data : ALIGN(4096)
    {
        *(.data)
    }

    .bss : ALIGN(4096)
    {
        *(COMMON)
        *(.bss)
    }

    .asm : ALIGN(4096)
    {
        KEEP(*(.asm))
    }

}
