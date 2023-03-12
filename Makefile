CFLAGS := -m16 -ffreestanding -nostartfiles -nodefaultlibs -nostartfiles

OBJCOPY ?= objcopy

all: tarea.img

clean:
	find . -type f -a \( -name '*.bin' -o -name '*.elf' \) -delete
	rm -vf tarea.img

run: tarea.img
	qemu-system-i386 -hda $<

tarea.img: boot.bin tarea.bin
	cat $^ >$@

boot.elf: boot.S boot.ld tarea.bin
	$(CC) $(CFLAGS) -DNUM_SECTORS=`./num_sectors.sh` -T boot.ld -o $@ $<

%.elf: %.S %.ld
	$(CC) $(CFLAGS) -T $*.ld -o $@ $<

%.bin: %.elf
	$(OBJCOPY) -O binary --only-section=.image $< $@
