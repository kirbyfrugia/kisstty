.SETCPU "6502"
.INCLUDE "atari.inc"
.INCLUDE "macros.inc"
.INCLUDE "rs232.inc"

.EXPORT rs232_open
.EXPORT rs232_close
.EXPORT rs232_status
.EXPORT rs232_getchr
.EXPORT rs232_putchr
.EXPORT rs232_last_status
.EXPORT rs232_input_buffer_size
.EXPORT rs232_output_buffer_size

.SEGMENT "CODE"
.define WRITE_BUF_LEN           512
.define CMD_TRANSLATION_PARITY  $26
.define CMD_CONTROL_LINES       $22
.define CMD_CONCURRENCY_MODE    $28
.define CMD_BAUD_STOPBITS_READY $24

; inputs:
;   x - channel
rs232_open:
  stx rs232_iocb
  lda #1         ; Device 1
  sta ICDNO,x
  lda #<dev_name ; R1
  sta ICBAL,x
  lda #>dev_name ; R1
  sta ICBAH,x
 
  lda #CLOSE
  sta ICCOM,x
  jsr CIOV

  ; set control lines
  ldx rs232_iocb
  lda #CMD_CONTROL_LINES
  sta ICCOM,x
  lda #RS232_DTR::OFF | RS232_RTS::OFF | RS232_XMT::MARK
  sta ICAX1,x
  lda #0
  sta ICAX2,x
  jsr CIOV
  bmi @error

  ; open port
  ldx rs232_iocb
  lda #OPEN
  sta ICCOM,x
  lda #$0d ; read, write, concurrent
  sta ICAX1,x
  lda #$00
  sta ICAX2,x
  jsr CIOV
  bmi @error

  ; configure settings
  ldx rs232_iocb
  lda #CMD_BAUD_STOPBITS_READY
  sta ICCOM,x
  lda #RS232_BAUD::B1200
  ora #RS232_STOPBITS::N1
  sta ICAX1,x
  lda #$00
  sta ICAX2,x
  jsr CIOV
  bmi @error

  ldx rs232_iocb
  lda #CMD_TRANSLATION_PARITY
  sta ICCOM,x
  lda #RS232_TRANSLATION::NONE | RS232_PARITY::NONE | RS232_PARITY::NONE | RS232_LINE_FEED::NO_APPEND_LF
  sta ICAX1,x
  lda #0
  sta ICAX2,x
  jsr CIOV
  bmi @error

  ; start concurrent mode
  ldx rs232_iocb
  lda #CMD_CONCURRENCY_MODE 
  sta ICCOM,x
  lda #<write_buf
  sta ICBAL,x
  lda #>write_buf
  sta ICBAH,x
  lda #<WRITE_BUF_LEN
  sta ICBLL,x
  lda #>WRITE_BUF_LEN
  sta ICBLH,x
  lda #$0c ; concurrent mode
  sta ICAX1,x
  lda #$00
  sta ICAX2,x
  jsr CIOV
  bmi @error
@opened:
  clc
  rts
@error:
  sec
  rts

rs232_status:
  ldx rs232_iocb
  lda #STATIS ; CIO status
  sta ICCOM,x
  jsr CIOV
  bmi @error
  
  lda $02ea
  sta rs232_last_status
  lda $02eb
  sta rs232_input_buffer_size
  lda $02ec
  sta rs232_input_buffer_size+1
  lda $02ed
  sta rs232_output_buffer_size
  clc
  rts
@error:
  lda $02ea
  ; TODO: do this elsewhere
  sta rs232_last_status
  sec
  rts

rs232_getchr:
  ldx rs232_iocb
  lda #GETCHR
  sta ICCOM,x
  lda #1
  sta ICBLL,x
  lda #0
  sta ICBLH,x
  jsr CIOV
  bmi @error
  clc
  rts
@error:
  sec
  rts

rs232_putchr:
  sta rs232_output_char
  ldx rs232_iocb
  lda #PUTCHR
  sta ICCOM,x
  lda rs232_output_char
  jsr CIOV
  bmi @error
  clc
  rts
@error:
  sec
  rts

rs232_close:
  ldx rs232_iocb
  lda #CLOSE
  sta ICCOM,x
  jsr CIOV
  bmi @error
@closed:
  clc
  rts
@error:
  sec
  rts

write_buf: .res WRITE_BUF_LEN
dev_name:  .byte "R1",$9b
rs232_iocb: .byte 48
sample_msg: .byte "Hello, world!",$9b
sample_msg_end:

rs232_output_char: .byte 0,$9b
rs232_last_status: .byte 0
rs232_input_buffer_size: .byte 0, 0
rs232_output_buffer_size: .byte 0
