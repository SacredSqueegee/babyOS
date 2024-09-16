#include "kernel.h"
#include "idt.h"
#include <stddef.h>
#include <stdint.h>

uint16_t* video_mem = 0;

// TODO: Make this a struct
uint16_t terminal_row = 0;
uint16_t terminal_col = 0;

// Terminal Functions
// --------------------------------------------------------------------
void terminal_init()
{
    // Initialize terminal vars
    video_mem = (uint16_t*)0xB8000;
    terminal_row = 0;
    terminal_col = 0;

    // Clear terminal
    for(int i=0; i<(VGA_WIDTH*VGA_HEIGHT); i++)
    {
        video_mem[i] = 0x0020;  // Fill buffer with black spaces
    }
}
uint16_t terminal_make_char(char c, char color)
{
    return (color << 8) | c;
}

void terminal_putchar(int x, int y, char c, char color)
{
    video_mem[(y * VGA_WIDTH) + x] = terminal_make_char(c, color);
}

void terminal_writechar(char c, char color)
{
    // TODO: Will need to update this if we want to add scrolling support

    // Handle special characters
    switch (c) {
        case '\n':
            terminal_col = 0;
            terminal_row++;

            // loop back to top
            if (terminal_row >= VGA_HEIGHT)
                terminal_row = 0;
            return;
            
        case '\t':
            terminal_col += 4;

            if(terminal_col >= VGA_WIDTH)
            {
                terminal_col = terminal_col - VGA_WIDTH;

                // loop back to top
                if (terminal_row >= VGA_HEIGHT)
                    terminal_row = 0;
            }
            return;
    }

    terminal_putchar(terminal_col, terminal_row, c, color);
    terminal_col++;

    // loop back around on next row
    if(terminal_col >= VGA_WIDTH)
    {
        terminal_col = 0;
        terminal_row++;

        // Loop back to top
        if(terminal_row >= VGA_HEIGHT)
            terminal_row = 0;
    }
}


// String Functions
// --------------------------------------------------------------------
size_t strlen(const char* str)
{
    size_t len = 0;
    while(str[len])
        len++;

    return len;
}

void print(const char* str)
{
    size_t len = strlen(str);
    for(int i=0; i<len; i++)
        terminal_writechar(str[i], 0x0f);
}


void kernel_main()
{
    terminal_init();

    char* string = "Hello, World!\n\tand\nHello, Kernel! :)";
    print(string);

    terminal_putchar(40, 15, 'X', 0x0f);

    idt_init();
}

