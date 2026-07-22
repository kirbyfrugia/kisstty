.setcpu "6502"
.include "protocol_kiss.inc"
.include "atari.inc"
.include "globals.inc"
.include "macros.inc"
.include "rs232.inc"
.include "utils.inc"

.segment "ZEROPAGE"
buf_counter:  .res 1
addr_counter: .res 1
crc_lo:       .res 1
crc_hi:       .res 1

.segment "CODE"

pk_reset:
  lda #KISS_STATE_NEW
  sta pk_state
  jsr pk_next_frame
  rts

; writes N chars from the given buffer over rs232 as
; a kiss message type with the option of trimming the end
; off the data. i.e. sending until last non-space char.
;
; inputs:
;   CMDDATA0/1 - ptr to the data
;   CMDDATA2/3 - ptr to the addressee
;   CMDDATA4   - size of buf
;   CMDDATA5   - trim flag, set RS232_PUTBUF_TRIM to trim
pk_send_message:
  data_ptr_lo = CMDDATA0
  addressee_ptr_lo = CMDDATA2
  buf_size = CMDDATA4
  trim = CMDDATA5

  lda trim
  bit KISS_SEND_FLAG_TRIM_END
  bmi @trim
  lda buf_size
  beq @data_empty; was empty string
  sta ut_result
  bne @ready
@data_empty:
  jmp @done
@trim:
  lda CMDDATA2
  pha
  lda buf_size
  sta CMDDATA2 
  jsr ut_str_trim_end_find
  pla
  sta CMDDATA2
  lda ut_result
  beq @all_spaces; was an empty string
  bne @ready
@all_spaces:
  jmp @done
@ready:
  lda #KISS_FEND
  jsr rs232_putchr
  bcs @error

  lda #KISS_CMD::DATA_FRAME
  jsr rs232_putchr
  bcs @error

  ; TODO: don't hard-code the header
  ldy #0
@dest:
  sty tempy
  lda hardcoded_dest,y
  jsr rs232_putchr
  bcs @error
  ldy tempy
  iny
  cpy #7
  bne @dest 

  ldy #0
@src:
  sty tempy
  lda hardcoded_src,y
  jsr rs232_putchr
  bcs @error
  ldy tempy
  iny
  cpy #7
  bne @src

  lda #$03 ; ui frame
  jsr rs232_putchr
  bcs @error

  lda #$f0 ; PID, no layer 3
  jsr rs232_putchr
  bcs @error

  lda #':'
  jsr rs232_putchr
  bcs @error

  ldy #0
@addressee:
  sty tempy
  lda pk_broadcast_addressee,y
  jsr rs232_putchr
  bcs @error
  ldy tempy
  iny
  cpy #9
  bne @addressee
 
  lda #':'
  jsr rs232_putchr
  bcs @error

  lda CMDDATA2
  pha
  lda ut_result
  sta CMDDATA2
  jsr rs232_putchrs
  pla
  sta CMDDATA2
  bcs @error

  lda #KISS_FEND
  jsr rs232_putchr
  bcs @error
@done:
  clc
  rts
@error:
  ldy rs232_last_status
  sty pk_error
  sec
  rts

pk_next_frame:
  lda #0
  sta buf_counter
  sta addr_counter
  sta btwn_counter
  sta g_disp_buf_num_lines
  sta pk_frame_header+Ax25FrameHeader::num_digi
  sta crc_lo
  sta crc_hi

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
  sta CMDDATA0
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
  sta pk_frame_header+Ax25FrameHeader::cmd_type
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
  cpy #Ax25FrameHeader::digipeater
  bcc @not_digi ; not yet to digipeater section
  inc pk_frame_header+Ax25FrameHeader::num_digi
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
  lda CMDDATA0
  ldy btwn_counter
  cpy #1
  beq @last_btwn
  sta pk_frame_header+Ax25FrameHeader::control
  inc btwn_counter
  jmp @done
@last_btwn:
  sta pk_frame_header+Ax25FrameHeader::protocol_id
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
  sta g_temp_data_ptr_lo
  lda #>g_disp_buf
  sta g_temp_data_ptr_hi

  inc buf_counter
  lda g_rx_buf+0
  cmp #':'
  beq pkpf_message
  cmp #'>'
  beq pkpf_status
  bne pkpf_done
pkpf_message:
  jsr int_process_message
  jmp pkpf_done
pkpf_status:
  jsr int_process_status
pkpf_done:
  rts

int_fend:
  lda pk_state
  and #KISS_STATE_INFO
  beq @reset ; frame ended before the info field
  lda buf_counter
  beq @reset ; no data, was an empty frame
  sta g_rx_buf_num_chars

  ; indicate a frame is ready for handling
  lda pk_state
  ora #KISS_FRAME_READY
  sta pk_state
  jmp @done
@reset:
  jsr pk_next_frame
@done:
  rts

;; checks if the processed frame is an ack message and
;; handles it if so (i.e. preps frame for display)
;; outputs:
;;   C - set if it was an ack, clear if not
;; modifies:
;;   A,X,Y
;int_maybe_handle_received_ack:
;  ; todo: make sure the message was actually for us,
;  ;       otherwise ignore it
;  ; todo: read the message until we see if it
;  ;       is an ack or not. Store as we go just in case.
;  ; todo: print ack if it's one we care about
;  ;       keep a string where we just replace the callsign
;  lda g_rx_buf_num_chars
;  cmp #KISS_TYPE_MSG_ACK_MIN_LEN
;  bcc @not_ack
;  cmp #(KISS_TYPE_MSG_ACK_MAX_LEN+1)
;  bcs @not_ack
;
;  ldy #KISS_TYPE_MSG_ACK_IDX
;  lda g_rx_buf,y
;  cmp #'a'
;  beq @test_c
;  cmp #'A'
;  beq @test_c
;  bne @not_ack
;@test_c:
;  iny
;  lda g_rx_buf,y
;  cmp  #'c'
;  beq @test_k
;  cmp #'C'
;  beq @test_k
;  bne @not_ack
;@test_k:
;  iny
;  lda g_rx_buf,y
;  cmp #'k'
;  beq @is_ack
;  cmp #'K'
;  beq @is_ack
;  bne @not_ack
;@is_ack:
;  lda #<g_disp_buf
;  sta g_temp_data_ptr_lo
;  lda #>g_disp_buf
;  sta g_temp_data_ptr_hi
;
;  ldx #6
;  iny
;@id_loop:
;  lda g_rx_buf,y
;  sta g_disp_buf,x
;  inx
;  iny
;  cpy g_rx_buf_num_chars
;  bne @id_loop
;  lda #' '
;@remainder_loop:
;  cpy #KISS_TYPE_MSG_ACK_MAX_LEN
;  beq @id_loop_done
;  sta g_disp_buf,x
;  inx
;  iny
;  bne @remainder_loop
;@id_loop_done:
;  sty y_index_var
;  sec
;  rts
;@not_ack:
;  clc
;  rts

int_calc_crc:
  ; todo: add in the message source, too.
  ; todo: this is just a simple check for dev.
  ;       calculate an actual crc instead of just summing the bytes
  lda #0
  sta crc_lo
  sta crc_hi
  ldy #KISS_TYPE_MSG_ADDRESSEE
@loop:
  lda g_rx_buf,y
  clc
  adc crc_lo
  sta crc_lo
  bcc @nowrap
  inc crc_hi
@nowrap:
  iny
  cpy g_rx_buf_num_chars
  bne @loop
@done:
  rts


; checks if the received frame is a repeat
; outputs:
;   C - set if ack, clear if not
int_is_repeat:
  ; todo: need some way to expire frames after 30 seconds
  jsr int_calc_crc
  clc
  rts

int_process_message:
  lda g_rx_buf_num_chars
  cmp #KISS_TYPE_MSG_END_COLON_IDX
  bcc @done ; not a valid message

;  jsr int_maybe_handle_received_ack
;  bcc @not_ack
;  jsr @done
;@not_ack:
  lda #<g_disp_buf
  sta g_temp_data_ptr_lo
  lda #>g_disp_buf
  sta g_temp_data_ptr_hi

  jsr int_is_repeat
  bcc @not_repeat
  jmp @done
@not_repeat:

  ldy #0
  ldx #Ax25FrameHeader::source
  stx x_index_var
  jsr int_addr_to_buf

  lda #'>'
  sta g_disp_buf,y

  iny

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
  sty y_index_var

;  jsr is_repeat
;  bcc @not_repeat
;  jmp @done
;@not_repeat:
  jsr int_finalize_disp
@done:
  rts

int_process_status:
  lda #<g_disp_buf
  sta g_temp_data_ptr_lo
  lda #>g_disp_buf
  sta g_temp_data_ptr_hi

  ldy #0
  lda #'['
  sta g_disp_buf,y

  iny
  ldx #Ax25FrameHeader::source
  stx x_index_var
  jsr int_addr_to_buf

  lda #']'
  sta g_disp_buf,y

  iny

  ; empty statuses are allowed, but we don't
  ; want to try parsing the string
  lda g_rx_buf_num_chars
  cmp #2 ; first char is '>' no matter what
  bcs @not_empty
  jmp @finalize
@not_empty:
  lda #' '
  sta g_disp_buf,y

  lda g_rx_buf_num_chars
  cmp #KISS_TYPE_STATUS_TIMESTAMP_ZULU_IDX
  bcc @nozulu
  ldx #KISS_TYPE_STATUS_TIMESTAMP_ZULU_IDX
  lda g_rx_buf,x
  cmp #'z'
  beq @zulu
  cmp #'Z'
  beq @zulu
  ldx #1
  bne @nozulu
@zulu:
  ; might be a timestamp, confirm
  ldx #1
  stx x_index_var
  ldx #KISS_TYPE_STATUS_TIMESTAMP_ZULU_IDX
  stx x_index_var_end
  jsr int_all_digits
  bcc @nozulu

  lda #' '
  sta g_disp_buf,y

  ; it's a timestamp. Convert from DDHHmm to HH:mm
  ldx #3
  iny
  lda g_rx_buf,x
  sta g_disp_buf,y
  iny
  inx
  lda g_rx_buf,x
  sta g_disp_buf,y
  iny
  lda #':'
  sta g_disp_buf,y
  iny
  inx
  lda g_rx_buf,x
  sta g_disp_buf,y
  iny
  inx
  lda g_rx_buf,x
  sta g_disp_buf,y
  iny
  lda #' '
  sta g_disp_buf,y
  inx
  inx
@nozulu:
  iny
  stx x_index_var
  lda g_rx_buf_num_chars
  sta x_index_var_end
  jsr int_read_until_end
@finalize:
  sty y_index_var
  jsr int_finalize_disp
@done:
  rts

; finalizes the output once all the real data
; has been added to the display buffer.
;
; Does the following:
;   - sets line count
;   - fills blank spaces to the end of the last line
;
; inputs
;   y_index_var - one past last character already printed
; modifies:
;   a,y
int_finalize_disp:
  lda y_index_var
  beq @done
@mod_loop:
  inc g_disp_buf_num_lines
  lda y_index_var
  sec
  sbc #TERMINAL_WIDTH
  beq @mod_loop_done ; exactly at zero, on last line
  bcc @mod_loop_done ; needed to borrow, on last line
  ; not on last line yet
  sta y_index_var ; remaining
  lda g_temp_data_ptr_lo
  clc
  adc #TERMINAL_WIDTH
  sta g_temp_data_ptr_lo
  bcc @nowrap
  inc g_temp_data_ptr_hi
@nowrap:
  jmp @mod_loop
@mod_loop_done:
  lda #' '
  ldy y_index_var
@fill_loop:
  cpy #TERMINAL_WIDTH
  beq @done
  sta (g_temp_data_ptr_lo),y
  iny
  jmp @fill_loop
@done:
  rts

; reads from x_index_var to x_index_var_end
; and sets the carry bit if it's all digits,
; otherwise it clears the carry bit
; inputs:
;   x_index_var        - start index to check
;   x_index_var_end    - end index to check (one past)
; outputs:
;   C - sec if all digits, clc otherwise
int_all_digits:
  ldx x_index_var
@loop:
  lda g_rx_buf,x
  cmp $30 ; ascii 0
  bcc @nozulu
  cmp $39 ; ascii 9 + 1
  bcs @nozulu
  inx
  cpx x_index_var_end
  bne @loop
  sec
  rts
@nozulu:
  clc
  rts

; reads from rx_buf from x_index_var to x_index_var_end
; or the given terminator char appears
;
; assumes x_index_var_end - x_index_var > 1
;
; inputs:
;   terminator            - char to search for or $00 until
;   g_temp_data_ptr_lo/hi - pointer to where to store output
;   x_index_var           - start index to check
;   x_index_var_end       - end index to check (one past)
;   y                     - start index to write to
; outputs:
;   x - index of last read char + 1
;   y - index of last written char + 1
int_read_until_terminator:
  ldx x_index_var
@loop:
  lda g_rx_buf,x
  cmp terminator
  beq @done
  sta (g_temp_data_ptr_lo),y
  iny
  inx
  cpx x_index_var_end
  bne @loop
@done:
  rts

; reads from rx_buf from x_index_var to x_index_var_end
;
; assumes x_index_var_end - x_index_var > 1
;
; inputs:
;   g_temp_data_ptr_lo/hi - pointer to where to store output
;   x_index_var           - start index to check
;   x_index_var_end       - end index to check (one past)
;   y                     - start index to write to
; outputs:
;   x - index of last read char + 1
;   y - index of last written char + 1
int_read_until_end:
  ldx x_index_var
@loop:
  lda g_rx_buf,x
  sta (g_temp_data_ptr_lo),y
  iny
  inx
  cpx x_index_var_end
  bne @loop
@done:
  rts


int_ack_message:
  rts

; inputs:
;   g_temp_data_ptr_lo/hi - address of line
;   x_index_var        - offset in Ax25FrameHeader to start of address
;   y                  - offset in disp buffer to store address
; modifies:
;   x_index_var        - will be one past end of this address
;   a,x,y
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
  sta (g_temp_data_ptr_lo),y
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
  sta (g_temp_data_ptr_lo),y
  lda ut_result
  lsr
  lsr
  lsr
  lsr
  beq @no_tens
  tax
  lda ut_hex_table_atascii,x
  iny
  sta (g_temp_data_ptr_lo),y 
@no_tens:
  iny
  lda ut_result
  and #%00001111
  tax
  lda ut_hex_table_atascii,x
  sta (g_temp_data_ptr_lo),y
  iny
@done:
  ; update our x to one past end of this address
  inc x_index_var
  rts

zulu:            .res 1
terminator:      .res 1
x_index_var:     .res 1
x_index_var_end: .res 1
y_index_var:     .res 1
btwn_counter:    .res 1
tempy:           .res 1

; TODO: remove this instead of hardcoding
hardcoded_dest: ; APZ001 
  .byte $82,$A0,$B4,$60,$60,$62,$E0
hardcoded_src:  ; NOCALL
  .byte $9C,$9E,$86,$82,$98,$98,$61

pk_state:        .res 1
pk_frame_header: .tag Ax25FrameHeader
pk_error:        .res 1
pk_broadcast_addressee: .byte "BROADCAST"

; CRCs for incoming frames
seen_frames_lo: .res KISS_MAX_SEEN_FRAMES
seen_frames_hi: .res KISS_MAX_SEEN_FRAMES
