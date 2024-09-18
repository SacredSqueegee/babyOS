#ifndef IO_H
#define IO_H

#include <stdint.h>

uint8_t inb(uint8_t port);
uint16_t inw(uint8_t port);
uint32_t ind(uint8_t port);

void outb(uint8_t port, uint8_t data_b);
void outw(uint8_t port, uint16_t data_w);
void outd(uint8_t port, uint32_t data_d);

#endif // !IO_H

