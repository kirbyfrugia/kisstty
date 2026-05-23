.macro dbg_print_zpb scr_base_lo, scr_base_hi, scr_offset, addr
  pha
  tya
  pha
  lda ZPB0
  pha
  lda ZPB1
  pha
  lda ZPB2
  pha
  lda ZPB3
  pha
  lda scr_base_lo
  clc
  adc #scr_offset
  sta ZPB0
  lda scr_base_hi
  adc #0
  sta ZPB1
  lda #<addr
  sta ZPB2
  lda #>addr
  sta ZPB3
  ldy #0
  jsr utils_dump_mem_row

  pla
  sta ZPB3
  pla
  sta ZPB2
  pla
  sta ZPB1
  pla
  sta ZPB0
  pla
  tay
  pla
.endmacro

.macro print_str str_data
  ldx #0
  lda #<str_data
  sta ICBAL,x
  lda #>str_data
  sta ICBAH,x

  lda #$ff
  sta ICBLL,x
  lda #0
  sta ICBLH,x

  lda #PUTREC
  sta ICCOM,x
  jsr CIOV
.endmacro

.macro print_bytes str_data, str_data_end
  ldx #0
  lda #<str_data
  sta ICBAL,x
  lda #>str_data
  sta ICBAH,x
  lda #<(str_data_end-str_data)
  sta ICBLL,x
  lda #>(str_data_end-str_data)
  sta ICBLH,x

  lda #11
  sta ICCOM,x
  jsr CIOV
.endmacro

.macro invstr str
  .repeat .strlen(str), i
    .byte .strat(str, i) | $80
  .endrepeat
.endmacro
