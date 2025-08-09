#include <stdlib.h>
#include <avr/pgmspace.h>
#include "crc-flash.h"

// If AVRtest is available, we can nicely print the used addresses without
// invoking printf.  Notice that LOG_XX takes exactly one host % in fmt.
#ifdef AVRTEST_H
#define printf(fmt, x) LOG_PFMT_U24 (PSTR (fmt), x)
#else
#define printf(fmt, x)
#endif // Have AVRtest


int main (void)
{
    crc_t crc = get_flash_crc ();
    crc_t crc_val = read_crc_value ();

    printf ("flash_crc = 0x%x\n", crc);
    printf ("crc_value = 0x%x\n", crc_val);

    if (crc != crc_val)
        abort ();

    return 0;
}
