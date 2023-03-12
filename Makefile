LD      ?= ld
OBJCOPY ?= objcopy

CFLAGS := -m16 -ffreestanding -nostartfiles -nodefaultlibs -nostartfiles -Wl,--no-check-sections

all: tarea.img

clean:
	find . -type f -a \( -name '*.bin' -o -name '*.elf' -o -name '*.o' \) -delete
	rm -vf tarea.img

run: tarea.img
	qemu-system-i386 $(QEMUFLAGS) -hda $<

tarea.img: boot.bin tarea.bin
	cat $^ >$@

boot.elf: boot.ld boot.S tarea.bin
	$(CC) $(CFLAGS) `./num_sectors.sh` -o $@ -T boot.ld boot.S

tarea.elf: tarea.ld tarea.S map1.o map2.o
	$(CC) $(CFLAGS) -o $@ -T $^

boot.bin: boot.elf
	$(OBJCOPY) -O binary --only-section=.mbr $< $@

tarea.bin: tarea.elf
	$(OBJCOPY) -O binary --only-section=.text $< tarea.text.bin
	$(OBJCOPY) -O binary --only-section=.map2 $< tarea.map1.bin
	$(OBJCOPY) -O binary --only-section=.map1 $< tarea.map2.bin
	cat tarea.text.bin tarea.map1.bin tarea.map2.bin >$@

%.bin: %.png png2mode13h.py
	./png2mode13h.py <$< >$@

%.o: %.bin
	$(OBJCOPY) -Ibinary -Oelf32-i386 -Bi8086 --rename-section .data=.sprites.$* $< $@
