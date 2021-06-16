.p816
.smart

.segment "ZEROPAGE"
temp1: .res 2
temp2: .res 2
temp3: .res 2
temp4: .res 2
temp5: .res 2
temp6: .res 2

; for sprite code
sprid: .res 1
spr_x: .res 2       ; 9 bit
spr_y: .res 1
spr_c: .res 1       ; tile #
spr_a: .res 1       ; attributes
spr_sz: .res 1      ; sprite size, 0 or 2
spr_h: .res 1       ; high 2 bits
spr_x2: .res 2      ; for meta sprite code

pad1: .res 2
pad1_new: .res 2
pad2: .res 2
pad2_new: .res 2
in_nmi: .res 2

bg1_x: .res 1
bg1_y: .res 1
bg2_x: .res 1
bg2_y: .res 1
bg3_x: .res 1
bg3_y: .res 1
map_selected: .res 1

collision: .res 1
obj2h: .res 1
obj2y: .res 1
obj1h: .res 1
obj1y: .res 1
obj2w: .res 1
obj2x: .res 1
obj1w: .res 1
obj1x: .res 1

.segment "BSS"

PAL_BUFFER: .res 512

OAM_BUFFER: .res 512 ; low table
OAM_BUFFER2: .res 32 ; high table


.include "define.asm"
.include "macros.asm"
.include "init.asm"
.include "library.asm"
.include "unrle.asm"



.segment "CODE"

; enters here // in foced blank
main:
.a16    ; reminder of the setting from the init code
.i16
  phk   ; setst he data bank register to the same as the Program Bank
  plb


; DMA from BG_Palette to CGRAM
  A8              ; macro to put registers in 8 bit mode
  stz pal_addr    ; $2121 cg address = zero

  stz $4300 ; transfer mode 0 = 1 register write once
  lda #$22  ; $2122
  sta $4301 ; destination palette data
  
  ldx #.loword(BG_Palette)
  stx $4302 ; source
  lda #^BG_Palette
  sta $4304 ; bank
  ldx #512
  stx $4305 ; length
  lda #1
  sta $420b ; start dma, channel 0


; DMA from Tiles to VRAM
  lda #V_INC_1      ; the value $80
  sta vram_inc      ; $2115 = set the increment mode +1

; COPY sprites to SPRITE BUFFER
  BLOCK_MOVE 422, Sprites, OAM_BUFFER

; DMA from OAM_BUFFER to the OAM RAM
  ldx #$0000
  stx oam_addr_L    ; $2102 & 2103
  
  stz $4300         ; transfer mode 0 = 1 register write once
  lda #4            ; $2104 oam data
  sta $4301         ; destination, oam data
  ldx#.loword(OAM_BUFFER)
  stx $4302         ; source
  lda #^OAM_BUFFER
  sta $4304         ; bank
  ldx #544
  stx $4305         ; length
  lda #1
  sta $420b         ; start dma, channel 0


; DMA from Spr_Tiles to VRAM 
; Set up for increment value for VRAM DMA
  lda #V_INC_1  ; the value $80
  sta vram_inc  ; $2115 = set the increment mode +1

  ldx #$4000
  stx vram_addr ; set an address in the vram of $4000

  lda #1
  sta $4300     ; transfer mode, 2 registers 1 write
                ; $2118 and $2119 are a pair Low/High
  lda #$18      ; $2118
  sta $4301     ; destination, vram data
  ldx #.loword(Spr_Tiles)
  stx $4302     ; source
  lda #^Spr_Tiles
  sta $4304     ; bank
  ldx #(End_Spr_Tiles-Spr_Tiles)    ; let the assembler figure out size of tiles for us
  stx $4305     ; length
  lda #1
  sta $420b     ; start DMA, channel 0

; $2101 sssnn-bb
; sss = sprite sizes (000 = 8x8 and 16x16 sprites)
; nn  = displacement for the 2nd set of sprite tiles (00 = normal)
; -bb = where are the sprite tiles (in steps of $2000)
; (that upper bit is useless so marked with a dash)

  lda #2              ; sprite tiles at $4000
  sta spr_addr_size   ; $2101

  lda #1              ; mode 1, tilesize 8x8 all
  sta bg_size_mode    ; $2105


  
; DMA from BG12Tiles to VRAM
; - set target address for transfer
  ldx #$0000
  stx vram_addr ; set an address in the vram of $0000
; - set transfer mode settings
  lda #1
  sta $4300   ; transfer mode, 2 registers 1 write
              ; $2118 and $2119 are a pair Low/High
  lda #$18    ; $2118
  sta $4301   ; destination, vram data

; - decompress first
  AXY16
  lda #.loword(BG12Tiles)
  ldx #^BG12Tiles
  jsl unrle   ; unpacks to 7f0000 UNPACK_ADR
  ; returns y = length
  ; ax = unpack address (x is bank)
; - transfer decompressed data
  sta $4302   ; source
  txa
  A8
  sta $4304   ; bank
  sty $4305   ; length
  lda #1
  sta $420b   ; start dma, channel 0

; DMA from BG3Tiles to VRAM
; - set target address for transfer
  ldx #$3000
  stx vram_addr ; set an address in the vram of $6000
; - transfer mode settings arleady set from previous transfer

; - decompress first
  AXY16
  lda#.loword(BG34Tiles)
  ldx #^BG34Tiles
  jsl unrle   ; unpacks to 7f0000 UNPACK_ADR
; - transfer uncompressed data
  sta $4302   ; source
  txa
  A8
  sta $4304   ; bank
  sty $4305   ; length
  lda #1
  sta $420b   ; start dma, channel 0

; DMA from BG1Tilemap to VRAM
; - set target address for transfer
  ldx #$6000
  stx vram_addr ; set an address in the vram of $9000
; - transfer mode settings already set from previous transfer

; - decompress first
  AXY16
  lda#.loword(BG1Tilemap)
  ldx#^BG1Tilemap
  jsl unrle   ; unpacks to 7f0000 UNPACK_ADR
; - transfer uncompressed data
  sta $4302   ; source
  txa
  A8
  sta $4304   ; bank
  sty $4305   ; length
  lda #1
  sta $420b   ; start dma, channel 0

; DMA from BG2Tilemap to VRAM
; - set target address for transfer
  ldx #$6800
  stx vram_addr ; set an address in the vram of $9800
; - transfer mode settings already set from previous transfer

; - decompress first
  AXY16
  lda#.loword(BG2Tilemap)
  ldx#^BG2Tilemap
  jsl unrle    ; unpacks to 7f0000 UNPACK_ADR
; - transfer uncompressed data
  sta $4302   ; source
  txa
  A8
  sta $4304   ; bank
  sty $4305   ; length
  lda #1
  sta $420b   ; start dma, channel 0

; DMA from BG3Tilemap to VRAM
; - set target address for transfer
  ldx #$7000
  stx vram_addr ; set an address int he vram of $a000
; - transfer mode settings already set form previous transfer

; - decompress first
  AXY16
  lda#.loword(BG3Tilemap)
  ldx#^BG3Tilemap
  jsl unrle   ; unpacks to 7f0000 UNPACK_ADR
; - transfer uncompressed data
  sta $4302   ; source
  txa
  A8
  sta $4304   ; bank
  sty $4305   ; length
  lda #1
  sta $420b   ; start dma, channel 0


; a is still 8 bit
  lda #1|BG3_TOP    ; mode 1, tilesize 8x8 all, layer 3 on top
  sta bg_size_mode  ; $2105

; 210b = tilesets for bg 1 and bg 2
; (210c for bg 3 and bg 4)
; setps of $1000 -321-321... bg2 bg1
  stz bg12_tiles    ; #210b BG 1 and 2 TILES at address $0000
  lda #$03
  sta bg34_tiles    ; $210c BG 3 TILES at address $3000

  ; 2107 map address bg1, steps of $400, but -54321yx
  ; y/x = map size... 0,0 = 32x32 tiles
  ; $6000 / $100 = $60
  lda #$60        ; VRAM address of $6000
  sta tilemap1    ; $2107

  lda #$68        ; VRAM address of $6800
  sta tilemap2

  lda #$70        ; VRAM address of $7000
  sta tilemap3

  lda #ALL_ON_SCREEN    ; show only sprites
  sta main_screen ; #212c

  ; turn on NMI interrupts and auto-controller reads
  lda #NMI_ON|AUTO_JOY_ON
  sta $4200

  jsr oam_clear

; turn screen on // end of forced blank
  lda #FULL_BRIGHT ; $0f = turn the screen on, full brightness
  sta fb_bright ; $2100

InfiniteLoop:
  A8
  jsr wait_nmi      ; wait for beginning of v-blank
  jsr dma_oam       ; copy the OAM_BUFFER to the OAM
  jsr set_scroll
  jsr pad_poll
  jsr oam_clear

  AXY16

  lda pad1
  and #KEY_UP
  beq @not_up

  jsr Up_Handler

@not_up:
  lda pad1
  and #KEY_DOWN
  beq @not_down

  jsr Down_Handler

@not_down:
  lda pad1
  and #KEY_RIGHT
  beq @not_right

  jsr Right_Handler

@not_right:
  lda pad1
  and #KEY_LEFT
  beq @not_left

  jsr Left_Handler

@not_left:
  lda pad1_new
  and #(KEY_A|KEY_B|KEY_X|KEY_Y)
  beq @not_button

  jsr Button_Handler

@not_button:

  jsr Draw_sprites
  jmp InfiniteLoop



  jmp InfiniteLoop


Draw_sprites:
  php
  A8

; spr_x - x (9 bit)
; spr_y - y
; spr_c - tile #
; spr_a - attributes, flip, palette, priority
; spr_sz - sprite size, 0 or 2
  lda #10
  sta spr_x
  sta spr_y
  lda map_selected
  asl a
  sta spr_c
  lda #SPR_PAL_0|SPR_PRIOR_2
  sta spr_a
  lda #SPR_SIZE_LG
  sta spr_sz
  jsr oam_spr
  plp
  rts

Button_Handler:
.a16
.i16
; A, B, X, or Y button pressed
; change the selected BG map
  php
  A8
  lda map_selected
  inc a
  cmp #3      ; keep it at 0-2
  bcc @ok
  lda #0
@ok:
  sta map_selected
  plp
  rts

; all these examples below work
; like a switch/case on map_selected
Left_Handler:
.a16
.i16
  php
  A8
  lda map_selected
  ; lda sets the z flag, if map_selected == 0
  ; so we dont' need to cmp #0
  bne @1or2
@0:       ; BG1 (map_selected == 0)
  inc bg1_x
  bra @end
@1or2:
  cmp #1
  bne @2
@1:       ; BG2 (map_selected == 1)
  inc bg2_x
  bra @end
@2:       ; BG3 (map_selected == 2)
  inc bg3_x
@end:
  plp
  rts

Right_Handler:
.a16
.i16
  php
  A8
  lda map_selected
  ; lda sets the z flag, if map_selected == 0
  ; so we dont' need to cmp #0
  bne @1or2
@0:       ; BG1 (map_selected == 0)
  dec bg1_x
  bra @end
@1or2:
  cmp #1
  bne @2
@1:       ; BG2 (map_selected == 1)
  dec bg2_x
  bra @end
@2:       ; BG3 (map_selected == 2)
  dec bg3_x
@end:
  plp
  rts

Down_Handler:
.a16
.i16
  php
  A8
  lda map_selected
  ; lda sets the z flag, if map_selected == 0
  ; so we dont' need to cmp #0
  bne @1or2
@0:       ; BG1 (map_selected == 0)
  dec bg1_y
  bra @end
@1or2:
  cmp #1
  bne @2
@1:       ; BG2 (map_selected == 1)
  dec bg2_y
  bra @end
@2:       ; BG3 (map_selected == 2)
  dec bg3_y
@end:
  plp
  rts

Up_Handler:
.a16
.i16
  php
  A8
  lda map_selected
  ; lda sets the z flag, if map_selected == 0
  ; so we dont' need to cmp #0
  bne @1or2
@0:       ; BG1 (map_selected == 0)
  inc bg1_y
  bra @end
@1or2:
  cmp #1
  bne @2
@1:       ; BG2 (map_selected == 1)
  inc bg2_y
  bra @end
@2:       ; BG3 (map_selected == 2)
  inc bg3_y
@end:
  plp
  rts


set_scroll:
.a8
.i16
  php
  A8
; scroll registers are write twice, low byte then high byte
; the high bytes are always 0 in this demo
; because the map is 256x256 always (32x32 map and 8x8 tiles)
  lda bg1_x
  sta bg1_scroll_x    ; $210d
  stz bg1_scroll_x
  lda bg1_y
  sta bg1_scroll_y    ; $210e
  stz bg1_scroll_y

  lda bg2_x
  sta bg2_scroll_x    ; $210f
  stz bg2_scroll_x
  lda bg2_y
  sta bg2_scroll_y    ; $2110
  stz bg2_scroll_y

  lda bg3_x
  sta bg3_scroll_x    ; $2101
  stz bg3_scroll_x
  lda bg3_y
  sta bg3_scroll_y    ; $2112
  stz bg3_scroll_y
  plp
  rts

wait_nmi:
.a8
.i16
; should work fine regardless of size of A
  lda in_nmi      ; load A register with the previous in_nmi
@check_again:
  WAI             ; wait for an interrupt
  cmp in_nmi      ; compare A to current in_nmi
                  ; wait for it to change
                  ; make sure it was an nmi interrupt
  beq @check_again
  rts

dma_oam:
.a8
.i16
  php
  A8
  XY16
  ldx #$0000
  stx oam_addr_L      ; $2102 (and 2103)
  
  stz $4300           ; transfer mode 0 = 1 regsiter write once
  lda #4              ; $2104 oam data
  sta $4301           ; desination, oam data
  ldx #.loword(OAM_BUFFER)
  stx $4302           ; source
  lda #^OAM_BUFFER
  sta $4304           ; bank
  ldx #544
  stx $4305           ; length
  lda #1
  sta $420b           ; start dma, channel 0
  plp
  rts


pad_poll:
.a8
.i16
; reads both controllers to pad1, pad1_new, pad2, pad2_new
; auto controller reads done, call this once per main loop
; copies the current controller reads to these variables
; pad1, pad1_new, pad2, pad2_new (all 16 bit)
  php
  A8
@wait:
; wait till auto controller reads are done
  lda $4212
  lsr a
  bcs @wait

  A16
  lda pad1
  sta temp1       ; save last frame
  lda $4218       ; controller 1
  sta pad1
  eor temp1
  and pad1
  sta pad1_new

  lda pad2
  sta temp1
  lda $421a
  sta pad2
  eor temp1
  and pad2
  sta pad2_new
  plp
  rts



clear_sp_buffer:
.a8
.i16
  php
  A8
  XY16
  lda #224      ; put all y values just below the screen
  ldx #$0000
  ldy #128      ; number of sprites
@loop:
  sta OAM_BUFFER+1, x
  inx
  inx
  inx
  inx           ; add 4 to x
  dey
  bne @loop
  plp
  rts





.include "header.asm"

.segment "RODATA1"

BG_Palette:
.incbin "bgAll.pal"

BG12Tiles:
; 4bpp tileset compressed
.incbin "RLE/bg12tileset.rle"

BG34Tiles:
; title tiles
; 2bpp tileset compressed
.incbin "RLE/bg34tileset.rle"

BG1Tilemap:
; chewie tilemap
; tilemap compressed
.incbin "RLE/bg1map.rle"

BG2Tilemap:
; custom BG tilemap
; tilemap compressed
.incbin "RLE/bg2map.rle"

BG3Tilemap:
; title
; tilemap compressed
.incbin "RLE/bg3map.rle"

Spr_Tiles:
.incbin "sprite.chr"
End_Spr_Tiles:

Sprites:
; 4 bytes per sprite = x, y, tile #, attribute
.incbin "floofMeta.bin"
End_Sprites: