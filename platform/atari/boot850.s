; =============================================================================
; Bootstraps the Atari 850 R: handler
; * (mostly) Handles ROM revisions automatically since it uses the info
;   from the 850. See readme for a possible exception.
;
; Source: Altirra Hardware Reference Manual (Avery Lee) pages 251-253
;
; Requirements:
;   $0500-$0658 must be free
; =============================================================================

.SETCPU "6502"
.INCLUDE "atari.inc"
.INCLUDE "macros.inc"
.SEGMENT "CODE"

POLL_DDEVIC    = $50       ; Device ID for 850 RS232 port
POLL_DUNIT     = $01       ; Device number 1
POLL_DCOMND    = $3f       ; Poll command to see if devices have handlers to load
POLL_DSTATS    = %01000000 ; Bit 6 - receive data
POLL_DBUF      = $0664     ; Poll response from 850 to retrieve loader (known safe location)
POLL_DTIMLO    = $02       ; Time to wait for the 850 to respond in seconds
POLL_DBYT      = 12        ; Num bytes in 850 response
POLL_DAUX1     = $01       ; Forces the device to always respond
POLL_DAUX2     = $00       ; Unused

BOOTSTRAP      = $0506     ; Booter/relocator load address and entry point, hardcoded in DOS II's AUTORUN.sys
LOAD_RHANDLER  = $0ab3     ; Adds the R: handler to HATABS

HATABS_ENTRIES = 8
HATABS_SIZE    = HATABS_ENTRIES * 3


.EXPORT boot850_bootstrap ; bootstrap the 850 (only thing you really need to call)
.EXPORT boot850_check     ; check if R: handler present in HATABS

; Boot the 850. Bootstraps and loads the 850's R: handler
; outputs:
;   carry - clear if succeeded, set if not.
boot850_bootstrap:
  lda #POLL_DDEVIC
  sta DDEVIC
  lda #POLL_DUNIT
  sta DUNIT
  lda #POLL_DCOMND
  sta DCOMND
  lda #POLL_DSTATS
  sta DSTATS
  lda #<POLL_DBUF
  sta DBUFLO
  lda #>POLL_DBUF
  sta DBUFHI
  lda #<POLL_DBYT
  sta DBYTLO
  lda #>POLL_DBYT
  sta DBYTHI
  lda #POLL_DTIMLO
  sta DTIMLO
  lda #POLL_DAUX1
  sta DAUX1
  lda #POLL_DAUX2
  sta DAUX2

  ; Send poll command and wait for 850 to respond with
  ; the command needed to retrieve the booter/relocator.
  jsr SIOV
  bmi @error

@poll_succeeded:
  ; Copy the 12 bytes from the 850 poll response
  ; into the HW Device Control Block (DCB). This
  ; is the command to load the booter. It is command $21.
  ldx #POLL_DBYT-1
@copy:
  lda POLL_DBUF,x
  sta DDEVIC,x
  dex
  bpl @copy

  jsr SIOV
  bmi @error
@bootstrap:
  ; execute the bootstrap code provided by the 850's ROM
  jsr BOOTSTRAP ; bootstraps the 850
  ; load the r: handler into HATABS. The Altirra docs didn't
  ; mention this as far as I could find, but I had to do it
  ; to get the actual handler loaded so the system was aware
  ; of it.
  jsr LOAD_RHANDLER
@installed:
  clc
  rts
@error:
  sec
  rts

; Checks to see if there is an R: device in HATABS
; outputs:
;   carry - clear if in HATABS, set if not.
boot850_check:
  ; There are up to 8 devices, each one takes up 3 bytes
  ldx #0
@check_installed:
  lda HATABS,x
  cmp #'R'
  beq @installed
  inx
  inx
  inx
  cpx #HATABS_SIZE
  bcc @check_installed
  sec ; failure
  rts
@installed:
  clc
  rts
@error:
  sec
  rts

