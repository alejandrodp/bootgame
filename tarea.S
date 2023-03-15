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

#define PLAYER_WIDTH  26
#define PLAYER_HEIGHT 26
#define PLAYER_FRAMES 4

#define PLAYER_START_X 3
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

#define COLOR_BORDER_A  0x12
#define COLOR_BORDER_B  0x04
#define COLOR_OBSTACULO 0x28
#define COLOR_TARGET    0x50


# Macro para uso de interrupción de delay 15h
.macro delay, ms
	mov  ah, 0x86
	mov  cx, ((\ms * 1000) >> 16)
	mov  dx, ((\ms * 1000) & 0xffff)
	int  0x15
.endm

.global _start
_start:
	# Esto hace algo luego del primer nivel
	mov   word ptr [obstaculos], 0


# Sección inicial de configuración de gráficos y elementos básicos (timer, mapa, jugador)
init_graphics:
	mov   ah, 0    # Set display mode
	mov   al, 0x13 # 13h = 320x200, 256 colors
	int   0x10     # Video BIOS Services
	# initial draw settings
	mov   ax, SEG_VIDEO
	mov   es, ax

	call  clear_screen

	mov   di, PLAYER_START
	call  draw_player

	call  stop_timer
	delay 200
	call  set_timeout

.clear_keys:
	mov   ah, 0x11
	int   0x16
	jz    .clear_keys.end
	mov   ah, 0x10
	int   0x16
	jmp   .clear_keys
.clear_keys.end:

	lea   si, [txt_start]
	call  putstr
	mov   ah, 0x10
	int   0x16

	call  clear_text
	call  update_stats

# Bucle principal que procesa las interrupciones de las teclas y el timer
main_loop:
	call  .fix_ip
.fix_ip:
	pop   bx
	add   bx, .loop - .fix_ip
	push  bx

.loop:
	cmp   byte ptr [panic_after_stats], 0
	jne   update_stats

	mov   bp, sp
	mov   bx, [bp]
	push  bx

.test_timer:
	test  byte ptr [timeout_ev], 0x80
	jz   .test_key
	call  timed_out

.test_key:
	mov   ah, 0x11
	int   0x16
	jnz   .handle_key
	hlt
	jmp   .test_timer

.handle_key:
	mov   ah, 0x10
	int   0x16

	cmp   ah, 0x13
	je    triple_fault
	cmp   ah, 0x26
	je    toggle_pause

	test  byte ptr [pause], 1
	jnz   .ignore_keypress

	cmp   ah, 0x48
	je    key_up
	cmp   ah, 0x4b
	je    key_left
	cmp   ah, 0x4d
	je    key_right
	cmp   ah, COLOR_TARGET
	je    key_down

.ignore_keypress:
	# Bucle, no es un ret real
	ret

# Cambia el valor de la bandera de pausa
toggle_pause:
	not   byte ptr [pause]
	call  update_stats
	cmp   byte ptr [pause], 0
	jnz   stop_timer
	jmp   set_timeout

# Rutina para procesar un time-out
timed_out:
	mov   byte ptr [timeout_ev], 0
	cmp   byte ptr [pause], 0
	jne   .frozen
	dec   byte ptr [timer_decs]
	jnz   .not_decs
	mov   byte ptr [timer_decs], 10
	dec   byte ptr [timer]
	call  update_stats
	lea   si, [txt_timeout]
	cmp   byte ptr [timer], 0
	je    lose
.not_decs:
	jmp   set_timeout
.frozen:
	ret

# Rutina para procesar el congelamiento del timer
stop_timer:
	mov   ah, 0x83
	mov   al, 0x01
	int   0x15
	mov   byte ptr [timeout_ev], 0
	ret

Rutine de configuración de un time-out
set_timeout:
	mov   ah, 0x83
	xor   al, al
	mov   cx, (100000 >> 16)
	mov   dx, (100000 & 0xffff)
	push  es
	mov   bx, ds
	mov   es, bx
	lea   bx, [timeout_ev]
	int   0x15
	pop   es
	ret

# Estas rutinas procesan la interrución de teclas 
# y alteran al jugador acorde para desdibujarlo y redibujarlo
key_up:
	mov   ax, -SCREEN_WIDTH
	clc  
	jmp   move_player

key_left:
	mov   ax, -1
	mov   byte ptr [dir_offset], 0
	stc
	jmp   move_player

key_right:
	mov   ax, 1
	mov   byte ptr [dir_offset], 8
	stc
	jmp   move_player

key_down:
	mov   ax, SCREEN_WIDTH
	clc

# Rutinas para redibujar al jugador
move_player:
	push  ax
	pushf

	mov   di, [player_pos]
	add   ax, di
	push  ax

	mov   bx, PLAYER_HEIGHT
	mov   cx, PLAYER_WIDTH
	call  clear_rect

	pop   di
	xor   bh, bh
	mov   bl, [dir_offset]
	mov   si, bx
	add   si, [player_sprite_offset]
	lea   bx, [player_sprites]
	mov   si, [bx + si]
	mov   ax, SEG_FLOAT
	mov   ds, ax
	mov   bx, PLAYER_HEIGHT
	mov   bp, di
	mov   dx, di

# Estas rutinas verifican y procesan las colisiones
.test_collisions:
	mov   cx, PLAYER_WIDTH
.test_collisions.row:
	lodsb
	mov   ah, es:[bp]
	test  al, al
	jz    .test_collisions.row.next
	cmp   ah, COLOR_BORDER_A
	je    .collision
	cmp   ah, COLOR_BORDER_B
	je    .collision
	cmp   ah, COLOR_OBSTACULO
	je    .collision
	cmp   ah, COLOR_TARGET
	je    next_level
.test_collisions.row.next:
	inc   bp
	loop  .test_collisions.row
	add   dx, SCREEN_WIDTH
	mov   bp, dx
	dec   bx
	jnz   .test_collisions
	xor   ax, ax
	mov   ds, ax
	jmp   .draw_at_new_position

.collision:
	xor   ax, ax
	mov   ds, ax
	mov   byte ptr [panic_after_stats], 1

.draw_at_new_position:
	mov   [player_pos], di

	popf
	pop   ax
	jnc   .redraw_or_stats
	push  ax

	mov   ax, SCREEN_WIDTH
	call  test_obstaculos
	push  ax

	mov   di, [player_pos]
	mov   ax, -SCREEN_WIDTH
	call  test_obstaculos

	pop   bx
	pop   cx
	or    ax, bx
	jz    .redraw_or_stats

	test  cx, cx
	js    .obstaculos_left
	add   word ptr [obstaculos], 1
	jmp   .obstaculos.update
.obstaculos_left:
	sub   word ptr [obstaculos], 1
.obstaculos.update:
	jmp   update_stats
.redraw_or_stats:
	cmp   di, XY(0, TEXT_TOP_Y + TEXT_AREA_HEIGHT)
	jb    update_stats
	jmp   draw_player

# Rutina de salto al siguiente nivel del juego
next_level:
	xor   ax, ax
	mov   ds, ax
	xor   byte ptr [last_level], 1
	jz    win

	lea   ax, [_binary_map2_bin_start]
	mov   word ptr [map_seg], SEG_MAP2
	mov   [map_start], ax
	lea   ax, [txt_map2]
	mov   [map_name], ax

	call  stop_timer
	mov   byte ptr [timer], 74
	mov   byte ptr [timer_decs], 10
	mov   byte ptr [timeout_ev], 0
	mov   word ptr [player_pos], PLAYER_START

	jmp   _start

# Rutina para verificar una colisión con un color que identifica al obstáculo
test_obstaculos:
	add   di, ax
	mov   dl, es:[di]
	cmp   dl, COLOR_BORDER_A
	je    .not_found
	cmp   dl, COLOR_BORDER_B
	je    .not_found
	cmp   dl, COLOR_OBSTACULO
	je    .found
	jmp   test_obstaculos
.found:
	mov   ax, 1
	ret
.not_found:
	xor   ax, ax
	ret

clear_screen:
	xor   di, di
	mov   bx, SCREEN_HEIGHT
	mov   cx, SCREEN_WIDTH

clear_rect: # di = video index, bx = height, cx = width
	mov   dx, cx
	mov   ax, [map_seg]
	mov   si, [map_start]
	mov   ds, ax
	add   si, di
	sub   sp, 4
	mov   bp, sp

.copy_map_loop:
	mov   [bp + 2], si
	mov   [bp], di
.copy_map_row:
	lodsb
	stosb
	loop  .copy_map_row
	dec   bx
	jz    .copy_map_loop.end
	mov   cx, dx
	mov   si, [bp + 2]
	mov   di, [bp]
	add   si, SCREEN_WIDTH
	add   di, SCREEN_WIDTH
	jmp   .copy_map_loop
.copy_map_loop.end:
	xor   ax, ax
	mov   ds, ax
	add   sp, 4
	ret

# Rutnia de animación del jugador, 
# esta rutina procesa los frames del jugador y los dibuja en determinada cantidad para simular el movimiento
draw_player:
	xor   ax, ax
	mov   ds, ax
	mov   di, [player_pos]
	xor   bh, bh
	mov   bl, [dir_offset]
	mov   si, bx
	mov   ax, [player_sprite_offset]
	add   si, ax
	lea   bx, [player_sprites]
	mov   si, [bx + si]
	xor   byte ptr [skip_animation], 1
	jz    .skip_animation
	add   ax, 2
	cmp   ax, 2 * PLAYER_FRAMES
	jb    .dont_cycle
	xor   ax, ax
.dont_cycle:
	mov   [player_sprite_offset], ax
.skip_animation:
	mov   ax, SEG_FLOAT
	mov   ds, ax
	mov   bx, PLAYER_HEIGHT
	mov   cx, PLAYER_WIDTH

# Rutina para copiado de sprites a memoria de video
copy_rect: # di = video index, ds:si = offset, bx = height, cx = width
	mov   dx, cx
	mov   bp, di
.copy_loop:
	lodsb
	test  al, al
	jz    .copy_loop.skip
es	stosb
	loop  .copy_loop
	jmp   .copy_loop.next
.copy_loop.skip:
	inc   di
	loop  .copy_loop
.copy_loop.next:
	mov   cx, dx
	add   bp, SCREEN_WIDTH
	mov   di, bp
	dec   bx
	jnz   .copy_loop
	xor   ax, ax
	mov   ds, ax
	ret

# Rutina de reinicio del sistema
triple_fault:
	call  stop_timer
	delay 500

	# Hechizo para reiniciar el procesador
	push  0
	push  0
	push  0
	mov   bp, sp
	lidt  [bp]
	xor   ax, ax
	div   ax

# Rutina de escritura de strings
putstr:
	push  si
.char_loop:
	mov   al, [si]
	test  al, al
	jz    .char_loop.end
	call  putchar
	mov   bp, sp
	inc   word ptr [bp]
	mov   si, [bp]
	jmp   .char_loop
.char_loop.end:
	add   sp, 2
	ret

# Rutina de escritura de números decimales
putdecimal:
	cmp   ax, 100
	jae   .bad_digit
	cmp   ax, 10
	jb    .last_digit
	mov   cl, 10
	div   cl
	push  ax
	add   al, '0'
	call  putchar
	pop   ax
	mov   al, ah
.last_digit:
	add   al, '0'
	jmp   putchar
.bad_digit:
	mov   al, '?'

# Rutina de escritura de caracteres
putchar:
	cmp   al, '\n'
	je    .newline
	mov   di, [text_pos]
	add   word ptr [text_pos], TEXT_WIDTH + TEXT_KERNING
	mov   bx, SEG_FLOAT
	mov   ds, bx
	lea   si, [_binary_font_bin_start]
	xor   ah, ah
	shl   ax, TEXT_SHIFT
	add   si, ax
	mov   bx, TEXT_HEIGHT
	mov   cx, TEXT_WIDTH
	jmp   copy_rect
.newline:
	mov   ax, word ptr [text_caret]
	add   ax, (TEXT_HEIGHT + TEXT_KERNING) * SCREEN_WIDTH
	mov   word ptr [text_pos], ax
	mov   word ptr [text_caret], ax
	ret

# Rutina de actualización de estadísticas
update_stats:
	call  clear_text

	lea   si, [txt_map]
	call  putstr
	mov   si, [map_name]
	call  putstr

	lea   si, [txt_timer]
	call  putstr
	mov   al, [timer]
	call  putdecimal

	lea   si, [txt_points]
	call  putstr
	mov   ax, [obstaculos]
	call  putdecimal

	cmp   byte ptr [pause], 0
	je    .not_paused
	lea   si, [txt_paused]
	call  putstr

.not_paused:
	lea   si, [txt_help]
	call  putstr

	lea   si, [txt_lost]
	cmp   byte ptr [panic_after_stats], 0
	jne   lose
	jmp   draw_player

clear_text:
	mov   di, TEXT_TOP
	mov   bx, TEXT_AREA_HEIGHT
	mov   cx, TEXT_AREA_WIDTH
	call  clear_rect
	mov   word ptr [text_pos], TEXT_TOP
	mov   word ptr [text_caret], TEXT_TOP
	ret

# Rutina ejecutada al ganar el juego
win:
	call  clear_text

	lea   si, [txt_winner]
	call  putstr

	call  stop_timer
	delay 4500

	jmp   triple_fault 

# Rutina ejecutada al perder el juego
lose:
	push  si
	call  clear_text
	pop   si
	call  putstr

	call  stop_timer
	delay 2500
	jmp   triple_fault


#TODO: debería ser .data
.section .rodata
player_pos:           .word PLAYER_START
obstaculos:           .word 0
map_seg:              .word SEG_MAP1
map_start:            .word _binary_map1_bin_start
text_pos:             .word TEXT_TOP
text_caret:           .word TEXT_TOP
map_name:             .word txt_map1
player_sprite_offset: .word 0
pause:                .byte 0
timeout_ev:           .byte 0
timer:                .byte 32
timer_decs:           .byte 10
last_level:           .byte 0
panic_after_stats:    .byte 0
dir_offset:           .byte 8
skip_animation:       .byte 0

player_sprites:
	.word _binary_l1_bin_start
	.word _binary_l2_bin_start
	.word _binary_l3_bin_start
	.word _binary_l4_bin_start
	.word _binary_r1_bin_start
	.word _binary_r2_bin_start
	.word _binary_r3_bin_start
	.word _binary_r4_bin_start

txt_map:     .asciz "Nivel: "
txt_timer:   .asciz "         Tiempo: "
txt_points:  .asciz "s\nObst\240culos superados: "
txt_paused:  .asciz "     [PAUSA]"
txt_help:    .asciz "\nComandos: Flechas, L:pausa, R:reiniciar"
txt_map1:    .asciz "Principiante"
txt_map2:    .asciz "Avanzado"
txt_winner:  .asciz "\n        \255Felicidades, ha ganado!"
txt_lost:    .asciz "\n        \255Felicidades, ha perdido!"
txt_timeout: .asciz "\n  \255Felicidades, se le agot\242 el tiempo!"
txt_start:   .asciz "\1Presione cualquier tecla para iniciar\1"
