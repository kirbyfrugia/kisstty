.SETCPU "6502"
.INCLUDE "atari.inc"
.INCLUDE "macros.inc"

MAX_INPUT_LEN = 114

.EXPORT utils_hex_to_str
.EXPORT utils_hex_str
.EXPORT utils_print_dcb
.EXPORT utils_print_hatabs
.EXPORT utils_dump_mem

.SEGMENT "CODE"

ZPB0 = $80
ZPB1 = $81
ZPB2 = $82
ZPB3 = $83

; writes the hex value in A to hex_str offset by y
; adds a $9b at the end
; Note: Y will be incremented by 2.
utils_hex_to_str:
  sta tmp0
  stx tmp1
  pha
  lsr
  lsr
  lsr
  lsr
  tax
  lda HEX_TABLE,x
  sta utils_hex_str,y
  pla
  and #%00001111
  tax
  iny
  lda HEX_TABLE,x
  sta utils_hex_str,y 
  iny
  lda #$9b
  sta utils_hex_str,y
  ldx tmp1
  lda tmp0
  rts

; dump memory to screen in 8-byte rows with address
; input:
;   $80/$81 = start address lo/hi
;   x       = number of rows to print
; also uses $82 and $83

; example usage:
;  lda #<$031a
;  sta $80
;  lda #>$031a
;  sta $81
;  ldx #3 ; each row is 8 bytes
;  jsr utils_dump_mem
utils_dump_mem:
  stx dump_rows
@next_row:
  ldy #0
  lda ZPB1
  jsr utils_hex_to_str
  lda ZPB0
  jsr utils_hex_to_str
  lda #':'
  sta utils_hex_str,y
  iny
  lda #' '
  sta utils_hex_str,y
  iny

  ldx #0
@next_byte:
  sty ZPB2
  txa
  tay
  lda (ZPB0),y
  ldy ZPB2
  jsr utils_hex_to_str
  lda #' '
  sta utils_hex_str,y
  iny
  inx
  cpx #8
  bne @next_byte
  dey
  lda #$9b
  sta utils_hex_str,y
  print_str utils_hex_str
  dec dump_rows
  beq @done

  lda ZPB0
  clc
  adc #8
  sta ZPB0
  lda ZPB1
  adc #0
  sta ZPB1
  jmp @next_row
@done:
  rts

utils_print_dcb:
  pha
  txa
  pha
  tya
  pha
  print_bytes str_dcb, str_dcb_end
  ldy #0
  ldx #0
@loop:
  lda DDEVIC,x
  jsr utils_hex_to_str
  lda #','
  sta utils_hex_str,y
  iny
  inx
  cpx #12
  bne @loop
  dey
  lda #$9b
  sta utils_hex_str,y
  print_str utils_hex_str
  pla
  tay
  pla
  tax
  pla
  rts

utils_print_hatabs:
  pha
  txa
  pha
  tya
  pha
  print_bytes str_hatabs, str_hatabs_end

  ldy #0
  ldx #0
@loop:
  lda HATABS,x
  sta hatabs_str, y
  inx
  inx
  inx
  iny
  lda #','
  sta hatabs_str, y
  iny
  cpx #24
  bcc @loop

  lda #$9b
  sta hatabs_str, y

  print_str hatabs_str

  pla
  tay
  pla
  tax
  pla

  rts

dump_rows: .byte 0
dump_buf:  .res 64
utils_hex_str: .res 80
hatabs_str: .res 80
tmp0: .byte 0
tmp1: .byte 0
tmp2: .byte 0

str_dcb:
  .byte "dcb: "
str_dcb_end:

str_hatabs:
  .byte "HATABS: "
str_hatabs_end:

HEX_TABLE: .byte "0123456789ABCDEF"

