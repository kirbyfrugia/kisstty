.SETCPU "6502"
.INCLUDE "atari.inc"
.INCLUDE "macros.inc"
.INCLUDE "common.inc"

MAX_INPUT_LEN = 114

.EXPORT utils_atascii_to_icode
.EXPORT utils_byte_to_scr_hex
.EXPORT utils_dump_mem_row

.SEGMENT "CODE"

; converts an atascii character to icode,
; used for screen display
;
;
; Reference: Mapping the atari, $e108
; inputs:
;   a - the character in atascii
; outputs:
;   a - the char in icode
utils_atascii_to_icode:
  cmp #32
  bcs @check_gteq_32
  ; 0 to 31, add 64
  clc
  adc #64
  bne @done
@check_gteq_32:
  cmp #96
  bcs @check_gteq_96
  ; 32 to 95, sub 32
  sec
  sbc #32
  jmp @done
@check_gteq_96:
  cmp #128
  bcs @check_gteq_128
  ; 96 to 127, no change
  bne @done
@check_gteq_128:
  cmp #160
  bcs @check_gteq_160
  ; 128 to 159, add 64
  clc
  adc #64
  bne @done
@check_gteq_160:
  cmp #224
  bcs @gteq_224
  ; 160 to 223, sub 32
  sec
  sbc #32
  bne @done
@gteq_224:
  ; 224 to 255, no change
@done:
  rts

; inputs:
;   - ZPB0/ZPB1 - location to print
;   - y - offset from location
;   - a - byte to print 
; outputs:
;   - Writes char to (zpb0),y
; modifies:
;   - UTILS_TMP1
utils_byte_to_scr_hex:
  sta UTILS_TMP1
  txa
  pha
  tya
  pha

  lda UTILS_TMP1
  lsr
  lsr
  lsr
  lsr
  tax
  lda HEX_TABLE_SCR,x
  sta (ZPB0),y
  lda UTILS_TMP1
  and #%00001111
  tax
  iny
  lda HEX_TABLE_SCR,x
  sta (ZPB0),y 

  pla
  tay
  pla
  tax
  lda UTILS_TMP1
  rts

; dump memory to screen in an 8-byte row with an address
; 
; input:
;   ZPB0/ZPB1 - screen address
;   ZPB2/ZPB3 - start address lo/hi
;   y - offset from start of screen row to print
; modifies:
;   - UTILS_TMP2
utils_dump_mem_row:
  pha
  txa
  pha
  tya
  pha

  lda ZPB3
  ldy #0
  jsr utils_byte_to_scr_hex
  lda ZPB2
  ldy #2
  jsr utils_byte_to_scr_hex
  lda #':'
  jsr utils_atascii_to_icode
  ldy #4
  sta (ZPB0),y
  lda #' '
  jsr utils_atascii_to_icode
  ldy #5
  sta (ZPB0),y

  iny
  ldx #0
@next_byte:
  sty UTILS_TMP2
  txa
  tay
  lda (ZPB2),y
  ldy UTILS_TMP2
  jsr utils_byte_to_scr_hex
  iny
  iny

  lda #' '
  jsr utils_atascii_to_icode
  sta (ZPB0),y
  iny
  inx
  cpx #8
  bne @next_byte
@done:
  pla
  tay
  pla
  tax
  pla
  rts

HEX_TABLE_ATASCII: .byte "0123456789ABCDEF"

; subtract 32 from their ATASCII since all are 32 to 95
HEX_TABLE_SCR:
  .byte 16,17,18,19,20,21,22,23,24,25
  .byte 33,34,35,36,37,38

