# Para usar notación Intel, no AT&T
.intel_syntax noprefix

.code16
.section .text.start

#define TIMEOUT 3

.global _start
_start:
	jmp  0x0000:on_known_cs

.text
on_known_cs:
	cld # CLear Direction flag
	xor  ax, ax
	mov  ds, ax
	mov  es, ax

	# Stack inicia en 0x80000 (fin de RAM convencional)
	mov  ax, 0x7000
	mov  ss, ax
	mov  sp, 0xfffe
	# Se necesitará luego
	push dx

	# Modo texto
	xor  ah, ah
	mov  al, 0x03
	int  0x10

	mov  cx, bootmsg.end - bootmsg
	lea  bp, bootmsg
	call print

	pop  dx
	test dl, 0x80
	jnz  .dl_is_harddrive
	mov  cx, baddl.end - baddl
	lea  bp, baddl
	call print
	jmp  halt

.dl_is_harddrive:
	push dx

	mov  cx, loading.end - loading
	lea  bp, loading
	call print

	mov  ax, NUM_SECTORS
	mov  bx, 0x7e00
	push 0
	push 0
	push 0
	push 1
	push 0x07e0
	push 0
	push FIRST_READ_SECTORS
	push 16
	push NUM_SECTORS
.read_loop:
	mov  ax, ss
	mov  ds, ax
	mov  ah, 0x42
	mov  bp, sp
	mov  dx, [bp + 2 + 16]
	lea  si, [bp + 2]
	int  0x13
	mov  ax, 0
	mov  ds, ax # Importante que no sea xor, ya que no debe tocar flags
	jc   read_error
	mov  bp, sp
	mov  ax, [bp + 2 + 2]
	mov  bx, [bp]
	sub  bx, ax
	jz   .read_loop.end
	mov  [bp], bx
	mov  cx, bx
	and  cx, 0x7f
	jz   .read_loop.full_segment
	test bx, ~0x7f
	jnz  .read_loop.full_segment
	mov  bx, cx
	jmp  .read_loop.do_read
.read_loop.full_segment:
	mov  bx, 0x80
.read_loop.do_read:
	mov  [bp + 2 + 2], bx
	add  word ptr [bp + 2 + 6], 0x1000
	add  [bp + 2 + 8], ax
	jmp  .read_loop
.read_loop.end:

	cmp  word ptr [0x7e00], 0xbaad
	jnz  magic_error
	lea  bp, readok
	mov  cx, readok.end - readok
	call print

	mov  ah, 0x86
	mov  cx, (TIMEOUT * 1000000) >> 16
	mov  dx, (TIMEOUT * 1000000) & 0xffff
	int  0x15
	jmp  0x7e02

read_error:
	lea  bp, badread
	mov  cx, badread.end - badread
	call print
	jmp  halt

magic_error:
	lea  bp, badmagic
	mov  cx, badmagic.end - badmagic
	call print

halt:
	cli
	hlt
	jmp  halt

print:
	mov  ah, 0x13
	mov  al, 0x01
	xor  bh, bh
	mov  bl, 0xf0 # Negro sobre blanco
	mov  dh, line
	xor  dl, dl
	int  0x10
	inc  byte ptr line
	ret

.section .rodata
#TODO: va en .data
line: .byte 0

bootmsg: .ascii "Bootloader!"
bootmsg.end:

loading: .ascii "Loading game..."
loading.end:

readok: .ascii "Booting game..."
readok.end:

badread: .ascii "Error: failed to read boot sectors, halting"
badread.end:

baddl: .ascii "Error: BIOS emulates boot drive as floppy"
baddl.end:

badmagic: .ascii "Error: bad payload magic"
badmagic.end:

.section .mbr

.byte 0x80             # bootable
.byte 0x00, 0x01, 0x00 # start CHS address
.byte 0x17             # partition type
.byte 0x00, 0x02, 0x00 # end CHS address
.long 0                # LBA
.long 2                # number of sectors

.fill 3 * 16, 1, 0
.word 0xaa55
