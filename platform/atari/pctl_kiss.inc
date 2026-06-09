; Protocols:
; * [KISS](https://erikarn.github.io/ax25/CNC1987-KISS-TNC-K3MC-KA9Q.pdf)
; * [APRS](https://aprspedia.com/doku.php?id=aprs_protocols:digipeter_addresses_field)
; * [AX.25](https://www.ax25.net/AX25.2.2-Jul%2098-2.pdf)
;
; Frames are sent in 8-bit binary.
; Frames are preceded and followed by the FEND byte, e.g.
; FEND CMD ...data... FEND
;
; We need to handle the case where we get data before the
; first FEND and the case where we get multiple FENDs
; in a row (e.g. between frames or when the sender wants
; to explicitly flush the buffer).
;
; This is simple.
;
; On startup, set `kiss_started` to false and `buffer_index`
; to zero.
;
; When FEND is received, if buffer_index is greater than zero,
; process the frame. Whether or not there was data, reset
; the buffer (set buffer_index to 0).
;
; Special bytes within the data are escaped using two-byte
; sequences. FESC introduces the escape, and the byte
; following it indicates what the original byte was:
;   FESC TFEND ($db $dc) -> original byte was $c0 (FEND)
;   FESC TFESC ($db $dd) -> original byte was $db (FESC)
.ifndef PCTL_KISS_INC
.define PCTL_KISS_INC

.define KISS_STATE_NEW    %10000000 ; waiting for first FEND
.define KISS_STATE_FESC   %01000000 ; in an FESC waiting for next byte
.define KISS_STATE_ADDR   %00100000 ; the address portion of the frame
.define KISS_STATE_BTWN   %00010000 ; the bytes between addr and info
.define KISS_STATE_INFO   %00001000 ; the info portion
.define KISS_FRAME_READY  %00000100 ; frame complete and ready to be processed

KISS_FEND  = $c0
KISS_FESC  = $db
KISS_TFEND = $dc
KISS_TFESC = $dd

KISS_DUPLEX_HALF = %00000000
KISS_DUPLEX_FULL = %11111111

; commands 
; all the times/delays are in 10ms units,
; e.g. a TX_DELAY of 50 = 500ms
.enum KISS_CMD
  DATA_FRAME  = $00
  TX_DELAY    = $01 ; keyup delay
  PERSISTENCE = $02 ; next byte is persp
  SLOT_TIME   = $03
  TX_TAIL     = $04
  DUPLEX      = $05
  RETURN      = $ff
.endenum

; these are sent shifted left by one bit
; but they are unshifted in this struct
.struct KissFrameAddr
  callsign .res 6
  ssid     .res 1
.endstruct

.struct KissFrameHeader
  cmd_type    .res 1
  dest        .tag KissFrameAddr
  source      .tag KissFrameAddr
  digipeater  .res 8 * .sizeof(KissFrameAddr)
  control     .res 1
  protocol_id .res 1
.endstruct

.endif
