.setcpu "6502"

.include "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.include "boot850.inc"
.include "config.inc"
.include "globals.inc"
.include "macros.inc"
.include "main.inc"
.include "main_input.inc"
.include "main_output.inc"
.include "pctl_kiss.inc"
.include "rs232.inc"
.include "terminal.inc"
.include "textarea.inc"
.include "utils.inc"

.segment "CODE"

RS232_CHANNEL     = 32 ; channel 2 (2 * 16)

PORT_STATUS_OK    = %00000000
PORT_STATUS_ERROR = %10000000

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
  jsr ut_atascii_to_icode
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
  jsr ut_atascii_to_icode
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
  lda #MO_LINE_HEIGHT
  jsr mo_resize
  jsr mi_reset
  jsr int_draw_ui_line_mode
  rts

int_repaint_char_mode:
  jsr mo_repaint
  jsr int_draw_ui_char_mode
  rts

int_reset_char_mode:
  lda #MO_CHAR_HEIGHT
  jsr mo_resize
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
  jsr cls
  jsr int_reset_protocol
  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::CHAR
  beq @char_mode
  jsr int_reset_line_mode
  jmp @welcome
@char_mode:
  jsr int_reset_char_mode
@welcome:
  print_str str_welcome
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
  jsr mi_edit_move_cursor_up
  rts

int_cmd_line_mode_move_cursor_down:
  jsr mi_edit_move_cursor_down
  rts

int_cmd_line_mode_move_cursor_left:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr mi_edit_move_cursor_left
  rts

int_cmd_line_mode_move_cursor_right:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr mi_edit_move_cursor_right
  rts

int_cmd_line_mode_handle_char:
  lda g_kbdcode_atascii
  beq @done
  sta CMDDATA0
  jsr mi_edit_type_char
@done:
  rts

int_cmd_line_mode_backspace:
  jsr mi_edit_backspace
  rts

int_cmd_line_mode_shift_clear:
  jsr mi_shift_clear
  rts

int_cmd_line_mode_line_insert:
  jsr mi_edit_line_insert
  rts

int_cmd_line_mode_char_insert:
  jsr mi_edit_char_insert
  rts

int_cmd_line_mode_line_delete:
  jsr mi_edit_line_delete
  rts

int_cmd_line_mode_char_delete:
  jsr mi_edit_char_delete
  rts

int_cmd_line_mode_return:
  lda #<mi_data
  sta CMDDATA0
  lda #>mi_data
  sta CMDDATA1
  lda mi_metadata+TextArea::height
  sta CMDDATA2
  jsr mo_append_lines
  jsr mi_shift_clear
  rts

int_handle_kbd_char_mode:
  lda g_kbd_key_pressed
  beq @done
  lda g_kbdcode_atascii
  beq @done
  jsr int_cmd_put_rs232

;  lda g_kbdcode_atascii
;  sta CMDDATA0
;  jsr mo_append_char
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
  print_str str_loading_850
  jsr boot850_bootstrap
  bcc @rhandler_bootstrapped
  print_str str_error_loading_850
  jmp @error
@rhandler_bootstrapped:
  jsr boot850_check
  bcc @rhandler_loaded
  print_str str_error_missing_850
  jmp @error
@rhandler_loaded:
  print_str str_loaded_850
  jmp @done
@error:
  lda #PORT_STATUS_ERROR 
  sta port_status
@done:
  rts

int_cmd_open_rs232:
  print_str str_opening_rs232
  ldx #RS232_CHANNEL
  jsr rs232_open
  bcs @error
  print_str str_opened_rs232
  jmp @done
@error:
  sty command_error
  sty port_status
  print_str_with_code str_error_rs232_open, g_copy_buffer40, command_error
  jsr int_print_status
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
  lda rs232_byte_read
  sta CMDDATA0
  jsr mo_append_char
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
  sta g_copy_buffer40,y
  iny
  inx
  cpx addr_index_var
  bne @loop
@loop_done:
  lda #'-'
  sta g_copy_buffer40,y

  ldx addr_index_var    ; index to ssid
  lda pk_frame_header,x ; ssid
  jsr ut_bin_to_bcd

  lda ut_result
  lsr
  lsr
  lsr
  lsr
  beq @no_tens
  tax
  lda ut_hex_table_atascii,x
  iny
  sta g_copy_buffer40,y 
@no_tens:
  iny
  lda ut_result
  and #%00001111
  tax
  lda ut_hex_table_atascii,x
  sta g_copy_buffer40,y
  rts

int_handle_kiss_frame:
;  ldy #0
;  lda #KissFrameHeader::source
;  jsr int_addr_to_copy_buf
;  
;  iny
;  lda #'>'
;  sta g_copy_buffer40,y
;
;  iny
;  lda #KissFrameHeader::dest
;  jsr int_addr_to_copy_buf
;
;  iny
;  lda #':'
;  sta g_copy_buffer40,y
;
;  iny
;  sty g_copy_buffer40_size
;
;  lda #<g_copy_buffer40
;  sta CMDDATA0
;  lda #>g_copy_buffer40
;  sta CMDDATA1
;  lda g_copy_buffer40_size
;  sta CMDDATA2
;  jsr mo_append_chars
;
;  lda #<g_rx_buf
;  sta CMDDATA0
;  lda #>g_rx_buf
;  sta CMDDATA1
;  lda g_rx_buf_num_chars
;  sta CMDDATA2
;  jsr mo_append_chars
  rts

int_print_status:
  jsr rs232_status
  print_str_with_code str_last_status, g_copy_buffer40, rs232_last_status
@done:
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
  print_str_with_code str_error_rs232_status, g_copy_buffer40, command_error
  jsr int_print_status
  jmp @done
@error_getchr:
  sty command_error
  sty port_status
  print_str_with_code str_error_rs232_getchr, g_copy_buffer40, command_error
  jsr int_print_status
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
  print_str_with_code str_error_rs232_putchr, g_copy_buffer40, command_error
  jsr int_print_status
@done:
  rts

addr_index_var:              .byte $00
top_banner:                  .byte 'S'|$80,'E'|$80,'L'|$80,"theme "
                             .byte 'S'|$80,'T'|$80,'A'|$80,'R'|$80,'T'|$80,"config "
                             .byte $00
current_mode:                .res 1
str_welcome:                 .byte "Welcome!",$00

str_loading_850:             .byte "Loading 850...",$00
str_loaded_850:              .byte "850 handler loaded",$00
str_error_missing_850:       .byte "850 not in HATABS",$00
str_error_loading_850:       .byte "850 load error",$00
str_error:                   .byte "Error",$00
str_last_status:             .byte "Last status",$00
str_opening_rs232:           .byte "Opening RS232 port...",$00
str_opened_rs232:            .byte "RS232 port opened",$00
str_error_rs232_open:        .byte "Error opening RS232 port",$00
str_error_rs232_open_code:   ; used as index to print error code for above str
str_error_rs232_status:      .byte "Error on RS232 status",$00
str_error_rs232_status_code: ; used as index to print error code for above str
str_error_rs232_getchr:      .byte "Error on RS232 getchr",$00
str_error_rs232_getchr_code: ; used as index to print error code for above str
str_error_rs232_putchr:      .byte "Error on RS232 putchr",$00
str_error_rs232_putchr_code: ; used as index to print error code for above str
command_error:               .byte 0

rs232_byte_read:             .byte 0
port_status:                 .byte 0
