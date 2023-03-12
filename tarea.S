.intel_syntax noprefix
.code16

.text
.word 0xbaad

.global _start
_start:
	push '+'
	push ('+' << 8) | 0xf0

print:
	mov  si, sp
	mov  bl, [si]
	not  byte ptr [si]
	mov  ah, 0x13
	mov  al, 0x01
	xor  bh, bh
	mov  cx, 1
	mov  dh, 10
	mov  dl, 10
	mov  bp, si
	add  bp, 2
	int  0x10
	jmp  print
