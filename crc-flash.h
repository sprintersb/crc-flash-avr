#ifndef CRC_FLASH_H
#define CRC_FLASH_H

#include <stdint.h>

typedef uint16_t crc_t;

#ifdef __AVR__

#include <avr/pgmspace.h>

extern PROGMEM const crc_t crc_value;

extern crc_t get_flash_crc (void);
extern crc_t read_crc_value (void);

#endif // AVR
#endif // CRC_FLASH_H
