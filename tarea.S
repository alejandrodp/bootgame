.intel_syntax noprefix
.code16

.text
.word 0xbaad

.global _start
_start:

init_graphics:
	mov ah, 0    # Set display mode
	mov al, 0x13 # 13h = 320x200, 256 colors
	int  0x10    # Video BIOS Services
	# initial draw settings
	mov ax, 0xA000
	mov es, ax

	call reset_screen

	mov ax, 0x17e0
	mov ds, ax
	lea si, _binary_map1_bin_start
	xor di, di
	lea cx, _binary_map1_bin_size
	cld
.load_loop:
	lodsw
	es stosw
	sub cx, 2
	jnz .load_loop

	xor ax, ax
	mov ds, ax

halt:
	cli
	hlt
	jmp halt

reset_screen:
	mov cx, 320*200
	mov di, 0
	mov al, 0
	rep stosb
	ret

draw_rect: # di = video index, bx = height, cx = width, al = color
	mov dx, cx
	mov si, di

rect_loop:
	rep stosb
	mov cx, dx
	add si, 320
	mov di, si
	dec bx
	jnz rect_loop
	ret


draw_map:

	mov di, 320*100
	mov bx, 50
	mov cx, 20
	mov al, map_color
	call draw_rect

	mov di, 320*2+70
	mov bx, 50
	mov cx, 20
	mov al, map_color
	call draw_rect
	jmp .
	


#TODO: Mover a .data
.section .rodata
map_color: .byte 4
