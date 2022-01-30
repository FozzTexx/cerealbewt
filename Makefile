AS=nasm

default: cboot.bin vicmon.bin

cboot.bin: cboot.asm

vicmon.bin: vicmon.asm

%.bin: %.asm
	$(AS) $(ASFLAGS) -fbin -o $@ -l $(basename $@).lst $<
