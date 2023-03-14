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

#define TEXT_TOP_X   1
#define TEXT_TOP_Y   1
#define TEXT_TOP     XY(TEXT_TOP_X, TEXT_TOP_Y)
#define TEXT_WIDTH   8
#define TEXT_HEIGHT  8
#define TEXT_SHIFT   6 // log2(8 * 8)
#define TEXT_KERNING 0

#define TEXT_AREA_WIDTH  (SCREEN_WIDTH - TEXT_TOP_X)
#define TEXT_AREA_HEIGHT (30 - TEXT_TOP_Y)

.global _start
_start:
	# Esto hace algo luego del primer nivel
	mov  word ptr [obstaculos], 0

init_graphics:
	mov  ah, 0    # Set display mode
	mov  al, 0x13 # 13h = 320x200, 256 colors
	int  0x10     # Video BIOS Services
	# initial draw settings
	mov  ax, SEG_VIDEO
	mov  es, ax

	call clear_screen
	call update_stats
	call set_timeout

	mov  ax, map_seg
	mov  ds, ax
	mov  si, map_start
	xor  di, di
	mov  bx, SCREEN_HEIGHT
	mov  cx, SCREEN_WIDTH
	call copy_rect

	mov  di, PLAYER_START
	call draw_player

main_loop:
	call .fix_ip
.fix_ip:
	pop  bx
	add  bx, .loop - .fix_ip
	push bx

.loop:
	mov  bp, sp
	mov  bx, [bp]
	push bx

.test_timer:
	test byte ptr timeout_ev, 0x80
	jz   .test_key
	call timed_out

.test_key:
	mov  ah, 0x11
	int  0x16
	jnz  .handle_key
	hlt
	jmp  .test_timer

.handle_key:
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
	jnz  stop_timer
	jmp  set_timeout

timed_out:
	mov  byte ptr [timeout_ev], 0
	cmp  byte ptr [pause], 0
	jne  .frozen
	dec  byte ptr [timer_decs]
	jnz  .not_decs
	mov  byte ptr [timer_decs], 10
	dec  byte ptr [timer]
	jz   triple_fault
	call update_stats
.not_decs:
	jmp  set_timeout
.frozen:
	ret

stop_timer:
	mov  ah, 0x83
	mov  al, 0x01
	int  0x15
	mov  byte ptr [timeout_ev], 0
	ret

set_timeout:
	mov  ah, 0x83
	xor  al, al
	mov  cx, (100000 >> 16)
	mov  dx, (100000 & 0xffff)
	push es
	mov  bx, ds
	mov  es, bx
	lea  bx, timeout_ev
	int  0x15
	pop  es
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
	lea  si, [_binary_nave_bin_start]
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
	lea  si, [_binary_nave_bin_start]
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
	jnz  .collision
.test_collisions.row.next:
	inc  bp
	loop .test_collisions.row
	add  dx, SCREEN_WIDTH
	mov  bp, dx
	dec  bx
	jnz  .test_collisions
	jmp  .draw_at_new_position

.collision:
	cmp  ah, 0x50
	jne  triple_fault
	xor  ax, ax
	mov  ds, ax
	lea  ax, [_binary_map2_bin_start]
	mov  word ptr map_seg, SEG_MAP2
	mov  map_start, ax
	lea  ax, txt_map2
	mov  map_name, ax

	# Cancelar timer
	call stop_timer
	mov  byte ptr timer, 60
	mov  byte ptr [timer_decs], 10
	mov  byte ptr [timeout_ev], 0

	jmp  _start

.draw_at_new_position:
	xor  ax, ax
	mov  ds, ax

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
	jz   draw_player

	test cx, cx
	js   .obstaculos_left
	add  word ptr [obstaculos], 1
	jmp  .obstaculos.update
.obstaculos_left:
	sub  word ptr [obstaculos], 1
.obstaculos.update:
	call draw_player
	jmp  update_stats

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
	xor  ax, ax
	mov  ds, ax
	mov  player_pos, di
	mov  ax, SEG_FLOAT
	mov  ds, ax
	lea  si, [_binary_nave_bin_start]
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
	xor  ax, ax
	mov  ds, ax
	ret

# Magia
triple_fault:
	push 0
	push 0
	push 0
	mov  bp, sp
	lidt [bp]
	xor  ax, ax
	div  ax

putstr:
	push si
.char_loop:
	mov  al, [si]
	test al, al
	jz   .char_loop.end
	call putchar
	mov  bp, sp
	inc  word ptr [bp]
	mov  si, [bp]
	jmp  .char_loop
.char_loop.end:
	add  sp, 2
	ret

putdecimal:
	cmp  ax, 100
	jae  .bad_digit
	cmp  ax, 10
	jb   .last_digit
	mov  cl, 10
	div  cl
	push ax
	add  al, '0'
	call putchar
	pop  ax
	mov  al, ah
.last_digit:
	add  al, '0'
	jmp  putchar
.bad_digit:
	mov  al, '?'

putchar:
	cmp  al, '\n'
	je   .newline
	mov  di, text_pos
	add  word ptr [text_pos], TEXT_WIDTH + TEXT_KERNING
	mov  bx, SEG_FLOAT
	mov  ds, bx
	lea  si, _binary_font_bin_start
	xor  ah, ah
	and  al, 0x7f # ASCII solo tiene 128 caracteres
	shl  ax, TEXT_SHIFT
	add  si, ax
	mov  bx, TEXT_HEIGHT
	mov  cx, TEXT_WIDTH
	jmp  copy_rect
.newline:
	mov  ax, word ptr [text_caret]
	add  ax, (TEXT_HEIGHT + TEXT_KERNING) * SCREEN_WIDTH
	mov  word ptr [text_pos], ax
	mov  word ptr [text_caret], ax
	ret

update_stats:
	call clear_text

	lea  si, txt_map
	call putstr
	mov  si, map_name
	call putstr

	lea  si, txt_timer
	call putstr
	mov  al, timer
	call putdecimal

	lea  si, txt_points
	call putstr
	mov  ax, obstaculos
	call putdecimal

	lea  si, txt_help
	jmp  putstr

clear_text:
	mov  di, TEXT_TOP
	mov  bx, TEXT_AREA_HEIGHT
	mov  cx, TEXT_AREA_WIDTH
	xor  al, al
	call clear_rect
	mov  word ptr [text_pos], TEXT_TOP
	mov  word ptr [text_caret], TEXT_TOP
	ret

#TODO: debería ser .data
.section .rodata
player_pos: .word PLAYER_START
obstaculos: .word 0
map_seg:    .word SEG_MAP1
map_start:  .word _binary_map1_bin_start
text_pos:   .word TEXT_TOP
text_caret: .word TEXT_TOP
map_name:   .word txt_map1
pause:      .byte 0
timeout_ev: .byte 0
timer:      .byte 32
timer_decs: .byte 10

txt_map:    .asciz "Nivel: "
txt_timer:  .asciz "        Tiempo: "
txt_points: .asciz "s\nObstaculos superados: "
txt_help:   .asciz "\nComandos: Flechas, L:pausa, R:reiniciar"
txt_map1:   .asciz "Principiante"
txt_map2:   .asciz "Avanzado"
