.ifndef TERMINAL_INC
TERMINAL_INC = 1

.global trm_init
.global trm_activate
.global trm_tick

TERMINAL_WIDTH = 38

.enum TERMINAL_MODE
  CHAR = %10000000
  LINE = %01000000
  NONE = %00000000
.endenum

.enum TERMINAL_PROTOCOL
  TERMINAL = %10000000
  APRS     = %01000000
  RTTY     = %00100000
.endenum

.macro print_str str
  lda #<str
  sta CMDDATA0
  lda #>str
  sta CMDDATA1

  jsr mo_println
.endmacro

.macro print_str_with_code str, buf, err_code
  lda #<str
  sta CMDDATA0
  lda #>str
  sta CMDDATA1

  lda #<buf
  sta CMDDATA2
  lda #>buf
  sta CMDDATA3

  lda err_code
  sta CMDDATA4
  jsr ut_str_with_code_to_buf

  lda #<buf
  sta CMDDATA0
  lda #>buf
  sta CMDDATA1
  jsr mo_println
.endmacro

.endif

