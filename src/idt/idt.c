#include "idt.h"
#include "config.h"
#include "kernel.h"
#include "memory.h"
#include <stdint.h>


extern void idt_load(struct idtr_descriptor* ptr);

struct idt_entry idt_entries[BABYOS_TOTAL_INTERRUPTS];
struct idtr_descriptor idtr_desc;


void idt_zero()
{
    print("Divide by zero error\n");
}


void idt_set(int interrupt_nu, void* address)
{
    struct idt_entry* entry = &idt_entries[interrupt_nu];
    entry->offset_low = (uint32_t) address & 0x0000ffff;
    entry->offset_high = (uint32_t) address >> 16;
    entry->selector = KERNEL_CODE_SELECTOR;                         // segment selector for interrupt
    entry->zero = 0x00;                                             // reserved
    entry->type = 0b1110;                                           // 32-bit interrupt gate
    entry->s = 0;                                                   // osdev wiki on IDT says this should be 0
    entry->dpl = 0b11;                                              // Ring-3 (user space)
    entry->p = 1;                                                   // set for valid interrupt
}

void idt_init()
{
    memset(idt_entries, 0, sizeof(idt_entries));
    idtr_desc.size = sizeof(idt_entries) - 1;
    idtr_desc.offset = (uint32_t) idt_entries;

    idt_set(0, idt_zero);

    // Load IDT
    idt_load(&idtr_desc);
}

