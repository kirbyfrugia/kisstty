.SETCPU "6502"
.INCLUDE "apple2.inc"

.SEGMENT "CODE"

.EXPORT start

start:
  lda KBD
  bpl start
  sta KBDSTRB
  rts
