; Resources
;   Best: [Altirra Hardware Reference Manual](https://www.virtualdub.org/downloads/Altirra%20Hardware%20Reference%20Manual.pdf)
;   [Assembly Language Programming for the Atari Computers](https://www.atariarchives.org/alp/index.php)
;   [De Re Atari](https://www.atariarchives.org/dere/)
;   [ChibiAkumas Tutorials](https://www.chibiakumas.com/6502/Atari800Atari5200.php)

.SETCPU "6502"
.INCLUDE "atari.inc"
.IMPORT boot850

.SEGMENT "CODE"

.EXPORT start
start:
  jsr boot850
  bcs @no850
  lda #<str_850loaded
  sta ICBAL
  lda #>str_850loaded
  sta ICBAH

  lda #<(str_850loaded_end-str_850loaded)
  sta ICBLL
  lda #>(str_850loaded_end-str_850loaded)
  sta ICBLH

  lda #PUTREC
  sta ICCOM

  ldx #$00
  jsr CIOV
  jmp @await_input

@no850:
  lda #<str_error_no850
  sta ICBAL
  lda #>str_error_no850
  sta ICBAH

  lda #<(str_error_no850_end-str_error_no850)
  sta ICBLL
  lda #>(str_error_no850_end-str_error_no850)
  sta ICBLH

  lda #PUTREC
  sta ICCOM

  ldx #$00
  jsr CIOV
 
@await_input:
  lda CH
  cmp #$FF
  beq @await_input
  rts

str_error_no850:
  .byte "No 850 found. Press a key."
str_error_no850_end:

str_850loaded:
  .byte "850 handler loaded. Press a key."
str_850loaded_end:

