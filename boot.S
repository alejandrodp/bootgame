.intel_syntax noprefix
.code16

.section .text.start
.global _start
_start:
	cli
	cld

	xor  ax, ax
	jmp  0x0000:on_known_cs

.text
on_known_cs:
	mov  ds, ax
	mov  es, ax

	# Stack inicia en 0x80000 (fin de RAM convencional)
	mov  ax, 0x7000
	mov  ss, ax
	xor  sp, sp
	# Se necesitará luego
	push dx

	xor  ah, ah
	mov  al, 0x03
	int  0x10

	mov  cx, bootmsg.end - bootmsg
	lea  bp, bootmsg
	call print

	mov  ah, 0x02
	mov  al, NUM_SECTORS
	xor  ch, ch
	mov  cl, 2 # Sector 1 en adelante
	mov  bx, 0x7e00
	pop  dx
	xor  dh, dh
	int  0x13
	jc   read_error
	cmp  word ptr [0x7e00], 0xbaad
	jnz  read_error

	lea  bp, readok
	mov  cx, readok.end - readok
	call print
	jmp  0x7e02

read_error:
	lea  bp, badread
	mov  cx, badread.end - badread
	push halt
	jmp  print

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

readok: .ascii "Jumping to game..."
readok.end:

badread: .ascii "Failed to read boot sectors, halting"
badread.end:

.section .mbr

.byte 0x80             # bootable
.byte 0x00, 0x01, 0x00 # start CHS address
.byte 0x17             # partition type
.byte 0x00, 0x02, 0x00 # end CHS address
.long 0                # LBA
.long 2                # number of sectors

.fill 3 * 16, 1, 0
.word 0xaa55
