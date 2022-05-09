
# This is where Make looks for the source files!
VPATH = src/

all: z80-monitor.bin

z80-monitor.bin: src/*.asm

.SUFFIXES: .bin .asm

.asm.bin:
	z80asm -Isrc/ -o $@ $<
