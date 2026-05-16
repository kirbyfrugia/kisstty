; =============================================================================
; Bootstraps the Atari 850 R: handler
; * NOTE: NOT YET TESTED BEYOND EMULATOR, WHICH ALREADY HAS
;         THE R-HANDLER LOADED
; * Handles ROM revisions automatically since it uses the info
;   from the 850.
;
; Source: Altirra Hardware Reference Manual (Avery Lee) pages 251-253
;
; Output:
; * carry set if there is an error bootstrapping
; * carry clear if r handler loaded (or was already loaded)
;
; Requirements:
;   $0500-$0658 must be free
; =============================================================================

.SETCPU "6502"
.INCLUDE "atari.inc"

DEVICE_ID_POLL   = $4F   ; Generic ID for devices with loadable handlers
POLL_FORCE_AUX1  = $01   ; Forces the device to respond
POLL_BYTES       = 12
CMD_POLL         = $3F   ; Poll command to see if devices have handlers to load
POLL_BUF         = $0600 ; Temp buffer for the 12-byte Device Control Block (DCB) returned by poll
BOOTER_ENTRY     = $0506 ; Booter/relocator load address and entry point, hardcoded in DOS II's AUTORUN.sys
HATABS_ENTRIES   = 8
HATABS_SIZE      = HATABS_ENTRIES * 3
DSTATS_READ_MODE = $40

.SEGMENT "CODE"

.EXPORT boot850

boot850:
  ; check the Handler Address Table (HATABS) to see if
  ; there is an R device in the table already.
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

  ; No R: handler loaded yet, poll to see if any devices
  ;   can autoload the R: handler (e.g. Atari 850)
  lda #DEVICE_ID_POLL
  sta DDEVIC
  lda #$01
  sta DUNIT
  lda #CMD_POLL
  sta DCOMND
  lda #DSTATS_READ_MODE
  sta DSTATS
  lda #<POLL_BUF
  sta DBUFLO
  lda #>POLL_BUF
  sta DBUFHI
  lda #<POLL_BYTES
  sta DBYTLO
  lda #>POLL_BYTES
  sta DBYTHI
  ;lda #$06
  lda #$1f
  sta DTIMLO
  lda #POLL_FORCE_AUX1
  sta DAUX1
  lda #$00
  sta DAUX2

  ; send command and wait for 850 to respond with its data
  jsr SIOV
  bmi @error

  ; Copy the 12 bytes the 850 returned into the hardware 
  ; Device Control Block (DCB)
  ldx #POLL_BYTES-1
@copy:
  lda POLL_BUF,x
  sta DDEVIC,x
  dex
  bpl @copy

  ; this will set DDEVIC $50, DCOMND $21 and
  ; load the booter into RAM
  jsr SIOV
  bmi @error

  ; execute the booter provided by the 850's ROM
  jsr BOOTER_ENTRY

@installed:
  clc ; success
  rts

@error:
  sec ; failure
  rts
