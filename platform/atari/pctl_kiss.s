.setcpu "6502"
.include "atari.inc"
.include "globals.inc"
.include "macros.inc"
.include "pctl_kiss.inc"
.include "utils.inc"

.segment "ZEROPAGE"
buf_counter:     .res 1
addr_counter:    .res 1
data_ptr_lo: .res 1
data_ptr_hi: .res 1

.segment "CODE"

pk_reset:
  lda #KISS_STATE_NEW
  sta pk_state
  jsr pk_next_frame
  rts

pk_next_frame:
  lda #0
  sta buf_counter
  sta addr_counter
  sta btwn_counter
  sta g_disp_buf_num_lines
  sta pk_frame_header+KissFrameHeader::num_digi

  lda pk_state
  and #%10000000  ; leave FEND alone, clear rest
  sta pk_state
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
  jsr int_fend
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
  cpy #KissFrameHeader::digipeater
  bcc @not_digi ; not yet to digipeater section
  inc pk_frame_header+KissFrameHeader::num_digi
@not_digi:
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

pk_process_frame:
  lda #<g_disp_buf
  sta data_ptr_lo
  lda #>g_disp_buf
  sta data_ptr_hi

  ;jsr int_process_addresses

  inc buf_counter
  lda g_rx_buf+0
  cmp #':'
  beq pkpf_message
  bne pkpf_done
;  cmp #'!'
;  beq pkpf_position_no_ts
;  cmp #'='
;  beq pkpf_position_no_ts
;  cmp #'/'
;  beq pkpf_position_ts
;  cmp #'@'
;  beq pkpf_position_ts
;pkpf_position_no_ts:
;  jmp int_process_position_no_ts
;  jmp pkpf_done
;pkpf_position_ts:
;  jmp int_process_position_ts
;  jmp pkpf_done
pkpf_message:
  jmp int_process_message
pkpf_done:
  rts

int_fend:
  lda buf_counter
  beq @done ; no data, was an empty frame
  sta g_rx_buf_num_chars

  ; indicate a frame is ready for handling
  lda pk_state
  ora #KISS_FRAME_READY
  sta pk_state
@done:
  rts

; inputs:
;   
int_process_msg:
  ldy #0
  ldx #KissFrameHeader::source
  stx x_index_var
  jsr int_addr_to_buf


  lda #<g_disp_buf
  sta data_ptr_lo
  lda #>g_disp_buf
  sta data_ptr_hi
  lda #KISS_TYPE_MSG_ADDRESSEE_IDX
  sta x_index_var
  lda #KISS_TYPE_MSG_END_COLON_IDX
  sta x_index_var_end
  lda #' '
  sta terminator
  jsr int_read_until_terminator

  lda #KISS_TYPE_MSG_END_COLON_IDX
  sta x_index_var
  lda g_rx_buf_num_chars
  sta x_index_var_end
  lda #'{'
  sta terminator
  jsr int_read_until_terminator

  rts

int_process_status:
  rts

; reads from rx_buf from x_index_var to x_index_var_end
; or the given terminator char appears
;
; assumes x_index_var_end - x_index_var > 1
;
; inputs:
;   terminator         - char to search for or $00 until
;   data_ptr_lo/hi - pointer to where to store output
;   x_index_var        - start index to check
;   x_index_var_end    - end index to check (one past)
;   y                  - start index to write to
; outputs:
;   x - index of last read char + 1
;   y - index of last written char + 1
int_read_until_terminator:
  ldx x_index_var
@loop:
  lda g_rx_buf,x
  cmp terminator
  beq @done
  sta (data_ptr_lo),y
  iny
  inx
  cpx x_index_var_end
  bne @loop
@done:
  rts

int_process_message:
  lda g_rx_buf_num_chars
  cmp #KISS_TYPE_MSG_END_COLON_IDX
  bcc ipm_done ; not a valid message

  ldy #0
  ldx #KissFrameHeader::source
  stx x_index_var
  jsr int_addr_to_buf

  ; TODO: update the parse addr method to
  ;       work with addresses that aren't
  ;       just in the kiss frame header.
  ;       Or maybe add to the header and rename?
  ;       e.g. add it after num_digi and rename to
  ;       KissFrameMetadata
  ;       Actually the above won't work because
  ;       this is a raw string, not a shifted char thing.

  ; y is already set by now from the addr parser
  lda #1
  sta g_disp_buf_num_lines
  ldx #0
@addressee_loop:
  lda g_rx_buf,x
  cmp #' '
  beq @addressee_colon_loop ; found first space, find next colon
  sta (data_ptr_lo),y
  iny
  inx
  cpx #KISS_TYPE_MSG_END_COLON_IDX
  bne @addressee_loop
  beq @loop ; no blank chars in addressee, parse actual msg
@addressee_colon_loop:
  ; get here if there were spaces in the addressee, proceed
  ; until we find the colon
  lda g_rx_buf,x
  cmp #':'
  beq @loop ; parse actual msg
  ;iny ; don't increment y since we're ignoring spaces
  inx
  cpx #KISS_TYPE_MSG_END_COLON_IDX
  bne @addressee_colon_loop
@loop:
  lda g_rx_buf,x
  ;cmp #'{'
  ;beq @msg_id
  sta (data_ptr_lo),y
  cpy #0
  bne @no_inc
  ; if on first char of a line, we inc number of lines
  inc g_disp_buf_num_lines
@no_inc:
  inx
  beq ipm_done; >255, too many chars
  cpx g_rx_buf_num_chars
  beq @fill
  iny
  cpy #TERMINAL_WIDTH
  bne @loop
  lda data_ptr_lo
  clc
  adc #TERMINAL_WIDTH
  sta data_ptr_lo
  bcc @nowrap_buf_ptr
  inc data_ptr_hi
@nowrap_buf_ptr:
  ldy #0
  beq @loop
@msg_id:
  ; here's where we will ack the message,
  ; but for now, just stop printing
  ;iny
  ;beq @calc_lines ; rolled over
  ;lda g_rx_buf,y
  ; TODO: handle ack'
  ; jsr int_ack_message
@fill:
  iny
  lda #' '
  ut_fill_to_end_ptr data_ptr_lo, #TERMINAL_WIDTH
ipm_done:
  rts

int_ack_message:
  rts

; may use later, not used now
int_process_addresses:
  ldx #0
  lda g_disp_buf_line_ptrs_lo,x
  sta data_ptr_lo
  lda g_disp_buf_line_ptrs_hi,x
  sta data_ptr_hi

  ldy #0
  ldx #KissFrameHeader::source
  stx x_index_var
  jsr int_addr_to_buf

  lda #'>'
  sta (data_ptr_lo),y

  iny
  ldx #KissFrameHeader::dest
  stx x_index_var
  jsr int_addr_to_buf

  lda #1
  sta g_disp_buf_num_lines

  lda pk_frame_header+KissFrameHeader::num_digi
  bne ipa_digi

  lda #'x'
  ut_fill_to_end_ptr data_ptr_lo, #TERMINAL_WIDTH
  jmp ipa_done
ipa_digi:
  lda #'v'
  sta (data_ptr_lo),y
  ldx #KissFrameHeader::digipeater
  stx x_index_var
  ldx #0 
ipa_loop:
  stx current_digi
  ldx x_index_var
  iny
  jsr int_addr_to_buf
  ldx current_digi
  inx
  cpx pk_frame_header+KissFrameHeader::num_digi
  beq ipa_done
  lda #','
  iny
  sta (data_ptr_lo),y
  jmp ipa_loop
  
  ; TODO
ipa_done:
  rts

; inputs:
;   data_ptr_lo/hi - address of line
;   x_index_var        - offset in KissFrameHeader to start of address
;   y                  - offset in disp buffer to store address
; modifies:
;   x_index_var        - will be one past end of this address
;   a,x,y              - can't count on these
int_addr_to_buf:
  lda x_index_var
  tax
  clc
  adc #6
  sta x_index_var ; offset to ssid
@loop:
  lda pk_frame_header,x
  cmp #$20
  beq @loop_done
  sta (data_ptr_lo),y
  iny
  inx
  cpx x_index_var
  bne @loop
@loop_done:
  ldx x_index_var       ; index to ssid
  lda pk_frame_header,x ; ssid
  beq @done             ; ssid of zero
  jsr ut_bin_to_bcd

  lda #'-'
  sta (data_ptr_lo),y
  lda ut_result
  lsr
  lsr
  lsr
  lsr
  beq @no_tens
  tax
  lda ut_hex_table_atascii,x
  iny
  sta (data_ptr_lo),y 
@no_tens:
  iny
  lda ut_result
  and #%00001111
  tax
  lda ut_hex_table_atascii,x
  sta (data_ptr_lo),y
@done:
  ; update our x to one past end of this address
  inc x_index_var
  rts

terminator:      .res 1
current_digi:    .res 1
x_index_var:     .res 1
x_index_var_end: .res 1
btwn_counter:    .res 1
pk_state:        .res 1
pk_frame_header: .tag KissFrameHeader
