#include <stdint.h>
#include <avr/pgmspace.h>
#include <util/crc16.h>

#include "crc-flash.h"

// Reding values from flash ROM.

#ifdef __AVR_HAVE_ELPM__
    typedef uint_farptr_t addr_t;
    #define PGM_READ_U8(x) pgm_read_byte_far (x)
    #define PGM_READ_U16(x) pgm_read_word_far (x)
    #define PGM_READ_U32(x) pgm_read_dword_far (x)
    #define ADDR(x) pgm_get_far_address (x)
#else
    typedef uintptr_t addr_t;
    #define PGM_READ_U8(x) pgm_read_byte (x)
    #define PGM_READ_U16(x) pgm_read_word (x)
    #define PGM_READ_U32(x) pgm_read_dword (x)
    #define ADDR(x) ((addr_t) &(x))
#endif


// Global asm with arguments is only supported since GCC v15, therefore
// wrap the asm into a naked function.
__attribute__((__used__,__unused__,__naked__))
static void define_crc_value (void)
{
    __asm (".pushsection .progmemx.data.crc_value,\"a\",@progbits\n"
           ".global crc_value\n"
           ".type crc_value,@object\n"
           "crc_value:\n"
           "    .%0byte crc.value\n"
           ".size crc_value, . - crc_value\n"
           ".popsection"
           :: "n" (sizeof (crc_value)));
}


// Read crc_value from somewhere in flash ROM.
crc_t read_crc_value (void)
{
    if (sizeof (crc_t) == 2)
        return PGM_READ_U16 (ADDR (crc_value));
    if (sizeof (crc_t) == 4)
        return PGM_READ_U32 (ADDR (crc_value));
    return 0;
}


/* The rest of the module deals with computing the CRC over the flash ROM.  */


// Symbols defined in the default linker script.
// The rodata symbols are only defined when there is a rodata MEMORY region.
// The PROGMEM attribute is only required for AVRrc so that the compiler
// adds 0x4000 when it takes the value of respective symbols (GCC PR71948).
// Notice that the symbol values are not 16-bit values in general.
extern const PROGMEM char __vectors;
extern const PROGMEM char __data_load_end;
extern const PROGMEM char __rodata_load_start;
extern const PROGMEM char __rodata_load_end;


/* Update CRC from ROM locations START...END.  */

static crc_t
crc_update_from_flash (crc_t crc, addr_t start, addr_t end)
{
    for (addr_t addr = start; ; ++addr)
    {
        crc = _crc16_update (crc, PGM_READ_U8 (addr));
        if (addr == end)
            break;
    }

    return crc;
}

// If AVRtest is available, we can nicely print the used addresses without
// invoking printf.  Notice that LOG_XX takes exactly one host % in fmt.
#ifdef AVRTEST_H
#define printf(fmt, x) LOG_PFMT_U24 (PSTR (fmt), x)
#else
#define printf(fmt, x)
#endif // Have AVRtest

/* Compute the CRC over MEMORY regions text, and rodata if it exists.
   Don't include crc_value in the resulting CRC.  */

crc_t get_flash_crc (void)
{
    crc_t crc = 0;
    addr_t start1 = ADDR (__vectors);
    addr_t end1   = ADDR (crc_value);
    crc = crc_update_from_flash (crc, start1, end1 - 1);

    addr_t start2 = end1 + sizeof (crc_value);
    addr_t end2   = ADDR (__data_load_end);
    if (start2 != end2)
        crc = crc_update_from_flash (crc, start2, end2 - 1);

    printf ("start1 = 0x%x\n", start1);
    printf ("end1   = 0x%x\n", end1);
    printf ("start2 = 0x%x\n", start2);
    printf ("end2   = 0x%x\n", end2);

    // Following is required when there is a rodata MEMORY region.
    // Without a rodata region, the .rodata input sections are
    // located in the .text output section.

#if defined(__AVR_HAVE_FLMAP__)                                     \
    && defined(__AVR_RODATA_IN_RAM__) && __AVR_RODATA_IN_RAM__ == 0

    addr_t start3 = ADDR (__rodata_load_start);
    addr_t end3   = ADDR (__rodata_load_end);
    if (start3 != end3)
        crc = crc_update_from_flash (crc, start3, end3 - 1);
    printf ("start3 = 0x%x\n", start3);
    printf ("end3   = 0x%x\n", end3);
#endif // Have rodata region.
    
    return crc;
}
