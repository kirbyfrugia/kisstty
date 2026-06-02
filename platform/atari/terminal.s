.SETCPU "6502"

.INCLUDE "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"
.INCLUDE "terminal.inc"
.INCLUDE "textarea.inc"

.IMPORT copy_buffer40
.IMPORT copy_buffer40_size
.IMPORT str_to_copy_buffer40_with_fill
.IMPORT g_kbd_key_pressed
.IMPORT g_kbdcode_raw
.IMPORT g_kbdcode_raw_stripped
.IMPORT g_kbdcode_atascii
.IMPORT utils_atascii_to_icode
.IMPORT cfg_saved_config
.IMPORT mi_init
.IMPORT mi_metadata
.IMPORT mi_data
.IMPORT mi_reset
.IMPORT mi_main_input_metadata
.IMPORT mi_hide_cursor
.IMPORT mi_show_cursor
.IMPORT mo_init
.IMPORT mo_reset
.IMPORT mo_append_chars
.IMPORT mo_scroll_up
.IMPORT ta_scr_ptr
.IMPORT ta_move_cursor_up
.IMPORT ta_move_cursor_down
.IMPORT ta_move_cursor_left
.IMPORT ta_move_cursor_right
.IMPORT ta_typechar
.IMPORT ta_backspace
.IMPORT ta_shift_clear
.IMPORT ta_line_insert
.IMPORT ta_char_insert
.IMPORT ta_line_delete
.IMPORT ta_char_delete
.IMPORT ta_copy_first_line
.IMPORT ta_copy_last_line
.IMPORT ta_push_context
.IMPORT ta_pop_context
.IMPORT ta_metadata
.EXPORT trm_init
.EXPORT trm_activate
.EXPORT trm_tick

.SEGMENT "CODE"

trm_init:
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

int_activate_line_mode:
  jsr mo_reset
  jsr mi_reset

  jsr int_draw_ui_line_mode

  rts

int_activate_char_mode:
  jsr mo_reset
  jsr int_draw_ui_char_mode
  rts

trm_activate:
  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::CHAR
  beq @char_mode
  jsr int_activate_line_mode
  jmp @welcome
@char_mode:
  jsr int_activate_char_mode

@welcome:
  lda #<welcome
  sta CMDDATA0
  lda #>welcome
  sta CMDDATA1
  lda #38
  sta CMDDATA2
  lda #' '
  sta CMDDATA3
  jsr str_to_copy_buffer40_with_fill

  lda copy_buffer40_size
  sta CMDDATA2
  lda #<copy_buffer40
  sta CMDDATA0
  lda #>copy_buffer40
  sta CMDDATA1
  jsr mo_append_chars

  rts

trm_tick:
  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::CHAR
  beq @char_mode
  jsr int_handle_kbd_line_mode
  jmp @done
@char_mode:
  jsr int_handle_kbd_char_mode
@done:
  rts


int_cmd_line_mode_move_cursor_up:
  jsr ta_move_cursor_up
  rts

int_cmd_line_mode_move_cursor_down:
  jsr ta_move_cursor_down
  rts

int_cmd_line_mode_move_cursor_left:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr ta_move_cursor_left
  rts

int_cmd_line_mode_move_cursor_right:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr ta_move_cursor_right
  rts

int_cmd_line_mode_handle_char:
  lda g_kbdcode_atascii
  beq @done
  jsr ta_typechar
@done:
  rts

int_cmd_line_mode_backspace:
  jsr ta_backspace
  rts

int_cmd_line_mode_shift_clear:
  jsr ta_shift_clear
  rts

int_cmd_line_mode_line_insert:
  jsr ta_line_insert
  rts

int_cmd_line_mode_char_insert:
  jsr ta_char_insert
  rts

int_cmd_line_mode_line_delete:
  jsr ta_line_delete
  rts

int_cmd_line_mode_char_delete:
  jsr ta_char_delete
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

  lda #<g_kbdcode_atascii
  sta CMDDATA0
  lda #>g_kbdcode_atascii
  sta CMDDATA1
  lda #1
  sta CMDDATA2
  jsr mo_append_chars
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

top_banner:             .byte 'S'|$80,'E'|$80,'L'|$80,"theme "
                        .byte 'S'|$80,'T'|$80,'A'|$80,'R'|$80,'T'|$80,"config "
                        .byte $00

welcome: .byte "Welcome!",$00
