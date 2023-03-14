LD      ?= ld
OBJCOPY ?= objcopy

FLAGS16 := -m16 -ffreestanding -nostartfiles -nodefaultlibs -nostartfiles -Wl,--no-check-sections

all: tarea.img

clean:
	find . -type f -a \( -name '*.bin' -o -name '*.elf' -o -name '*.o' \) -delete
	rm -vf tarea.img font_8x8

run: tarea.img
	qemu-system-i386 $(QEMUFLAGS) -hda $<

tarea.img: boot.bin tarea.bin
	cat $^ >$@

boot.elf: boot.ld boot.S tarea.bin
	$(CC) $(CFLAGS) $(FLAGS16) `./num_sectors.sh` -o $@ -T boot.ld boot.S

tarea.elf: tarea.ld tarea.S map1.o map2.o font.o nave.o
	$(CC) $(CFLAGS) $(FLAGS16) -o $@ -N -T $^

boot.bin: boot.elf
	$(OBJCOPY) -O binary --only-section=.mbr $< $@

tarea.bin: tarea.elf
	$(OBJCOPY) -O binary --only-section=.text $< tarea.text.bin
	$(OBJCOPY) -O binary --only-section=.sprites.map1 $< tarea.map1.bin
	$(OBJCOPY) -O binary --only-section=.sprites.map2 $< tarea.map2.bin
	$(OBJCOPY) -O binary --only-section=.sprites.float $< tarea.float.bin
	cat tarea.text.bin tarea.map1.bin tarea.map2.bin tarea.float.bin >$@

font.bin: font_8x8
	./$< >$@

%.bin: %.png png2mode13h.py
	./png2mode13h.py <$< >$@

%.o: %.bin
	$(OBJCOPY) -Ibinary -Oelf32-i386 -Bi8086 --rename-section .data=.sprites $< $@
