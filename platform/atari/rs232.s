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

WRITE_BUF_LEN = 512
CMD_TRANSLATION_PARITY  = $26
CMD_CONTROL_LINES       = $22
CMD_CONCURRENCY_MODE    = $28
CMD_BAUD_STOPBITS_READY = $24


.SEGMENT "CODE"

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

  ; configure settings
  ldx rs232_iocb
  lda #$24
  sta ICCOM,x
  lda #RS232_BAUD::B1200
  ora #RS232_STOPBITS::N1
  sta ICAX1,x
  lda #0
  sta ICAX2,x
  jsr CIOV
  bmi @error

  ; open port
  ldx rs232_iocb
  lda #OPEN
  sta ICCOM,x
  lda #13        ; concurrent read and write
  sta ICAX1,x
  jsr CIOV
  bmi @error

  ; start concurrent mode
  ldx rs232_iocb
  lda #$28 
  sta ICCOM,x
  lda #<write_buf
  sta ICBAL,x
  lda #>write_buf
  sta ICBAH,x
  lda #<WRITE_BUF_LEN
  sta ICBLL,x
  lda #<WRITE_BUF_LEN
  sta ICBLH,x
  jsr CIOV
  bmi @error
@opened:
  clc
  rts
@error:
  sec
  rts

; OK, see page 43 in the 850 operator manual.
;STATUS returns the number of chars in the input buffer in locations
;747 and 748 and the number in the output buffer in 749.
rs232_status:
  ldx rs232_iocb
  lda #STATUS
  sta ICCOM,x
  lda #0
  sta ICAX1,x
  lda #0
  sta ICAX2,x
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
  ; TODO: I think we're lucky this stores the value
  ;       in the accumulator. Grab somewhere better.
  lda #GETCHR
  sta ICCOM,x
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
  lda #<rs232_output_char
  sta ICBAL,x
  lda #>rs232_output_char
  sta ICBAH,x
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




;rs232_write:
;  ldx rs232_iocb
;  lda #PUTREC
;  ;lda #$57 ; 'W' write
;  sta ICCOM,x
;  lda #<sample_msg
;  sta ICBAL,x
;  lda #>sample_msg
;  sta ICBAH,x
;  lda #<(sample_msg_end-sample_msg)
;  sta ICBLL,x
;  lda #>(sample_msg_end-sample_msg)
;  sta ICBLH,x
;  jsr CIOV
;  bmi @error
;  clc
;  rts
;@error:
;  sec
;  rts


; inputs:
;   x - channel
rs232_close:
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

rs232_output_char: .byte 0
rs232_last_status: .byte 0
rs232_input_buffer_size: .byte 0, 0
rs232_output_buffer_size: .byte 0
