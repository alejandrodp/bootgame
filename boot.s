.intel_syntax noprefix
.code16

.section .text.start
.global _start
_start:
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

	xor  ah, ah
	mov  al, 0x03
	int  0x10

	mov  ah, 0x13
	mov  al, 0x01
	xor  bh, bh
	mov  bl, 0xf0 # Negro sobre blanco
	mov  cx, bootmsg.end - bootmsg
	xor  dl, dl
	xor  dh, dh
	lea  bp, bootmsg
	int  0x10
	jmp  .

.section .rodata
bootmsg: .ascii "Bootloader!"
bootmsg.end:

.section .magic
.word 0xaa55
