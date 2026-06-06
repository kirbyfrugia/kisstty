.SETCPU "6502"
.INCLUDE "atari.inc"
.INCLUDE "macros.inc"
.INCLUDE "common.inc"

.EXPORTZP utils_bcd_result
.EXPORT   utils_atascii_to_icode
.EXPORT   utils_hex_table_atascii
.EXPORT   utils_hex_to_atascii
.EXPORT   utils_hex_to_icode
.EXPORT   utils_bin_to_bcd

.SEGMENT "ZEROPAGE"
bcd_tmp:          .res 1
utils_bcd_result: .res 2

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

; Writes char in hex in atascii to (CMDDATA0),y
;
; inputs:
;   - CMDDATA0/CMDDATA1 - location to print
;   - y - offset from location
;   - a - byte to print 
utils_hex_to_atascii:
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
  lda utils_hex_table_atascii,x
  sta (CMDDATA0),y
  lda tmp_byte_to_str
  and #%00001111
  tax
  iny
  lda utils_hex_table_atascii,x
  sta (CMDDATA0),y

  pla
  tay
  pla
  tax
  lda tmp_byte_to_str
  rts


; Writes char in icode to (CMDDATA0),y
;
; inputs:
;   - CMDDATA0/CMDDATA1 - location to print
;   - y - offset from location
;   - a - byte to print 
utils_hex_to_icode:
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
  lda hex_table_scr,x
  sta (CMDDATA0),y
  lda tmp_byte_to_str
  and #%00001111
  tax
  iny
  lda hex_table_scr,x
  sta (CMDDATA0),y

  pla
  tay
  pla
  tax
  lda tmp_byte_to_str
  rts

; Thanks to [Andrew Jacobs]( https://6502.org/source/integers/hex2dec-more.htm)
; inputs:
;   A - value to convert
; outputs:
;   bcd_result+0 = low nibble is ones, high nibble is 10s
;   bcd_result+1 = hundreds digit
; modifies:
;   A and X
utils_bin_to_bcd:
  sta bcd_tmp
  lda #0
  sta utils_bcd_result+0
  sta utils_bcd_result+1
  ldx #8

  sed
@loop:
  asl bcd_tmp
  lda utils_bcd_result+0
  adc utils_bcd_result+0
  sta utils_bcd_result+0
  lda utils_bcd_result+1
  adc utils_bcd_result+1
  sta utils_bcd_result+1
  dex
  bne @loop
  cld

  rts

utils_hex_table_atascii: .byte "0123456789ABCDEF"

; subtract 32 from their ATASCII since all are 32 to 95
hex_table_scr:
  .byte 16,17,18,19,20,21,22,23,24,25
  .byte 33,34,35,36,37,38

tmp_byte_to_str: .byte 0
