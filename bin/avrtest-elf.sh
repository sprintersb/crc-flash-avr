#!/usr/bin/env sh

# Determine the right avrtest executable and -mmcu
# like:  avrtest-xmega -mmcu=avrxmega3
# $1 = ELF file
# $2 = Optional _log

# Usage
# $(avrtest-elf <elf-file>) ...
# $(avrtest-elf <elf-file> _log) ...

elf="$1"

me="$(basename $0)"

# Get the core arch and avrtest flavour.
arch=$(avr-readelf -h "$elf" \
	   | grep Flags | sed -e "s/.*avr://" | sed -e "s/,.*//" )

if [ "$arch" -gt 100 ]; then
    sim=-xmega
    arh=-mmcu=avrxmega$(($arch - 100))
elif [ "$arch" -eq 100 ]; then
    sim=-tiny
elif [ "$arch" -ge 2 ]; then
    arh=-mmcu=avr$arch
else
    echo "$me: error: bad arch avr:$arch"
    exit 1
fi

if [ "$arch" -eq 103 ]; then
    # For all devices in avrxmega3, except:
    #    ATmega808/9, ATmega1608/9, ATmega3208/9, ATmega4808/9
    # flash is seen in RAM address space at address 0x8000, which is also
    # the avrtest default.
    # For the mentioned devices, the flash mirror starts at 0x4000.
    2>1 devinfo=$(avr-readelf --string-dump=.note.gnu.avr.deviceinfo "$elf")
    case $devinfo in
	*atmega80[89]* | *atmega160[89]* | *atmega320[89]* | *atmega480[89]* )
	    pm="-pm 0x4000"
    esac
fi

echo avrtest${sim}$2 ${arh} ${pm}


