.SETCPU "6502"

.INCLUDE "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"

.IMPORT g_kbd_key_pressed
.IMPORT g_kbdcode_raw
.IMPORT g_kbdcode_raw_stripped
.IMPORT g_kbdcode_atascii
.IMPORT utils_atascii_to_icode
.IMPORT mi_init
.IMPORT mi_repaint
.IMPORT mi_main_input_metadata
.IMPORT mi_hide_cursor
.IMPORT mi_show_cursor
.IMPORT mo_init
.IMPORT mo_repaint
.IMPORT mo_append
.IMPORT mo_scroll_up
.IMPORT mo_paste_last_line
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
.EXPORT trm_init
.EXPORT trm_activate
.EXPORT trm_tick

.SEGMENT "CODE"

trm_init:
  jsr mo_init
  jsr mi_init
  rts

trm_activate:
  jsr mi_show_cursor
  LINE_ABOVE_INPUT_OFFSET = 40*19
  lda SCR_PTR_LO
  clc
  adc #<LINE_ABOVE_INPUT_OFFSET
  sta ZPB0
  LDA SCR_PTR_HI
  adc #>LINE_ABOVE_INPUT_OFFSET
  sta ZPB1

  lda #$52 ; horizontal bar
  ldy #39
@loop:
  sta (ZPB0),y
  dey
  bpl @loop

  jsr mo_repaint
  jsr mi_repaint
  jsr mi_show_cursor
  rts

trm_tick:
  jsr int_handle_kbd
  rts

int_cmd_move_cursor_up:
  jsr ta_move_cursor_up
  rts

int_cmd_move_cursor_down:
  jsr ta_move_cursor_down
  rts

int_cmd_move_cursor_left:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr ta_move_cursor_left
  rts

int_cmd_move_cursor_right:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr ta_move_cursor_right
  rts

int_cmd_typechar:
  lda g_kbdcode_atascii
  beq @done
  jsr ta_typechar
@done:
  rts

int_cmd_backspace:
  jsr ta_backspace
  rts

int_cmd_shift_clear:
  jsr ta_shift_clear
  rts

int_cmd_line_insert:
  jsr ta_line_insert
  rts

int_cmd_char_insert:
  jsr ta_char_insert
  rts

int_cmd_line_delete:
  jsr ta_line_delete
  rts

int_cmd_char_delete:
  jsr ta_char_delete
  rts

int_cmd_return:
  jsr mo_scroll_up
  rts

int_handle_kbd:
  lda g_kbd_key_pressed
  beq @done
;  ; TODO remove when no longer debugging
;  lda SAVMSC
;  sta CMDDATA0
;  lda SAVMSC+1
;  sta CMDDATA1
;  ldy #0
;  lda g_kbdcode_raw 
;  jsr utils_byte_to_scr_hex
;  ldy #3
;  lda ctrl_shift_lock_flag
;  jsr utils_byte_to_scr_hex

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
  jsr int_cmd_typechar
  jmp @done
@up_arrow:
  jmp int_cmd_move_cursor_up
  jmp @done
@down_arrow:
  jmp int_cmd_move_cursor_down
  jmp @done
@left_arrow:
  jmp int_cmd_move_cursor_left
  jmp @done
@right_arrow:
  jmp int_cmd_move_cursor_right
  jmp @done
@backspace:
  jsr int_cmd_backspace
  jmp @done
@shift_clear:
  jsr int_cmd_shift_clear
  jmp @done
@line_insert:
  jsr int_cmd_line_insert
  jmp @done
@char_insert:
  jsr int_cmd_char_insert
  jmp @done
@line_delete:
  jsr int_cmd_line_delete
  jmp @done
@char_delete:
  jsr int_cmd_char_delete
  jmp @done
@return:
  jsr int_cmd_return
@done:
  rts


