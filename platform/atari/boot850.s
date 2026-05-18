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

DUMMY_DDEVIC = $31       ; Device ID for Disk 1
DUMMY_DUNIT  = $01       ; Device number 1
DUMMY_DCOMND = $53       ; Status command
DUMMY_DAUX1  = $00       ; Unused
DUMMY_DAUX2  = $00       ; Unused
DUMMY_DBYT   = 4         ; Num bytes in disk response
DUMMY_DSTATS = %01000000 ; Bit 6 - receive data
DUMMY_DTIMLO = $07       ; Time to wait for the response
DUMMY_DBUF   = $0660     ; Location to store the response

POLL_DDEVIC    = $50       ; Device ID for 850 RS232 port
;POLL_DDEVIC    = $4f       ; Device ID for 850 RS232 port
;POLL_DDEVIC    = $00       ; Device ID for 850 RS232 port
POLL_DUNIT     = $01       ; Device number 1
POLL_DCOMND    = $3f       ; Poll command to see if devices have handlers to load
POLL_DAUX1     = $01       ; Forces the device to always respond
POLL_DAUX2     = $00       ; Unused
POLL_DBYT      = 12        ; Num bytes in 850 response
POLL_DSTATS    = %01000000 ; Bit 6 - receive data
POLL_DTIMLO    = $1f       ; Time to wait for the 850 to respond in seconds
POLL_DBUF      = $0664     ; Poll response from 850 to retrieve loader (known safe location)

DIRECT_DDEVIC    = $50       ; Device ID for 850 RS232 port
DIRECT_DUNIT     = $01       ; Device number 1
DIRECT_DCOMND    = $21       ; Poll command to see if devices have handlers to load
DIRECT_DAUX1     = $00       ; Forces the device to always respond
DIRECT_DAUX2     = $00       ; Unused
DIRECT_DBYT      = $0156     ; Num bytes in 850 response
DIRECT_DSTATS    = %01000000 ; Bit 6 - receive data
DIRECT_DTIMLO    = $1f       ; Time to wait for the 850 to respond in seconds
DIRECT_DBUF      = $0664     ; Poll response from 850 to retrieve loader (known safe location)

BOOTER_ENTRY   = $0506     ; Booter/relocator load address and entry point, hardcoded in DOS II's AUTORUN.sys
HATABS_ENTRIES = 8
HATABS_SIZE    = HATABS_ENTRIES * 3

.SEGMENT "CODE"

.EXPORT wakeup850
.EXPORT check850
.EXPORT boot850_poll
.EXPORT boot850_direct
.EXPORT boot850_poll_device

; I was having issues getting the real 850 to respond. Apparently
; it powers up in a locked state ignoring $50 commands
; until it sees D1: activity on the SIO bus. This dummy status
; command forces D1 to respond with an ACK, thus unlocking 
; it's R: listener so that my poll will succeed.
wakeup850:
  lda #DUMMY_DDEVIC
  sta DDEVIC
  lda #DUMMY_DUNIT
  sta DUNIT
  lda #DUMMY_DCOMND
  sta DCOMND
  lda #DUMMY_DSTATS
  sta DSTATS
  lda #<DUMMY_DBUF
  sta DBUFLO
  lda #>DUMMY_DBUF
  sta DBUFHI
  lda #<DUMMY_DBYT
  sta DBYTLO
  lda #>DUMMY_DBYT
  sta DBYTHI
  lda #DUMMY_DTIMLO
  sta DTIMLO
  lda #DUMMY_DAUX1
  sta DAUX1
  lda #DUMMY_DAUX2
  sta DAUX2

  ; we don't care about the response. The 850 sees
  ; the command either way
  jsr SIOV
  rts

check850:
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
  sec ; failure
  rts
@installed:
  clc ; success
  rts
@error:

boot850_poll:
  lda #1
  sta poll_counter

@loop:
  ;lda #POLL_DDEVIC
  lda boot850_poll_device
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

  ; Send command and wait for 850 to respond with
  ; the command needed to retrieve the booter/relocator.
  ; This is the exact command the 850 will listen to
  ; to load its handler.
  jsr SIOV
  bpl @poll_succeeded
  lda poll_counter
  sec
  sbc #1
  beq @error
  sta poll_counter
  bne @loop

@poll_succeeded:
  ; Copy the 12 bytes from the 850 poll response
  ; into the HW Device Control Block (DCB). This
  ; is the command to load the booter.
  ldx #POLL_DBYT-1
@copy:
  lda POLL_DBUF,x
  sta DDEVIC,x
  dex
  bpl @copy

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

boot850_direct:
  ;lda #DIRECT_DDEVIC
  lda boot850_poll_device
  sta DDEVIC
  lda #DIRECT_DUNIT
  sta DUNIT
  lda #DIRECT_DCOMND
  sta DCOMND
  lda #DIRECT_DSTATS
  sta DSTATS
  lda #<DIRECT_DBUF
  sta DBUFLO
  lda #>DIRECT_DBUF
  sta DBUFHI
  lda #<DIRECT_DBYT
  sta DBYTLO
  lda #>DIRECT_DBYT
  sta DBYTHI
  lda #DIRECT_DTIMLO
  sta DTIMLO
  lda #DIRECT_DAUX1
  sta DAUX1
  lda #DIRECT_DAUX2
  sta DAUX2

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

poll_counter: .byte 26
boot850_poll_device: .byte 0
