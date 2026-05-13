.SETCPU "6502"
.INCLUDE "atari.inc"

.SEGMENT "CODE"

.EXPORT boot_850

; will set carry if it cannot load the 850
boot_850:
  clc
  rts
