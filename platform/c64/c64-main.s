.SETCPU "6502"
.INCLUDE "c64.inc"

CHROUT = $FFD2
GETIN  = $FFE4

; required by c64-asm.cfg
.SEGMENT "LOADADDR"
.EXPORT __LOADADDR__
__LOADADDR__:
  .WORD $0801

; BASIC stub: 10 SYS 2061
.SEGMENT "EXEHDR"
  .WORD link
  .WORD 10
  .BYTE $9E
  .BYTE "2061"
  .BYTE 0
link:
  .WORD 0

.SEGMENT "CODE"

start:
  jsr GETIN
  beq start
  rts
