.p816
.smart

.segment "ZEROPAGE"

pad1: .res 2
pad1_new: .res 2
pad2: .res 2
pad2_new: .res 2
in_nmi: .res 2


.segment "BSS"

PAL_BUFFER: .res 512

OAM_BUFFER: .res 512 ; low table
OAM_BUFFER2: .res 32 ; high table


.include "define.asm"
.include "macros.asm"
.include "init.asm"
.include "unrle.asm"


.segment "CODE"

; enters here // in foced blank
main:
.a16    ; reminder of the setting from the init code
.i16
  phk   ; setst he data bank register to the same as the Program Bank
  plb

  jsr clear_sp_buffer

; COPY PALETTES to PAL_BUFFER
; BLOCK_MOVE length, src_addr, dst_addr
  BLOCK_MOVE 512, BG_Palette, PAL_BUFFER

; COPY sprites to SPRITE BUFFER
  BLOCK_MOVE 422, Sprites, OAM_BUFFER

; COPY just 1 high table number
  A8
  lda #$2a  ; = 00101010 = flip all the size bits to large
              ; will give us 16x16 tiles
  sta OAM_BUFFER2

; DMA from BG_Palette to CGRAM
  A8              ; macro to put registers in 8 bit mode
  stz pal_addr    ; $2121 cg address = zero

  stz $4300 ; transfer mode 0 = 1 register write once
  lda #$22  ; $2122
  sta $4301 ; destination palette data
  
  ldx #.loword(PAL_BUFFER)
  stx $4302 ; source
  lda #^PAL_BUFFER
  sta $4304 ; bank
  ldx #512
  stx $4305 ; length
  lda #1
  sta $420b ; start dma, channel 0


; DMA from OAM_BUFFER to the OAM RAM
  jsr dma_oam

;  ldx #$0000
;  stx oam_addr_L    ; $2102 & 2103
;  
;  stz $4300         ; transfer mode 0 = 1 register write once
;  lda #4            ; $2104 oam data
;  sta $4301         ; destination, oam data
;  ldx#.loword(OAM_BUFFER)
;  stx $4302         ; source
;  lda #^OAM_BUFFER
;  sta $4304         ; bank
;  ldx #544
;  stx $4305         ; length
;  lda #1
;  sta $420b         ; start dma, channel 0


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


  

  lda #SPR_ON     ; show only sprites
  sta main_screen ; #212c

  lda #NMI_ON|AUTO_JOY_ON
  sta $4200

; turn screen on // end of forced blank
  lda #FULL_BRIGHT ; $0f = turn the screen on, full brightness
  sta fb_bright ; $2100

InfiniteLoop:
  jsr wait_nmi      ; wait for beginning of v-blank
  jsr dma_oam       ; copy the OAM_BUFFER to the OAM
  jsr pad_poll      ; read controllers

  AXY16

  lda pad1
  and #KEY_LEFT
  beq @not_left
@left:
  A8
  dec OAM_BUFFER
  dec OAM_BUFFER+4
  dec OAM_BUFFER+8
  A16
@not_left:

  lda pad1
  and #KEY_RIGHT
  beq @not_right
@right:
  A8
  inc OAM_BUFFER    ; increase the x values
  inc OAM_BUFFER+4
  inc OAM_BUFFER+8
  A16
@not_right:

  lda pad1
  and #KEY_UP
  beq @not_up
@up:
  A8
  dec OAM_BUFFER+1  ; decrease the Y values
  dec OAM_BUFFER+5
  dec OAM_BUFFER+9
  A16
@not_up:

  lda pad1
  and #KEY_DOWN
  beq @not_down
@down:
  A8
  inc OAM_BUFFER+1  ; increase the Y values
  inc OAM_BUFFER+5
  INC OAM_BUFFER+9
  A16
@not_down:
  A8
  jmp InfiniteLoop



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


wait_nmi:
.a8
.i16
; should work fine regardless of size of A
  lda in_nmi    ; load A register with previous in_nmi
@check_again:
  WAI           ; wait for an iterrupt
  cmp in_nmi    ; compare A to current in_nmi
                ; wait for it to change
                ; to ensure it was an nmi interrupt
  beq @check_again
  rts


dma_oam:
.a8
.i16
  php
  A8
  XY16
  ldx #$0000
  stx oam_addr_L    ; $2102 & 2103

  stx $4300         ; transfer mode 0 = 1 register write once
  lda #4            ; $2104 oam data
  sta $4301         ; destination, oam data
  ldx #.loword(OAM_BUFFER)
  stx $4302         ; source
  lda #^OAM_BUFFER
  sta $4304         ; bank
  ldx #544
  stx $4305         ; length
  lda #1
  sta $420b         ; start dma, channel 0
  plp
  rts


pad_poll:
.a8
.i16
  php
  A8
@wait:
; wait till auto-controller reads are done
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
  sta temp1       ; save last frame
  lda $421a       ; controller 2
  sta pad2
  eor temp1
  and pad2
  sta pad2_new
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