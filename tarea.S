.intel_syntax noprefix

.code16
.text

#define SCREEN_WIDTH  320
#define SCREEN_HEIGHT 200
#define XY(x, y)      (SCREEN_WIDTH * (y) + (x))

#define SEG_MAP1  0x17e0
#define SEG_MAP2  0x27e0
#define SEG_FLOAT 0x37e0
#define SEG_VIDEO 0xa000

#define PLAYER_WIDTH  24
#define PLAYER_HEIGHT 23

#define PLAYER_START_X 6
#define PLAYER_START_Y 50
#define PLAYER_START   XY(PLAYER_START_X, PLAYER_START_Y)

#define TARGET_WIDTH  24
#define TARGET_HEIGHT 23

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

	mov  di, PLAYER_START
	call draw_player

#	lea  si, _binary_premio_bin_start
#	mov  di, XY(270, 150)
#	mov  bx, TARGET_HEIGHT
#	mov  cx, TARGET_WIDTH
#	call copy_rect

read_keycodes:
	call .fix_ip
.fix_ip:
	pop  bx
	add  bx, .loop - .fix_ip
	push bx
.loop:
	mov  bp, sp
	mov  bx, [bp]
	push bx
	mov  ah, 0x10
	int  0x16
	cmp  ah, 0x13
	je   triple_fault
	cmp  ah, 0x26
	je   toggle_pause

	test byte ptr [pause], 1
	jnz  .ignore_keypress

	cmp  ah, 0x48
	je   key_up
	cmp  ah, 0x4b
	je   key_left
	cmp  ah, 0x4d
	je   key_right
	cmp  ah, 0x50
	je   key_down

.ignore_keypress:
	# Bucle, no es un ret real
	ret

toggle_pause:
	not  byte ptr pause
	ret

key_up:
	mov  ax, -SCREEN_WIDTH
	clc  
	jmp  move_player

key_left:
	mov  ax, -1
	stc
	jmp  move_player

key_right:
	mov  ax, 1
	stc
	jmp  move_player

key_down:
	mov  ax, SCREEN_WIDTH
	clc

move_player:
	push ax
	pushf

	mov  di, player_pos
	add  ax, di
	push ax

	mov  bx, PLAYER_HEIGHT
	mov  ax, SEG_FLOAT
	mov  ds, ax
	lea  si, _binary_nave_bin_start
	mov  bp, di
.clear_player:
	mov  cx, PLAYER_WIDTH
.clear_player.row:
	lodsb
	test al, al
	jz   .clear_player.dont_clear
	mov  byte ptr es:[di], 0
.clear_player.dont_clear:
	inc  di
	loop .clear_player.row
	add  bp, SCREEN_WIDTH
	mov  di, bp
	dec  bx
	jnz  .clear_player

	pop  di
	mov  ax, SEG_FLOAT
	mov  ds, ax
	lea  si, _binary_nave_bin_start
	mov  bx, PLAYER_HEIGHT
	mov  bp, di
	mov  dx, di
.test_collisions:
	mov  cx, PLAYER_WIDTH
.test_collisions.row:
	lodsb
	mov  ah, es:[bp]
	test al, al
	jz   .test_collisions.row.next
	test ah, ah
	jnz  triple_fault
.test_collisions.row.next:
	inc  bp
	loop .test_collisions.row
	add  dx, SCREEN_WIDTH
	mov  bp, dx
	dec  bx
	jnz  .test_collisions
	jmp  .draw_at_new_position

.collision:
	pop  ax
	pop  ax
	mov  di, player_pos
	jmp  draw_player

.draw_at_new_position:
	popf
	pop  ax
	jnc  draw_player
	push ax

	push di
	mov  ax, SCREEN_WIDTH
	call test_obstaculos

	pop  di
	push ax
	push di
	mov  ax, -SCREEN_WIDTH
	call test_obstaculos

	pop  di
	pop  bx
	pop  cx
	or   ax, bx
	jz   .obstaculos_none

	test cx, cx
	js   .obstaculos_left
	add  word ptr [obstaculos], 1
	jmp  draw_player
.obstaculos_left:
	sub  word ptr [obstaculos], 1
.obstaculos_none:
	jmp  draw_player

test_obstaculos:
	add  di, ax
	mov  dl, es:[di]
	cmp  dl, 0x12
	je   .not_found
	cmp  dl, 0x28
	je   .found
	jmp  test_obstaculos
.found:
	mov  ax, 1
	ret
.not_found:
	xor  ax, ax
	ret

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

draw_player:
	mov  ax, SEG_FLOAT
	mov  ds, ax
	lea  si, _binary_nave_bin_start
	mov  player_pos, di
	mov  bx, PLAYER_HEIGHT
	mov  cx, PLAYER_WIDTH

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

# Magia
triple_fault:
	push 0
	push 0
	push 0
	mov  bp, sp
	lidt [bp]
	int  0x69

#TODO: debería ser .data
.section .rodata
player_pos: .word PLAYER_START
obstaculos: .word 0
pause:      .byte 0
