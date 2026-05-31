.ifndef RS232_INC
RS232_INC = 1

; enums for configuring rs232

.enum RS232_BAUD
  B300    = %00000000
  B45_5   = %00000001
  B50     = %00000010
  B56_875 = %00000011
  B75     = %00000100
  B110    = %00000101
  B134_5  = %00000110
  B150    = %00000111
  B300X   = %00001000 ; same as zero
  B600    = %00001001
  B1200   = %00001010
  B1800   = %00001011
  B2400   = %00001100
  B4800   = %00001101
  B9600   = %00001110
  B19200  = %00001111 ; not supported by straight 850
.endenum


.enum RS232_WORDSIZE
  N5 = %00000000
  N6 = %00010000
  N7 = %00100000
  N8 = %00110000
.endenum

.enum RS232_STOPBITS
  N1 = %00000000
  N2 = %10000000
.endenum

.enum RS232_FLOWCONTROL
  DSR = %00000100
  CTS = %00000010
  CRX = %00000001
.endenum

.enum RS232_TRANSLATION
  LIGHT = %00000000
  HEAVY = %00010000
  NONE  = %00100000
.endenum

.enum RS232_PARITY
  NONE  = %00000000
  EVEN  = %00001000
  ODD   = %00000100
.endenum

.enum RS232_LINE_FEED
  NO_APPEND_LF = %00000000
  APPEND_LF    = %01000000
.endenum

.enum RS232_DSR
  OFF = %00000000
  ON  = %00000100
.endenum

.enum RS232_CTS
  OFF = %00000000
  ON  = %00000010
.endenum

.enum RS232_CRX
  OFF = %00000000
  ON  = %00000001
.endenum

.enum RS232_DTR
  NO_CHANGE = %00000000
  OFF       = %10000000
  ON        = %11000000
.endenum

.enum RS232_RTS
  NO_CHANGE = %00000000
  OFF       = %00100000
  ON        = %00110000
.endenum

.enum RS232_XMT
  NO_CHANGE = %00000000
  SPACE     = %00000010
  MARK      = %00000011
.endenum

.enum RS232_DUPLEX
  FULL = %10000000
  HALF = %00000000
.endenum

.endif
