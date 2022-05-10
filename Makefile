SERIAL=/dev/ttyUSB0

VPATH = src/

all: z80-monitor.bin
	memsim2 -d $(SERIAL) -m 27256 -r -100 -e $<

z80-monitor.bin: src/*.asm

.SUFFIXES: .bin .asm

.asm.bin:
	z80asm -Isrc/ -o $@ $<
