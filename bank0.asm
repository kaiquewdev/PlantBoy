;-------------
; PlantBoy - bank0.asm
;-------------
; Includes
;-------------
	
	INCLUDE "hardware.asm"
	INCLUDE "header.asm"
	INCLUDE "tiles.asm"
	INCLUDE "map.asm"

;-------------
; Start
;-------------

SECTION "Program Start",HOME[$150]
START:
	ei				 ;enable interrupts
	ld  sp,$FFFE
	ld  a,IEF_VBLANK ;enable vblank interrupt
	ld  [rIE],a

	ld  a,$0
	ldh [rLCDC],a 	 ;LCD off
	ldh [rSTAT],a

	ld  a,%11100100  ;shade palette (11 10 01 00)
	ldh [rBGP],a 	 ;setup palettes
	ldh [rOCPD],a
	ldh [rOBP0],a

	call CLEAR_MAP
	call LOAD_TILES
	call LOAD_MAP
	call INIT_PLAYER
	call INIT_RABBITS
	call INIT_TIMERS

	ld  a,%11010011  ;turn on LCD, BG0, OBJ0, etc
	ldh [rLCDC],a    ;load LCD flags

	call DMA_COPY    ;move DMA routine to HRAM
LOOP:
	call WAIT_VBLANK
	call READ_JOYPAD
	call MOVE_PLAYER
	call PLAYER_SHOOT
	call UPDATE_BULLET
	call SPAWN_RABBITS
	call ANIMATE_RABBITS
	call UPDATE_RABBITS
	call UPDATE_PLAYER
	call PLAYER_WATER
	call _HRAM		 ;call DMA routine from HRAM
	jp LOOP

;-------------
; Subroutines
;-------------

WAIT_VBLANK:
	ld  hl,vblank_flag
.wait_vblank_loop
	halt
	nop  			 ;Hardware bug
	ld  a,$0
	cp  [hl]
	jr  z,.wait_vblank_loop
	ld  [hl],a
	ld  a,[vblank_count]
	inc a
	ld  [vblank_count],a
	ld  a,[player_frame_time]
	inc a
	ld  [player_frame_time],a
	ld  a,[rabbit_spawn_time]
	inc a
	ld  [rabbit_spawn_time],a
	ld  a,[rabbit_y_spawn]
	inc a
	ld  [rabbit_y_spawn],a
	ld  a,[rabbit_move_time]
	inc a
	ld  [rabbit_move_time],a
	ld  a,[player_update_time]
	inc a
	ld  [player_update_time],a
	ld  a,[rabbit_frame_time]
	inc a
	ld  [rabbit_frame_time],a
	ret

DMA_COPY:
	ld  de,$FF80  	 ;DMA routine, gets placed in HRAM
	rst $28
	DB  $00,$0D
	DB  $F5, $3E, $C1, $EA, $46, $FF, $3E, $28, $3D, $20, $FD, $F1, $D9
	ret

CLEAR_MAP:
	ld  hl,_SCRN0    ;load map0 ram
	ld  bc,$400
.clear_map_loop
	ld  a,$0
	ld  [hli],a      ;clear tile, increment hl
	dec bc
	ld  a,b
	or  c
	jr  nz,.clear_map_loop
	ret

LOAD_TILES:
	ld  hl,TILE_DATA
	ld  de,_VRAM
	ld  bc,TILE_COUNT
.load_tiles_loop
	ld  a,[hli]      ;grab a byte
	ld  [de],a       ;store the byte in VRAM
	inc de
	dec bc
	ld  a,b
	or  c
	jr  nz,.load_tiles_loop
	ret

LOAD_MAP:
	ld  hl,MAP_DATA  ;same as LOAD_TILES
	ld  de,_SCRN0
	ld  bc,$400
.load_map_loop
	ld  a,[hli]
	ld  [de],a
	inc de
	dec bc
	ld  a,b
	or  c
	jr  nz,.load_map_loop
	ret

INIT_TIMERS:
	ld a,$0
	ld [rabbit_spawn_time],a
	ld [blood_count],a
	ld [rabbit_move_time],a
	ld [rabbit_spawn_side],a
	ld [player_frame_time],a
	ld [crop_count],a
	ld [rabbit_y_spawn],a
	ld [player_update_time],a
	ld [rabbit_frame_time],a
	ld a,$9
	ld [rabbit_frame],a
	ret

READ_JOYPAD:
	ld  a,%00100000  ;select dpad
	ld  [rP1],a
	ld  a,[rP1]		 ;takes a few cycles to get accurate reading
	ld  a,[rP1]
	ld  a,[rP1]
	ld  a,[rP1]
	cpl 			 ;complement a
	and %00001111    ;select dpad buttons
	swap a
	ld  b,a

	ld  a,%00010000  ;select other buttons
	ld  [rP1],a  
	ld  a,[rP1]
	ld  a,[rP1]
	ld  a,[rP1]
	ld  a,[rP1]
	cpl
	and %00001111
	or  b
					 ;lower nybble is other
	ld  b,a
	ld  a,[joypad_down]
	cpl
	and b
	ld  [joypad_pressed],a
					 ;upper nybble is dpad
	ld  a,b
	ld  [joypad_down],a
	ret

JOY_RIGHT:
	and %00010000
	cp  %00010000
	jp  nz,JOY_FALSE
	ld  a,$1
	ret
JOY_LEFT:
	and %00100000
	cp  %00100000
	jp  nz,JOY_FALSE
	ld  a,$1
	ret
JOY_UP:
	and %01000000
	cp  %01000000
	jp  nz,JOY_FALSE
	ld  a,$1
	ret
JOY_DOWN:
	and %10000000
	cp  %10000000
	jp  nz,JOY_FALSE
	ld  a,$1
	ret
JOY_A:
	and %00000001
	cp  %00000001
	jp  nz,JOY_FALSE
	ld  a,$1
	ret
JOY_B:
	and %00000010
	cp  %00000010
	jp  nz,JOY_FALSE
	ld  a,$1
	ret
JOY_SELECT:
	and %00000100
	cp  %00000100
	jp  nz,JOY_FALSE
	ld  a,$1
	ret
JOY_START:
	and %00001000
	cp  %00001000
	jp  nz,JOY_FALSE
	ld  a,$1
	ret
JOY_FALSE:
	ld  a,$0
	ret
	
INIT_RABBITS:
	ld  hl,rabbit_sprites
	ld  b,8                  ;8 sprites, 4 bytes each
.init_rabbit_loop
	ld  a,$0 				 ;off position
	ld  [hli],a 			 ;y
	ld  [hli],a 			 ;x
	ld  a,$9 			     ;default tile
	ld  [hli],a 			 ;tile
	ld  a,$0 			     ;default flags
	ld  [hli],a 			 ;flags
	dec b
	jr  nz,.init_rabbit_loop
	ret

SPAWN_RABBITS:
	ld  a,[rabbit_spawn_time]
	cp  $10
	jr  nz,.end              ;spawn every x vblanks

	ld  a,[rabbit_spawn_side]
	inc a
	ld  [rabbit_spawn_side],a

	ld  a,$0
	ld  [rabbit_spawn_time],a
	ld  b,$8 			     ;8 rabbits, 4 byte each
	ld  hl,rabbit_sprites
.find_idle_rabbit 			 ;find a rabbit not currently used
	ld  a,[hl]
	cp  $0
	jr  nz,.next
	jp  .spawn
.next
	inc hl                   ;y->x
	inc hl                   ;x->tile
	inc hl                   ;tile->flags
	inc hl                   ;flags->next y
	dec b
	jr  nz,.find_idle_rabbit
	jp  .end
.spawn
	ld  a,[rabbit_spawn_side]
	cp  $1
	jr  nz,.right
	ld  c,$0
	ld  e,%00000000
	jp  .spawn_now
.right
	ld  a,$0
	ld  [rabbit_spawn_side],a
	ld  c,$A4
	ld  e,%00100000
.spawn_now
	ld  a,[rabbit_y_spawn]   ;y spawn
	ld  [hli],a              ;y->x
	ld  a,c                  ;x spawn
	ld  [hli],a              ;x->tile
	inc hl                   ;tile->flags
	ld  [hl],e  
.end
	ret

ANIMATE_RABBITS:
	ld  a,[rabbit_frame_time]
	cp  $10
	jr  z,.animate
	ret
.animate
	ld  a,$0
	ld  [rabbit_frame_time],a
	ld  a,[rabbit_frame]
	inc a
	cp  $B
	jr  z,.reset
	ld  [rabbit_frame],a
	ret
.reset
	ld  a,$9
	ld  [rabbit_frame],a
	ld  a,$0
	ld  [rabbit_frame_time],a
	ret

UPDATE_RABBITS:
	ld  a,[rabbit_move_time] ;update  every 4 vblanks
	cp  $4
	jr  nz,.end
	ld  a,$0
	ld  [rabbit_move_time],a

	ld  a,[rabbit_y_spawn]
	cp  $90
	jr  nz,.loop_start
	ld  a,$0
	ld  [rabbit_y_spawn],a
.loop_start
	ld  hl,rabbit_sprites
	ld  b,$8
.loop
	ld  a,[hli]              ;y->x
	cp  $0
	jr  z,.next
.check
	ld  a,[hli]              ;x->tile
	cp  $AF
	jr  nz,.move
	dec hl                   ;x<-tile
	dec hl                   ;y<-x
	ld  a,$0                 ;despawn when off screen
	ld  [hl],a
	inc hl                   ;y->x
	jp  .next
.move
	inc hl                   ;tile->flags
	ld  a,[hl]
	dec hl                   ;tile<-flags
	dec hl                   ;x<-tile
	and %00100000
	jr  z,.right
.left
	ld  a,[hl]
	dec a
	dec a
	ld  [hl],a
	jp  .coll_up
.right
	ld  a,[hl]
	inc a
	inc a
	ld  [hl],a               ;below is basic AABB collision
.coll_up
	dec hl                   ;y
	ld  a,[bullet_y]
	add $4
	sub [hl]
	jr  nc,.coll_down
	jp  .con_next
.coll_down
	ld  a,[bullet_y]
	sub $4
	sub [hl]
	jr  nc,.con_next
	jp  .coll_left
.coll_left
	inc hl                   ;x
	ld  a,[bullet_x]
	add $6
	sub [hl]
	jr  nc,.coll_right
	dec hl 				     ;y
	jp  .con_next
.coll_right
	ld  a,[bullet_x]
	sub $4
	sub [hl]
	dec hl                   ;y
	jr  nc,.con_next
	jp  .die
.con_next
	inc hl                   ;x
	jp  .next
.next
	inc hl                   ;x->tile
	ld  a,[rabbit_frame]
	ld  [hl],a
	inc hl                   ;tile->flags
	inc hl                   ;flags->next y
	dec b
	jr  nz,.loop
.end
	ret
.die
	ld  a,$0
	ld  [hl],a
	ld  [bullet_x],a
	ld  [bullet_y],a
	ld  [bullet_reset],a
	call PLAY_SWEEP
	ld  a,$1
	ld  [blood_count],a
	ret


INIT_PLAYER:
	ld  a,$50
	ld  [player_x],a
	ld  [player_y],a
	ld  [crop_x],a
	ld  [crop_y],a
	ld  a,$4
	ld  [player_tile],a
	ld  a,$6
	ld  [bullet_tile],a
	ld  a,$0
	ld  [player_flags],a
	ld  [bullet_flags],a
	ld  [bullet_x],a
	ld  [bullet_y],a
	ld  [bullet_reset],a
	ld  [blood_count_flags],a
	ld  [crop_flags],a
	ld  [crop_count_flags],a

	ld  a,$B
	ld  [crop_tile],a

	ld  a,$98
	ld  [crop_count_y],a
	ld  a,$69 
	ld  [crop_count_x],a

	ld  a,$98
	ld  [blood_count_y],a
	ld  a,$31
	ld  [blood_count_x],a
	ld  a,$15
	ld  [blood_count_tile],a
	ld  [crop_count_tile],a
	ret

MOVE_PLAYER:
	ld  a,[player_frame_time] ;animate player tile
	cp  $8
	jr  nz,.move_speed
	ld  a,$0
	ld  [player_frame_time],a
	ld  a,[player_tile]
	inc a
	cp  $6
	jr  z,.tile_reset

	ld  b,a
	ld  a,[joypad_down]       ;dpad pressed? 
	and %11110000
	jr  z,.tile_reset

	ld  a,b
	ld  [player_tile],a
.move_speed
	ld  a,[vblank_count]
	cp  $2
	jp  nz,.move_done
	ld  a,$0
	ld  [vblank_count],a
	jp  .move_right
.tile_reset
	ld  a,$4
	ld  [player_tile],a
	jp .move_speed
.move_right
	ld  a,[player_x] 		   ;right bound
	cp  $A0
	jr  z,.move_left

	ld  a,[joypad_down]
	call JOY_RIGHT
	jr  nz,.move_left
	ld  a,[player_x]
	inc a
	ld  [player_x],a

	ld  a,[player_flags]        ;flip tile
	res 5,a
	ld  [player_flags],a
.move_left
	ld  a,[player_x]			;left bound
	cp  $8
	jr  z,.move_up

	ld  a,[joypad_down]
	call JOY_LEFT
	jr  nz,.move_up
	ld  a,[player_x]
	dec a
	ld  [player_x],a

	ld  a,[player_flags]        ;flip tile
	set 5,a
	ld  [player_flags],a
.move_up
	ld  a,[player_y] 			;up bound
	cp  $10
	jr  z,.move_down

	ld  a,[joypad_down]
	call JOY_UP
	jr  nz,.move_down
	ld  a,[player_y]
	dec a
	ld  [player_y],a
.move_down
	ld  a,[player_y] 			;left bound
	cp  $90
	jr  z,.move_done

	ld  a,[joypad_down]
	call JOY_DOWN
	jr  nz,.move_done
	ld  a,[player_y]
	inc a
	ld  [player_y],a
.move_done
	ret

PLAYER_SHOOT:
	ld  a,[joypad_pressed]
	call JOY_A
	cp  $1
	jr  z,.shoot		 		    ;a pressed?
.end
	ret
.shoot
	ld  a,[bullet_reset]
	cp  $0
	jr  nz,.end                 ;bullet at 0x0?

	ld  a,[player_x]            ;set bullet to player pos
	ld  [bullet_x],a
	ld  a,[player_y]
	ld  [bullet_y],a
	ld  a,[player_flags]
	ld  [bullet_flags],a
	ld  a,$1
	ld  [bullet_reset],a
	call PLAY_NOISE
	ret

UPDATE_PLAYER:
	ld  a,[blood_count]
	cp  $1
	jr  z,.blood_1
	ld  a,$15
	ld  [blood_count_tile],a
	jp  .loop_start
.blood_1
	ld  a,$16
	ld  [blood_count_tile],a
.loop_start
	ld  hl,rabbit_sprites
	ld  b,$8
.loop
	ld  a,[hli]              ;y->x
	cp  $0
	jr  z,.next
.coll_up
	dec hl                   ;y
	ld  a,[player_y]
	add $4
	sub [hl]
	jr  nc,.coll_down
	jp  .con_next
.coll_down
	ld  a,[player_y]
	sub $4
	sub [hl]
	jr  nc,.con_next
	jp  .coll_left
.coll_left
	inc hl                   ;x
	ld  a,[player_x]
	add $6
	sub [hl]
	jr  nc,.coll_right
	dec hl 				     ;y
	jp  .con_next
.coll_right
	ld  a,[player_x]
	sub $4
	sub [hl]
	dec hl                   ;y
	jr  nc,.con_next
	jp  .die
.con_next
	inc hl                   ;x
	jp  .next
.next
	inc hl                   ;tile
	inc hl                   ;flags
	inc hl                   ;next y
	dec b
	jr  nz,.loop
.end
	ret
.die
	call START
	ret

PLAYER_WATER:
	ld  a,[joypad_pressed]
	call JOY_B
	jr  nz,.done
	ld  a,[blood_count]
	cp  $1
	jr  z,.has_blood
	jp  .done
.has_blood
	call PLAY_WATER
	ld  a,$0
	ld  [blood_count],a
.coll_up
	ld  hl,crop_y
	ld  a,[player_y]
	add $4
	sub [hl]
	jr  nc,.coll_down
	jp  .done
.coll_down
	ld  a,[player_y]
	sub $4
	sub [hl]
	jr  nc,.done
	jp  .coll_left
.coll_left
	ld  hl,crop_x
	ld  a,[player_x]
	add $6
	sub [hl]
	jr  nc,.coll_right
	jp  .done
.coll_right
	ld  a,[player_x]
	sub $4
	sub [hl]
	jr  nc,.done
.con
	ld  a,[crop_tile]
	inc a
	cp  $E
	jr  z,.reset
	ld  [crop_tile],a
	jp  .done
.reset
	ld  a,[crop_count]
	inc a
	ld  [crop_count],a
	add $15
	ld  [crop_count_tile],a
	ld  a,$B
	ld  [crop_tile],a
.done
	ret

UPDATE_BULLET:
	ld  a,[bullet_flags]
	and %00100000
	ld  a,[bullet_x]
	jr  z,.right
.left
	dec a
	jp  .check_collision
.right
	inc a
.check_collision
	ld  [bullet_x],a
	cp  $0
	jr  z,.reset
	cp  $A4
	jr  z,.reset
.end
	ret
.reset
	ld  a,$0
	ld  [bullet_x],a
	ld  [bullet_y],a
	ld  [bullet_reset],a
	ret

PLAY_NOISE:
	ld  a,%01000101
	ld  [rNR42],a
	ld  a,%01111001
	ld  [rNR43],a
	ld  a,%11111111
	ld  [rNR50],a
	ld  [rNR51],a
	ld  a,%10000000
	ld  [rNR44],a
	ret
PLAY_SWEEP:
	ld  a,%10000001
	ld  [rNR42],a
	ld  a,%01111001
	ld  [rNR43],a
	ld  a,%11111111
	ld  [rNR50],a
	ld  [rNR51],a
	ld  a,%10000000
	ld  [rNR44],a
	ret
PLAY_WATER:
	ld  a,%10000001
	ld  [rNR42],a
	ld  a,%01111011
	ld  [rNR43],a
	ld  a,%11111111
	ld  [rNR50],a
	ld  [rNR51],a
	ld  a,%10000000
	ld  [rNR44],a
	ret
;-------------
; RAM Vars
;-------------

SECTION "RAM Vars",BSS[$C000]
vblank_flag:
db
rabbit_spawn_time:
db
vblank_count:
db
joypad_down:
db 				     			 ;dow/up/lef/rig/sta/sel/a/b
joypad_pressed:
db
player_frame_time:
db
player_update_time:
db
bullet_reset:
db
rabbit_y_spawn:
db
rabbit_move_time:
db
rabbit_spawn_side:
db
rabbit_frame_time:
db
rabbit_frame:
db
blood_count:
db
crop_count:
db

SECTION "RAM OAM Vars",BSS[$C100]
player_y:
db
player_x:
db
player_tile:
db
player_flags:
db
bullet_y:
db
bullet_x:
db
bullet_tile:
db
bullet_flags:
db
crop_y:
db
crop_x:
db
crop_tile:
db
crop_flags:
db
blood_count_y:
db
blood_count_x:
db
blood_count_tile:
db
blood_count_flags:
db
crop_count_y:
db
crop_count_x:
db
crop_count_tile:
db
crop_count_flags:
db
rabbit_sprites:
db 								 ;8 wabbits


;-------------
; End of file
;-------------