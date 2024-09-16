#ifndef IDT_H
#define IDT_H

#include <stdint.h>


struct idtr_descriptor
{
    uint16_t size;
    uint32_t offset;
} __attribute__((packed));

struct idt_entry
{
    uint16_t offset_low;    // offset bits 0 - 15
    uint16_t selector;      // Segment Selector to use for interrupt
    uint8_t zero;           // unused, set to zero
    union {
        uint8_t type_attr;          // Combined Descriptor type and attribute fields
        struct                      // Individually accessable Type and attribute fields
        {
            uint8_t type : 4;       // Descriptor type
            uint8_t s : 1;          // Storage Segment
            uint8_t dpl : 2;        // Descriptor Priveledge Level
            uint8_t p : 1;          // Present
        } __attribute__((packed));
    };
    uint16_t offset_high;   // offset bits 16 - 31
} __attribute__((packed));

void idt_init();

#endif // !IDT_H

