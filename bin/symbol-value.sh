#!/bin/bash

# Print the value of symbol $2 in ELF file $1.
# When there is no such symbol, print 0.
if [[ -f "$1" ]]; then
    sym=$(avr-readelf -s $1 | grep " $2\$" | awk '{ print $2 }')
    echo -n "0x${sym:-0}"
else
    echo "$(basename $0): error: $1: file not found" 1>&2
    exit 1
fi
