; unrle code to unpack the rle file from M1TE
; unpack size can't be larger than 32kB ($8000)

UNPACK_ADR = $7f0000

.segment "CODE"

; in axy16
; a = address of the compressed data
; x = bank of the compressed data

; returns y = size of unpacked data
; and ax = address of UNPACK_ADR


unrle:
.a16
.i16
    rep #$30        ; axy16
    sta temp1
    stx temp2
    stz temp4       ; index to dst
    ldy #0
@loop:
    sep #$20        ; a8
    lda #0          ; clear the upper byte for later
    xba
; read header byte
    lda [temp1], y
    cmp #$f0
    bcs @done
    and #$c0        ; get mode
    bne @1
    jmp @lit_short  ; 00
@1:
    cmp #$40
    bne @2
    jmp @rle_short  ; 40
@2:
    cmp #$80
    bne @3
    jmp @plus_short ; 80
@3:
; 2 byte header
;   - get 1st byte
    lda [temp1], y
    and #$30
    bne @4
    jmp @lit_long   ; c0
@4:
    cmp #$10
    bne @5
    jmp @rle_long   ; d0
@5:
    jmp @plus_long


@done:
; see if planar
    and #$0f
    bne @plannar    ; ff
@standard:          ; f0

@exit:
    rep #$30        ; axy16
    lda #.loword(UNPACK_ADR)
    ldx #^UNPACK_ADR
    ldy temp4       ; size
    rtl


@plannar:
.a8
; interleave the bytes
    rep #$30        ; axy16
    lda #.loword(UNPACK_ADR)
    ldy #^UNPACK_ADR
    sta temp1
    lda temp4       ; size
        pha         ; save size
    clc
    adc temp1
    sta temp5
        pha         ; save address
    lda temp4       ; size
    lsr a           ; half
    tax             ; half size as counter
    clc
    adc temp1
    sta temp3       ; full size, start of output buffer
    sty temp2       ; bank bytes
    sty temp4
    sty temp6
; temp1 points to the start of the buffer, temp3 points to halfway point
    sep #$20        ; a8
    ldy #0
@loop2:
    lda [temp3], y  ; high byte
    xba
    lda [temp1], y  ; low byte
    rep #$20        ; a16
    sta [temp5], y  ; combined byte
    iny
    inc temp5       ; 16 bit inc
    sep #$20        ; a8
    dex
    bne @loop2

@exit2:
    rep #$30        ; axy16
    ;lda #.loword(UNPACK_ADR)
    pla             ; output address
    ldx #^UNPACK_ADR
    ply             ; size
    rtl


@lit_short:
.a8
.i16
    ; upper byte should be clear
    lda [temp1], y  ; get repeat count
    and #$3f
    ; note register size mismatch
    tax             ; loop count
    iny
    bra @literal

@lit_long:
    rep #$20        ; a16
    lda [temp1], y  ; get repeat count
    xba             ; the bytes are in reverse order
    and #$0fff
    tax
    iny
    iny             ; 2 byte header
    sep #$20        ; a8
    ; fall through, x = repeat count
@literal:           ; copy literal bytes
.a8
    inx             ; repeat +1
    stx temp3       ; count
    ldx temp4       ; index to dst
@loop4:
    sep #$20        ; a8
    lda [temp1], y
    sta f:UNPACK_ADR, x
    iny
    inx
    rep #$20        ; a16
    dec temp3       ; count 16 bit
    bne @loop4
    ; sep #$20      ; a8 - done at top of @loop
    stx temp4       ; index to dst
    jmp @loop


@rle_short:
.a8
.i16
    ; upper byte should be clear
    lda [temp1], y  ; get repeat count
    and #$3f
    ; note register size mismatch
    tax             ; loop count
    iny
    bra @do_rle
@rle_long:
    rep #$20        ; a16
    lda [temp1], y  ; get repeat count
    xba             ; the bytes are in reverse order
    and #$0fff
    tax
    iny
    iny             ; 2 byte header
    sep #$20        ; a8
    ; fall through, x = repeat count
@do_rle:
.a8
    inx ; repeat +1
    lda [temp1], y  ; the value to repeat
    iny
    phy
    txy             ; use y as counter
    ldx temp4       ; index to dst
@loop5:
    sta f:UNPACK_ADR, x
    inx
    dey
    bne @loop5

    ply
    ; sep #$20      ; a8 - done at top of @loop
    stx temp4       ; index to dst
    jmp @loop

@plus_short:
.a8
.i16
    ; upper byte should be clear
    lda [temp1], y  ; get repeat count
    and #$3f
    ; note the register size mismatch
    tax             ; loop count
    iny
    bra @do_plus
@plus_long:
    rep #$20        ; a16
    lda [temp1], y  ; get repeat count
    xba             ; the bytes are in reverse order
    and #$0fff
    tax
    iny
    iny             ; 2 byte header
    sep #$20        ; a8
    ; fall through, x = repeat count
@do_plus:
.a8
    inx             ; repeat +1
    lda [temp1], y  ; the value to repeat
    iny
    phy
    txy             ; use y as counter
    ldx temp4       ; index to dst
@loop6:
    sta f:UNPACK_ADR, x
    inc a          ; increase the value each loop
    inx
    dey
    bne @loop6

    ply
    ; sep#$20       ; a8 - done at top of @loop
    stx temp4       ; index to dst
    jmp @loop
