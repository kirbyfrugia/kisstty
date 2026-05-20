
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
