; Resources
;   Best: [Altirra Hardware Reference Manual](https://www.virtualdub.org/downloads/Altirra%20Hardware%20Reference%20Manual.pdf)

.SETCPU "6502"
.INCLUDE "atari.inc"
.IMPORT boot_850

.SEGMENT "CODE"

.EXPORT start

start:
  jsr boot_850
  bcs print_error
  
  lda CH
  cmp #$FF
  beq start
  rts

print_error:
  brk
