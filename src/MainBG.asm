.p816
.smart

.include "define.asm"
.include "macros.asm"
.include "init.asm"
.include "unrle.asm"


.segment "BSS"

PAL_BUFFER: .res 512

OAM_BUFFER: .res 512 ; low table
OAM_BUFFER2: .res 32 ; high table

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



; turn screen on // end of forced blank
  lda #FULL_BRIGHT ; $0f = turn the screen on, full brightness
  sta fb_bright ; $2100

InfiniteLoop:
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