.ifndef TERMINAL_INC
.define TERMINAL_INC 1
.SEGMENT "CODE"

.define TERMINAL_WIDTH 38


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

.macro err_code_to_buf error_code, offset
  lda #<copy_buffer40
  sta CMDDATA0
  lda #>copy_buffer40
  sta CMDDATA1
  ldy #offset
  lda error_code
  jsr utils_hex_to_atascii
.endmacro

.macro str_to_buf str_addr, fill_size, backfill_char
  lda #<str_addr
  sta CMDDATA0
  lda #>str_addr
  sta CMDDATA1
  lda #fill_size
  sta CMDDATA2
  lda #backfill_char
  sta CMDDATA3
  jsr str_to_copy_buffer40_with_fill

  lda copy_buffer40_size
  sta CMDDATA2
  lda #<copy_buffer40
  sta CMDDATA0
  lda #>copy_buffer40
  sta CMDDATA1

.endmacro


.endif

