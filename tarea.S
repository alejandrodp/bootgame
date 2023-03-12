.intel_syntax noprefix
.code16

.text
.word 0xbaad

#define SCREEN_WIDTH  320
#define SCREEN_HEIGHT 200
#define XY(x, y)      (SCREEN_WIDTH * (y) + (x))

#define SEG_MAP1  0x17e0
#define SEG_MAP2  0x27e0
#define SEG_FLOAT 0x37e0
#define SEG_VIDEO 0xa000

.global _start
_start:

init_graphics:
	mov  ah, 0    # Set display mode
	mov  al, 0x13 # 13h = 320x200, 256 colors
	int  0x10     # Video BIOS Services
	# initial draw settings
	mov  ax, SEG_VIDEO
	mov  es, ax

	call clear_screen

	mov  ax, SEG_MAP1
	mov  ds, ax
	lea  si, _binary_map1_bin_start
	xor  di, di
	mov  bx, SCREEN_HEIGHT
	mov  cx, SCREEN_WIDTH
	call copy_rect

	mov  ax, SEG_FLOAT
	mov  ds, ax
	lea  si, _binary_nave_bin_start
	mov  di, XY(15, 50)
	mov  bx, 23
	mov  cx, 24
	call copy_rect

	lea  si, _binary_premio_bin_start
	mov  di, XY(270, 150)
	mov  bx, 23
	mov  cx, 24
	call copy_rect

halt:
	cli
	hlt
	jmp  halt

clear_screen:
	xor  di, di
	mov  bx, SCREEN_HEIGHT
	mov  cx, SCREEN_WIDTH
	xor  al, al

clear_rect:
	mov  dx, cx
	mov  bp, di
.clear_loop:
rep	stosb
	mov  cx, dx
	add  bp, SCREEN_WIDTH
	mov  di, bp
	dec  bx
	jnz  .clear_loop
	ret

copy_rect: # di = video index, ds:si = offset, bx = height, cx = width
	mov   dx, cx
	mov   bp, di
.copy_loop:
	lodsb
	test  al, al
	jz    .copy_loop.skip
es	stosb
	loop .copy_loop
	jmp  .copy_loop.next
.copy_loop.skip:
	inc  di
	loop .copy_loop
.copy_loop.next:
	mov  cx, dx
	add  bp, SCREEN_WIDTH
	mov  di, bp
	dec  bx
	jnz  .copy_loop
	ret
