.p816
.smart

.include "define.asm"
.include "macros.asm"
.include "init.asm"

.segment "CODE"

; enters here // in foced blank
main:
.a16    ; reminder of the setting from the init code
.i16
  phk   ; setst he data bank register to the same as the Program Bank
  plb

  A8              ; macro to put registers in 8 bit mode
  
  stz pal_addr    ;set color address to 0
  lda #$1f        ;palette low byte   gggrrrrr
  sta pal_data    ;1f = all the red bits
  lda #$00        ;palette high byte  -bbbbbgg
  sta pal_data    ;store zero for high byte

; turn screen on // end of forced blank

  lda #$0f
  sta $2100

InfiniteLoop:
  jmp InfiniteLoop

.include "header.asm"