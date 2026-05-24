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
; modifies/outputs:
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

; Writes char to (CMDDATA0),y
;
; inputs:
;   - CMDDATA0/CMDDATA1 - location to print
;   - y - offset from location
;   - a - byte to print 
utils_byte_to_scr_hex:
  sta tmp_byte_to_str
  txa
  pha
  tya
  pha

  lda tmp_byte_to_str
  lsr
  lsr
  lsr
  lsr
  tax
  lda HEX_TABLE_SCR,x
  sta (CMDDATA0),y
  lda tmp_byte_to_str
  and #%00001111
  tax
  iny
  lda HEX_TABLE_SCR,x
  sta (CMDDATA0),y

  pla
  tay
  pla
  tax
  lda tmp_byte_to_str
  rts

; dump memory to screen in an 8-byte row with an address
; 
; input:
;   CMDDATA0/CMDDATA1- screen address
;   CMDDATA2/CMDDATA3- start address lo/hi
; modifies:
utils_dump_mem_row:
  pha
  txa
  pha
  tya
  pha

  lda CMDDATA3
  ldy #0
  jsr utils_byte_to_scr_hex
  lda CMDDATA2
  ldy #2
  jsr utils_byte_to_scr_hex
  lda #':'
  jsr utils_atascii_to_icode
  ldy #4
  sta (CMDDATA0),y
  lda #' '
  jsr utils_atascii_to_icode
  ldy #5
  sta (CMDDATA0),y

  iny
  ldx #0
@next_byte:
  sty tmp_dump_mem
  txa
  tay
  lda (CMDDATA2),y
  ldy tmp_dump_mem
  jsr utils_byte_to_scr_hex
  iny
  iny

  lda #' '
  jsr utils_atascii_to_icode
  sta (CMDDATA0),y
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

tmp_dump_mem:    .byte 0
tmp_byte_to_str: .byte 0
