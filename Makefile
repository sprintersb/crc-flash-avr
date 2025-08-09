CC = avr-gcc
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
STRIP = avr-strip
NM = avr-nm

MCU ?= atmega8

EXE = main.elf

EXE0 = 0.elf

.PHONY: help all run show-crc force

help:
	@echo ""
	@echo "Makefile usage examples:"
	@echo "    make all                # Build all objects and ELF."
	@echo "    make all RUN=0          # Build all for no simulation."
	@echo "    make run                # Build all objects and simulate"
	@echo "                            # ELF with the AVRtest simulator."
	@echo "    make run MCU=attiny88   # Build for ATtiny88 and simulate."
	@echo "    make show-crc           # Show the CRC value."
	@echo "    make clean              # Remove all generated files."
	@echo ""

all: $(EXE)

RUN ?= 1

AVRTEST_HOME := $(dir $(shell which avrtest))

#---------------------------------------------------------------------------
# http://make.mad-scientist.net/papers/advanced-auto-dependency-generation/

C_SOURCE = main.c crc-flash.c

OBJS := $(C_SOURCE:%.c=%.o)

DEPDIR := .deps
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.d

$(DEPDIR): ; @mkdir -p $@

DEPFILES := $(C_SOURCE:%.c=$(DEPDIR)/%.d)
$(DEPFILES):

include $(wildcard $(DEPFILES))

#---------------------------------------------------------------------------
# This example is simple enough (does not require AVR I/O) so that we
# can use AVRtest to simulate $(EXE).  avrtest.h is included with -include,
# and the C code detects presence with #ifdef AVRTEST_H.  This allows to
# print the CRC values from the AVR program without using printf.
# When no simulation shou be performed, then: make ... RUN=0.

ifeq ($(RUN),1)

# Determine the folder where the avrtest executable lives, but
# only when the user didn't make ... AVRTEST_HOME=...
ifeq ($(AVRTEST_HOME),)
$(warning AVRtest not found: simulating $(EXE) is disabled.)
$(warning For AVRtest see https://github.com/sprintersb/atest)
else
$(inform using AVRTEST_HOME=$(AVRTEST_HOME))

IAVRTEST := -include $(AVRTEST_HOME)avrtest.h
EXIT_O := $(AVRTEST_HOME)exit-$(MCU).o

$(OBJS) $(EXE) $(EXE0): $(EXIT_O)

$(EXIT_O):
	@echo "== $@"
	cd $(AVRTEST_HOME); make $(notdir $@) CC_FOR_AVR=$(CC)
	@[ -f $@ ] || (echo "$(MCU) not supported by $(CC)" 1>&2 && exit 1)

run: $(EXE)
	@echo "== run $<"
	$(shell bin/avrtest-elf.sh $<) $< -e $(TEXT_START) -v $(AARGS)
endif
endif

#---------------------------------------------------------------------------
# Some additional dependencies.

$(OBJS) : .EXTRA_PREREQS = Makefile s-vars

# Update the contents of file $1 with string $2, but only when $1 doesn't
# already exist, or when the contents of $1 differ from $2.
Update = ([ ! -f $1 ] || [ "x$$(cat $1)" != "x$2" ]) && (echo "$2" > $1) || true

s-vars: force
	$(call Update,$@,$(MCU):$(RUN):$(ARGS))

#---------------------------------------------------------------------------
# Let the PC compute the CRC of the tentative $(EXE0).

# The binary files that contribute to the CRC.
# Their order is as expected by gen-crc.x.
BINS := text.bin data.bin rodata.bin

# DumpSection: Dump an output section like .text to text.bin.
# $1: The section name without leading '.' (dot).
# $2: File name of the result.
DumpSection = $(OBJCOPY) $< -O binary /dev/null --dump-section .$(strip $1)=$(strip $2) > /dev/null 2>&1

# Write output section .text to binary file text.bin etc.
# When the output section doesn't exist, produce an empty file.
%.bin: $(EXE0)
	@echo "== $@"
	$(call DumpSection,$*,$@) || touch $@
	touch $@
	@ls -l $@

# Set C variable $1 to the value of $(EXE0)'s symbol $2.
VarSymbol = const addr_t $1 = $(shell bin/symbol-value.sh $(EXE0) $2); // $2

syms.def: $(EXE0)
	@echo "== $@"
	echo "// Auto-generated from $(EXE0). Do not change." > $@
	echo "$(call VarSymbol,text_start  ,__vectors)" >> $@
	echo "$(call VarSymbol,text_end    ,__data_load_end)" >> $@
	echo "$(call VarSymbol,crc_address ,crc_value)" >> $@
	echo "$(call VarSymbol,rodata_start,__rodata_load_start)" >> $@

# This program runs on the PC and computes the CRC of $(EXE0).
gen-crc.x: gen-crc.c crc-flash.h syms.def
	@echo "== $@"
	gcc $< -O2 -std=gnu99 -Wall -Werror -o $@

# This file contains the CRC of $(EXE0) as ASCII text.
crc.txt: $(BINS) gen-crc.x
	@echo "== $@"
	./gen-crc.x $(BINS) > $@
	@echo ":: crc.value = $$(cat $@)"

show-crc: crc.txt force
	@echo "== $@"
	@echo ":: crc.value = $$(cat $<)"

#---------------------------------------------------------------------------
# Options, compiling, linking.

WARN  = -Wall
DEBUG = -dp -save-temps
OPTIMIZE = -Os -fdata-sections -ffunction-sections

CFLAGS += -mmcu=$(MCU) -std=gnu99
CFLAGS += $(DEBUG) $(OPTIMIZE) $(WARN) $(IAVRTEST) $(ARGS)

TEXT_START = 0x10
TextStart = -Ttext=$(strip $1) -Wl,--defsym,__TEXT_REGION_ORIGIN__=$(strip $1)

LDFLAGS = $(CFLAGS) $(call TextStart,$(TEXT_START)) -mrelax -Wl,--gc-sections

%.o: %.c
%.o: %.c $(DEPDIR)/%.d | $(DEPDIR)
	@echo "== $@"
	$(CC) $< -c -o $@ -std=c99 $(CFLAGS) $(DEPFLAGS)

Map = -Wl,-Map,$(@:.elf=.map)
Link = $(CC) $(LDFLAGS) -o $@ $^ $(Map) -Wl,--defsym,crc.value=$(strip $1)

DumpElf = $(OBJDUMP) -d $@ > $(@:.elf=.lst)
StripDebug = $(STRIP) -g $@

$(EXE0): $(OBJS)
	@echo "== $@"
	$(call Link,0xcafe)
	$(call StripDebug)
	$(call DumpElf)

$(EXE): .EXTRA_PREREQS = crc.txt
$(EXE): $(OBJS)
	@echo "== $@"
	$(call Link,$(shell cat crc.txt))
	$(call StripDebug)
	$(call DumpElf)
	@$(NM) $@ | grep ' crc_value$$' || true
	@$(NM) $@ | grep ' crc\.value$$' || true

.PHONY: bin elf elf0

elf0: $(EXE0)
elf:  $(EXE)

bin: $(BINS)
	@echo "== $@..."
	ls -al $^

clean:
	rm -f -- $(wildcard *.[isox] *.elf *.lst *.bin *.map *.res *.out)
	rm -f -- $(wildcard syms.def crc.txt s-vars)
	rm -rf -- $(wildcard $(DEPDIR))

#---------------------------------------------------------------------------
# Images

.PHONY: png svg

png svg:
	cd images; make $@
