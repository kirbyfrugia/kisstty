.setcpu "6502"
.include "atari.inc"
.include "globals.inc"
.include "macros.inc"
.include "pctl_kiss.inc"

.segment "ZEROPAGE"
buf_counter:  .res 1
addr_counter: .res 1

.segment "CODE"

pk_reset:
  lda #KISS_STATE_NEW
  sta pk_state
  jsr pk_next_frame
  rts

; Note: assumes we never have a frame with data > 256 bytes
int_process_byte:
  lda pk_state
  and #KISS_STATE_INFO
  beq @chk_in_addr ; dumb cause branch too far
  jmp @in_info
@chk_in_addr:
  lda pk_state
  and #KISS_STATE_ADDR
  beq @chk_in_btwn ; dumb cause branch too far
  jmp @in_addr
@chk_in_btwn:
  lda pk_state
  and #KISS_STATE_BTWN
  beq @in_first_byte
  jmp @in_btwn
@in_first_byte:
  ; just the type field, first byte
  lda CMDDATA0
  sta pk_frame_header+KissFrameHeader::cmd_type
  lda pk_state
  ora #KISS_STATE_ADDR
  sta pk_state
  ldy #1
  sty buf_counter
  jmp @done
@in_addr:
  ldy buf_counter
  lda addr_counter
  cmp #6
  beq @ssid ; last byte has ssid and extension bit
  ; address bytes are all shifted left by one bit
  lda CMDDATA0
  lsr
  sta pk_frame_header,y 
  inc addr_counter
  jmp @in_addr_done
@ssid:
  lda CMDDATA0
  lsr            ; address extension bit -> carry
  and #%00001111 ; ssid
  sta pk_frame_header,y
  bcs @last_addr
  lda #0
  sta addr_counter
@in_addr_done:
  iny
  sty buf_counter
  jmp @done
@last_addr:
  iny
  sty buf_counter
  lda pk_state
  eor #KISS_STATE_ADDR
  ora #KISS_STATE_BTWN
  sta pk_state
  jmp @done
@in_btwn:
  ldy buf_counter
  lda CMDDATA0
  sta pk_frame_header,y
  iny
  sty buf_counter
  ldy btwn_counter
  cpy #1
  beq @last_btwn
  inc btwn_counter
  jmp @done
@last_btwn:
  lda pk_state
  eor #KISS_STATE_BTWN
  ora #KISS_STATE_INFO
  sta pk_state
  ldy #0
  sty buf_counter
  jmp @done
@in_info:
  ldy buf_counter
  lda CMDDATA0
  sta g_rx_buf,y
  iny ; assumes <256 bytes
  sty buf_counter
@done:
  rts

pk_next_frame:
  lda #0
  sta buf_counter
  sta addr_counter
  sta btwn_counter

  lda pk_state
  and #%10000000  ; leave FEND alone, clear rest
  sta pk_state

  rts

int_parse_position_no_ts:
  rts

int_parse_position_ts:
  rts

int_process_frame:
  lda buf_counter
  beq @done ; no data, was an empty frame
  sta g_rx_buf_num_chars

;  lda pk_frame_info+KissFrameInfo::dti
;  cmp #'!'
;  beq position_no_ts
;  cmp #'='
;  beq position_no_ts
;  cmp #'/'
;  beq position_ts
;  cmp #'@'
;  beq position_ts
;position_no_ts:
;  jmp parse_position_no_ts
;  jmp @done
;position_ts:
;  jmp parse_position_ts
;  jmp @done

  ; indicate a frame is ready for handling
  lda pk_state
  ora #KISS_FRAME_READY
  sta pk_state
@done:
  rts

; inputs:
;   CMDDATA0 - byte received
pk_new_byte:
  lda #KISS_STATE_NEW
  bit pk_state
  bpl @parse
  ; if here, still waiting on very first FEND
  lda CMDDATA0
  cmp #KISS_FEND
  bne @done
  lda pk_state
  eor #KISS_STATE_NEW
  sta pk_state
  jmp @done
@parse:
  lda pk_state
  and #KISS_STATE_FESC
  bne @in_fesc
  ; if here, not in escape mode
  lda CMDDATA0
  cmp #KISS_FESC
  beq @fesc
  cmp #KISS_FEND
  beq @fend
  bne @data
@fesc:
  ; enter escape mode
  lda pk_state
  ora #KISS_STATE_FESC
  sta pk_state
  jmp @done
@fend:
  ; if here, end of frame
  jsr int_process_frame
  jmp @done
@in_fesc:
  ; exit escape mode
  lda pk_state
  eor #KISS_STATE_FESC
  sta pk_state
  lda CMDDATA0
  cmp #KISS_TFESC
  beq @in_fesc_tfesc
  cmp #KISS_TFEND
  beq @in_fesc_tfend
  bne @done ; invalid, drop the byte
@in_fesc_tfesc:
  lda #KISS_FESC
  bne @data
@in_fesc_tfend:
  lda #KISS_FEND
@data:
  jsr int_process_byte
@done:
  rts

btwn_counter:    .res 1
pk_state:        .res 1
pk_frame_header: .tag KissFrameHeader
