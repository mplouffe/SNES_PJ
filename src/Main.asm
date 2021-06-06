.p816
.smart

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
  ldx #64
  stx $4305 ; length
  lda #1
  sta $420b ; start dma, channel 0


; DMA from Tiles to VRAM
  lda #V_INC_1  ; the value $80
  sta vram_inc  ; $2115 = set the increment mode +1
  ldx #$0000
  stx vram_addr ; set an address in the vram of $0000

  lda #1
  sta $4300   ; transfer mode, 2 registers 1 write
              ; $2118 and $2119 are a pair Low/High
  lda #$18    ; $2118
  sta $4301   ; destination, vram data

; - decompress first
  AXY16
  lda #.loword(Tiles)
  ldx #^Tiles
  jsl unrle   ; unpacks to 7f0000 UNPACK_ADR
  ; returns y = length
  ; ax = unpack address (x is bank)
  sta $4302   ; source
  txa
  A8
  sta $4304   ; bank
  sty $4305   ; length
  lda #1
  sta $420b   ; start dma, channel 0


; DMA from Tilemap to VRAM
  ldx #$6000
  stx vram_addr ; set an address in the vram of $6000

; - decompress first
  AXY16
  lda #.loword(Tilemap)
  ldx #^Tilemap
  jsl unrle     ; unpacks to 7f0000 UNPACK_ADR
  ; returns y = length
  ; ax = unpack addr (x is bank)
  sta $4302     ; source
  txa
  A8
  sta $4304     ; bank
  sty $4305     ; length
  lda #1
  sta $420b     ; start dma, channel 0


; a is still 8 bit
  lda #1
  sta bg_size_mode  ; $2105

; 210b = tilesets for bg 1 and bg 2
; (210c for bg 3 and bg 4)
; setps of $1000 -321-321... bg2 bg1
  stz bg12_tiles    ; #210b BG 1 and 2 TILES at address $0000

  ; 2107 map address bg1, steps of $400, but -54321yx
  ; y/x = map size... 0,0 = 32x32 tiles
  ; $6000 / $100 = $60
  lda #$60        ; address $6000
  sta tilemap1    ; $2107

  lda #BG1_0N     ; only bg1 is active
  sta main_screen ; #212c



; turn screen on // end of forced blank
  lda #FULL_BRIGHT ; $0f = turn the screen on, full brightness
  sta fb_bright ; $2100

InfiniteLoop:
  jmp InfiniteLoop

.include "header.asm"

.segment "RODATA1"

BG_Palette:
.incbin "chewie.pal"

Tiles:
; 4bpp tileset compressed
.incbin "RLE/tileset.rle"

Tilemap:
; tilemap compressed
.incbin "RLE/map.rle"