#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdbool.h>
#include <string.h>

typedef unsigned addr_t;

#include "crc-flash.h" // crc_t
#include "syms.def"    // Auto-generated from 0.elf.

char *me = "";

/* Diagnostics */

void error (const char *fmt, ...)
{
    fprintf (stderr, "%s: error: ", me);
    va_list args;
    va_start (args, fmt);
    vfprintf (stderr, fmt, args);
    fprintf (stderr, "\n");
    va_end (args);

    exit (EXIT_FAILURE);
}


// Verbatim copy from AVR-LibC's documentation of <util/crc16.h>
// so that the outcome is the same like for _crc16_update on AVR.

static inline uint16_t
_crc16_update (uint16_t crc, uint8_t a)
{
    crc ^= a;
    for (int i = 0; i < 8; ++i)
    {
        if (crc & 1)
            crc = (crc >> 1) ^ 0xA001;
        else
            crc = crc >> 1;
    }
 
    return crc;
}


/* Update CRC from the bytes in file STREAM, skipping SKIP_LEN bytes
   starting at byte number SKIP_START, where byte counting starts at 0. */

static crc_t
crc_update_from_file (crc_t crc, FILE *stream,
                      addr_t skip_start, addr_t skip_len)
{
    for (addr_t n = 0;; ++n)
    {
        int c = fgetc (stream);
        if (feof (stream))
            return crc;
        else if (n < skip_start || n >= skip_start + skip_len)
            crc = _crc16_update (crc, (uint8_t) c);
    }
}


/* Same, but read from file FILENAME.  */

static crc_t
crc_update_from_filename (crc_t crc, const char* filename,
                          addr_t skip_start, addr_t skip_len)
{
    FILE *stream = fopen (filename, "rb");
    if (! stream)
        error ("cannot open file %s for reading", filename);

    crc = crc_update_from_file (crc, stream, skip_start, skip_len);
    fclose (stream);
    return crc;
}


int main (int argc, char *argv[])
{
    me = argv[0];

    if (argc != 1 + 3)
        error ("usage: %s text.bin data.bin rodata.bin", me);

    // Names of the *.bin files.
    const char *const text_bin = argv[1];
    const char *const data_bin = argv[2];
    const char *const rodata_bin = argv[3];

    // Adjust the address of crc_value so that it is relative to
    // the start of .text section.
    const addr_t crc_loc = crc_address - text_start;

    crc_t crc = 0;
    crc = crc_update_from_filename (crc, text_bin, crc_loc, sizeof (crc_t));

    if (rodata_start == 0)
        crc = crc_update_from_filename (crc, rodata_bin, 0, 0);

    crc = crc_update_from_filename (crc, data_bin, 0, 0);

    if (rodata_start > 0)
        crc = crc_update_from_filename (crc, rodata_bin, 0, 0);

    printf ("0x%x", (unsigned) crc);

    return EXIT_SUCCESS;
}

