.SETCPU "6502"

.include "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.include "common.inc"
.include "config.inc"
.include "macros.inc"
.include "main_output.inc"
.include "pctl_kiss.inc"
.include "terminal.inc"
.include "textarea.inc"

.importzp g_rx_buf_num_chars
.importzp utils_result
.import   boot850_check 
.import   boot850_bootstrap 
.import   copy_buffer40
.import   copy_buffer40_size
.import   str_to_copy_buffer40_with_fill
.import   g_rx_buf
.import   g_kbd_key_pressed
.import   g_kbdcode_raw
.import   g_kbdcode_raw_stripped
.import   g_kbdcode_atascii
.import   utils_atascii_to_icode
.import   utils_hex_table_atascii
.import   utils_hex_to_atascii
.import   utils_bin_to_bcd
.import   cfg_saved_config
.import   mi_init
.import   mi_metadata
.import   mi_data
.import   mi_repaint
.import   mi_reset
.import   mi_main_input_metadata
.import   mi_hide_cursor
.import   mi_show_cursor
.import   pk_frame_header
.import   pk_frame_info
.import   pk_new_byte
.import   pk_next_frame
.import   pk_reset
.import   pk_state
.import   rs232_open
.import   rs232_close
.import   rs232_status
.import   rs232_getchr
.import   rs232_putchr
.import   rs232_last_status
.import   rs232_input_buffer_size
.import   rs232_output_buffer_size
.export   trm_init
.export   trm_activate
.export   trm_tick

.SEGMENT "CODE"

.define RS232_CHANNEL 32 ; channel 2 (2 * 16)

.define PORT_STATUS_OK    %00000000
.define PORT_STATUS_ERROR %10000000

trm_init:
  lda #PORT_STATUS_OK
  sta port_status
  lda #TERMINAL_MODE::NONE
  sta current_mode

  jsr mo_init
  jsr mi_init
@done:
  rts

.macro draw_divider line_offset
  lda SCR_PTR_LO
  clc
  adc #<line_offset
  sta ZPB0
  lda SCR_PTR_HI
  adc #>line_offset
  sta ZPB1

  lda #$52 ; horizontal bar
  ldy #(SCREEN_WIDTH-1)
@loop:
  sta (ZPB0),y
  dey
  bpl @loop
.endmacro


; draws the line mode specific part of the ui
int_draw_ui_line_mode:
  jsr int_draw_ui_base
  draw_divider (SCREEN_WIDTH*19)
  rts

; draws the char mode specific part of the ui
int_draw_ui_char_mode:
  jsr int_draw_ui_base
  draw_divider (SCREEN_WIDTH*22)

  CURSOR_POS .set (SCREEN_WIDTH*23)+1
  lda SCR_PTR_LO
  clc
  adc #<CURSOR_POS
  sta ZPB0
  lda SCR_PTR_HI
  adc #>CURSOR_POS
  sta ZPB1
  ldy #0
  lda (ZPB0),y
  ora #%10000000
  sta (ZPB0),y
  rts

int_draw_ui_base:
  lda SCR_PTR_LO
  sta ZPB0
  lda SCR_PTR_HI
  sta ZPB1

  ldy #(SCREEN_WIDTH-1)
  lda #' '
  eor #$80
  jsr utils_atascii_to_icode
@top_bar_loop:
  sta (ZPB0),y
  dey
  bpl @top_bar_loop

  lda SCR_PTR_LO
  clc
  adc #1
  sta ZPB0
  lda SCR_PTR_HI
  adc #0
  sta ZPB1

  ldy #0
@top_banner_loop:
  lda top_banner,y
  beq @top_banner_done
  eor #$80
  jsr utils_atascii_to_icode
  sta (ZPB0),y
  iny
  jmp @top_banner_loop
@top_banner_done:
@done:
  rts

int_repaint_line_mode:
  jsr mo_repaint
  jsr mi_repaint
  jsr int_draw_ui_line_mode
  rts

int_reset_line_mode:
  jsr mo_reset
  jsr mi_reset
  jsr int_draw_ui_line_mode
  rts

int_repaint_char_mode:
  jsr mo_repaint
  jsr int_draw_ui_char_mode
  rts

int_reset_char_mode:
  jsr mo_reset
  jsr int_draw_ui_char_mode
  rts

int_reset_protocol:
  lda cfg_saved_config+Config::protocol
  cmp #TERMINAL_PROTOCOL::TERMINAL
  beq @terminal
  cmp #TERMINAL_PROTOCOL::APRS
  beq @aprs
  bne @done
@terminal:
  jmp @done
@aprs:
  jsr pk_reset
  jmp @done
@done:
  rts

int_repaint:
  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::CHAR
  beq @char_mode
  jsr int_repaint_line_mode
  jmp @done
@char_mode:
  jsr int_repaint_char_mode
@done:
  rts

int_reset:
  jsr int_reset_protocol
  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::CHAR
  beq @char_mode
  jsr int_reset_line_mode
  jmp @welcome
@char_mode:
  jsr int_reset_char_mode
@welcome:
  str_to_buf str_welcome, TERMINAL_WIDTH, ' '
  jsr int_print_str
@done:
  rts

trm_activate:
  lda #PORT_STATUS_OK
  sta port_status
  lda cfg_saved_config+Config::mode
  cmp current_mode
  sta current_mode
  beq @no_mode_change
  jsr int_reset
  jmp @boot850
@no_mode_change:
  jsr int_repaint
@boot850:
  jsr int_cmd_boot850
  jsr int_cmd_open_rs232
@done:
  rts

trm_tick:
  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::CHAR
  beq @char_mode
  jsr int_handle_kbd_line_mode
  jmp @rs232
@char_mode:
  jsr int_handle_kbd_char_mode
@rs232:
  lda port_status
  cmp #PORT_STATUS_OK
  bne @done
  jsr int_cmd_get_rs232
@done:
  rts


int_cmd_line_mode_move_cursor_up:
  jsr ta_edit_move_cursor_up
  rts

int_cmd_line_mode_move_cursor_down:
  jsr ta_edit_move_cursor_down
  rts

int_cmd_line_mode_move_cursor_left:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr ta_edit_move_cursor_left
  rts

int_cmd_line_mode_move_cursor_right:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr ta_edit_move_cursor_right
  rts

int_cmd_line_mode_handle_char:
  lda g_kbdcode_atascii
  beq @done
  jsr ta_edit_type_char
@done:
  rts

int_cmd_line_mode_backspace:
  jsr ta_edit_backspace
  rts

int_cmd_line_mode_shift_clear:
  jsr ta_shift_clear
  rts

int_cmd_line_mode_line_insert:
  jsr ta_edit_line_insert
  rts

int_cmd_line_mode_char_insert:
  jsr ta_edit_char_insert
  rts

int_cmd_line_mode_line_delete:
  jsr ta_edit_line_delete
  rts

int_cmd_line_mode_char_delete:
  jsr ta_edit_char_delete
  rts

int_cmd_line_mode_return:
  jsr ta_push_context
  lda #<mi_data
  sta CMDDATA0
  lda #>mi_data
  sta CMDDATA1
  lda mi_metadata+TextArea::size
  sta CMDDATA2
  jsr mo_append_chars
  jsr ta_pop_context
  jsr ta_shift_clear
  rts

int_handle_kbd_char_mode:
  lda g_kbd_key_pressed
  beq @done
  lda g_kbdcode_atascii
  beq @done
;  jsr int_cmd_put_rs232

;  jsr ta_push_context
;  lda #<g_kbdcode_atascii
;  sta CMDDATA0
;  lda #>g_kbdcode_atascii
;  sta CMDDATA1
;  lda #1
;  sta CMDDATA2
;  jsr mo_append_chars
;  jsr ta_pop_context

  jsr ta_push_context
  lda g_kbdcode_atascii
  sta CMDDATA0
  jsr mo_append_char
  jsr ta_pop_context
@done:
  rts


  
int_handle_kbd_line_mode:
  lda g_kbd_key_pressed
  beq @done
  lda g_kbdcode_raw 
  cmp #$8e
  beq @up_arrow
  cmp #$8f
  beq @down_arrow
  cmp #$86
  beq @left_arrow
  cmp #$87
  beq @right_arrow
  cmp #$0c
  beq @return
  cmp #$34
  beq @backspace
  cmp #$76 ; shift+clear ($b4 on atari 800 emulator)
  beq @shift_clear
  cmp #$b6 ; ctrl+clear
  beq @shift_clear
  cmp #$77 ; shift+insert on atari ($7c on atari800 emulator)
  beq @line_insert
  cmp #$b7 ; ctrl+insert
  beq @char_insert
  cmp #$74 ; shift+delete bs
  beq @line_delete
  cmp #$b4 ; ctrl+delete bs
  beq @char_delete
@output:
  jsr int_cmd_line_mode_handle_char
  jmp @done
@up_arrow:
  jmp int_cmd_line_mode_move_cursor_up
  jmp @done
@down_arrow:
  jmp int_cmd_line_mode_move_cursor_down
  jmp @done
@left_arrow:
  jmp int_cmd_line_mode_move_cursor_left
  jmp @done
@right_arrow:
  jmp int_cmd_line_mode_move_cursor_right
  jmp @done
@backspace:
  jsr int_cmd_line_mode_backspace
  jmp @done
@shift_clear:
  jsr int_cmd_line_mode_shift_clear
  jmp @done
@line_insert:
  jsr int_cmd_line_mode_line_insert
  jmp @done
@char_insert:
  jsr int_cmd_line_mode_char_insert
  jmp @done
@line_delete:
  jsr int_cmd_line_mode_line_delete
  jmp @done
@char_delete:
  jsr int_cmd_line_mode_char_delete
  jmp @done
@return:
  jsr int_cmd_line_mode_return
@done:
  rts


int_cmd_boot850:
  jsr boot850_check
  bcc @rhandler_loaded
  jsr boot850_bootstrap
  bcc @rhandler_bootstrapped
  str_to_buf str_error_loading_850, TERMINAL_WIDTH, ' '
  jsr int_print_str
  jmp @error
@rhandler_bootstrapped:
  jsr boot850_check
  bcc @rhandler_loaded
  str_to_buf str_error_missing_850, TERMINAL_WIDTH, ' '
  jsr int_print_str
  jmp @error
@rhandler_loaded:
  str_to_buf str_loaded_850, TERMINAL_WIDTH, ' '
  jsr int_print_str
  jmp @done
@error:
  lda #PORT_STATUS_ERROR 
  sta port_status
@done:
  rts

int_cmd_open_rs232:
  str_to_buf str_opening_rs232, TERMINAL_WIDTH, ' '
  jsr int_print_str
  ldx #RS232_CHANNEL
  jsr rs232_open
  bcs @error
  str_to_buf str_opened_rs232, TERMINAL_WIDTH, ' '
  jsr int_print_str
  jmp @done
@error:
  sty command_error
  sty port_status
  str_to_buf str_error_rs232_open, TERMINAL_WIDTH, ' '
  err_code_to_buf command_error,\
                  str_error_rs232_open_code-str_error_rs232_open-1
  jsr int_print_str
@done:
  rts

int_handle_byte_read:
  lda cfg_saved_config+Config::protocol
  cmp #TERMINAL_PROTOCOL::TERMINAL
  beq @terminal
  cmp #TERMINAL_PROTOCOL::APRS
  beq @aprs
  bne @done
@terminal:
  lda #<rs232_byte_read
  sta CMDDATA0
  lda #>rs232_byte_read
  sta CMDDATA1
  lda #1
  sta CMDDATA2
  jsr mo_append_chars
  jmp @done
@aprs:
  lda rs232_byte_read
  sta CMDDATA0
  jsr pk_new_byte
  lda pk_state
  and #KISS_FRAME_READY
  beq @done
@aprs_frame_ready:
  jsr int_handle_kiss_frame
  jsr pk_next_frame
@done:
  rts

; inputs:
;   A - offset in frame header to address
;   Y - offset in copy buffer to store address
; modifies:
;   addr_index_var, X, Y
int_addr_to_copy_buf:
  tax
  clc
  adc #6
  sta addr_index_var ; last char of callsign
@loop:
  lda pk_frame_header,x
  cmp #$20
  beq @loop_done
  sta copy_buffer40,y
  iny
  inx
  cpx addr_index_var
  bne @loop
@loop_done:
  lda #'-'
  sta copy_buffer40,y

  ldx addr_index_var    ; index to ssid
  lda pk_frame_header,x ; ssid
  jsr utils_bin_to_bcd

  lda utils_result
  lsr
  lsr
  lsr
  lsr
  beq @no_tens
  tax
  lda utils_hex_table_atascii,x
  iny
  sta copy_buffer40,y 
@no_tens:
  iny
  lda utils_result
  and #%00001111
  tax
  lda utils_hex_table_atascii,x
  sta copy_buffer40,y
  rts

int_handle_kiss_frame:
  ldy #0
  lda #KissFrameHeader::source
  jsr int_addr_to_copy_buf
  
  iny
  lda #'>'
  sta copy_buffer40,y

  iny
  lda #KissFrameHeader::dest
  jsr int_addr_to_copy_buf

  iny
  lda #':'
  sta copy_buffer40,y

  iny
  sty copy_buffer40_size

  lda #<copy_buffer40
  sta CMDDATA0
  lda #>copy_buffer40
  sta CMDDATA1
  lda copy_buffer40_size
  sta CMDDATA2
  jsr mo_append_chars

  lda #<g_rx_buf
  sta CMDDATA0
  lda #>g_rx_buf
  sta CMDDATA1
  lda g_rx_buf_num_chars
  sta CMDDATA2
  jsr mo_append_chars

  rts

int_cmd_get_rs232:
  jsr rs232_status
  bcs @error_status
  lda rs232_input_buffer_size+1
  bne @read
  lda rs232_input_buffer_size
  bne @read
  jmp @done
@read:
  jsr rs232_getchr
  bcc @read_success
  jmp @error_getchr
@read_success:
  sta rs232_byte_read

  jsr int_handle_byte_read

  jmp @done
@error_status:
  sty command_error
  sty port_status
  str_to_buf str_error_rs232_status, TERMINAL_WIDTH, ' '
  err_code_to_buf command_error,\
                  str_error_rs232_status_code-str_error_rs232_status-1
  jsr int_print_str
  jmp @done
@error_getchr:
  sty command_error
  sty port_status
  str_to_buf str_error_rs232_getchr, TERMINAL_WIDTH, ' '
  err_code_to_buf command_error,\
                  str_error_rs232_getchr_code-str_error_rs232_getchr-1
  jsr int_print_str
@done:
  rts


; writes a single char from kbd to rs232
int_cmd_put_rs232:
  lda port_status
  cmp #PORT_STATUS_OK
  bne @done
  lda g_kbdcode_atascii
  beq @done
  jsr rs232_putchr
  bcs @error_putchr
  jmp @done
@error_putchr:
  sty command_error
  sty port_status
  str_to_buf str_error_rs232_putchr, TERMINAL_WIDTH, ' '
  err_code_to_buf command_error,\
                  str_error_rs232_putchr_code-str_error_rs232_putchr-1
  jsr int_print_str
@done:
  rts

; TODO this is just a temp hack
int_print_str:
  rts
  jsr ta_push_context
  lda #<copy_buffer40
  sta CMDDATA0
  lda #>copy_buffer40
  sta CMDDATA1
  lda copy_buffer40_size
  sta CMDDATA2
  lda #0
  sta CMDDATA3
  jsr mo_append_chars

  jsr ta_pop_context
  rts

addr_index_var:              .byte $00
top_banner:                  .byte 'S'|$80,'E'|$80,'L'|$80,"theme "
                             .byte 'S'|$80,'T'|$80,'A'|$80,'R'|$80,'T'|$80,"config "
                             .byte $00
current_mode:                .res 1
str_welcome:                 .byte "Welcome!",$00

str_loading_850:             .byte "Loading 850...",$9b
str_loaded_850:              .byte "850 handler loaded",$9b
str_error_missing_850:       .byte "850 not in HATABS",$9b
str_error_loading_850:       .byte "850 load error",$9b
str_error:                   .byte "Error: ",$9b
str_opening_rs232:           .byte "Opening RS232 port...",$9b
str_opened_rs232:            .byte "RS232 port opened",$9b
str_error_rs232_open:        .byte "Error opening RS232 port: ",$9b
str_error_rs232_open_code:   ; used as index to print error code for above str
str_error_rs232_status:      .byte "Error on RS232 status: ",$9b
str_error_rs232_status_code: ; used as index to print error code for above str
str_error_rs232_getchr:      .byte "Error on RS232 getchr: ",$9b
str_error_rs232_getchr_code: ; used as index to print error code for above str
str_error_rs232_putchr:      .byte "Error on RS232 putchr: ",$9b
str_error_rs232_putchr_code: ; used as index to print error code for above str
command_error:               .byte 0

rs232_byte_read:             .byte 0
port_status:                 .byte 0
