.setcpu "6502"
.include "main_input.inc"
.include "config.inc"
.include "globals.inc"
.include "textarea.inc"

.segment "CODE"

MARGIN_LEFT = 1
MARGIN_TOP  = 20
WIDTH       = 38
HEIGHT      = 4
SIZE        = WIDTH * HEIGHT

; initializes the text input area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mi_init:
  lda #0
  sta mi_metadata+TextArea::cursorx
  sta mi_metadata+TextArea::cursory

  lda #<(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  clc
  adc SCR_PTR_LO
  sta mi_metadata+TextArea::first_line_scr_ptr
  lda #>(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  adc SCR_PTR_HI
  sta mi_metadata+TextArea::first_line_scr_ptr+1

  lda #TA_TYPE_INPUT
  sta mi_metadata+TextArea::type

  lda #<mi_data
  sta mi_metadata+TextArea::first_line_data_ptr
  lda #>mi_data
  sta mi_metadata+TextArea::first_line_data_ptr+1
  lda #WIDTH
  sta mi_metadata+TextArea::width
  lda #HEIGHT
  sta mi_metadata+TextArea::height
  lda #SIZE
  sta mi_metadata+TextArea::size
  lda #0
  sta mi_metadata+TextArea::size+1
  lda #(WIDTH-1)
  sta mi_metadata+TextArea::cursor_maxx
  lda #(HEIGHT-1)
  sta mi_metadata+TextArea::cursor_maxy

  jsr int_set_context
  jsr ta_shift_clear
  rts

int_set_context:
  ; preserve CMDDATA0/1 so callers can stage command inputs there
  ; before setting the context (matches int_set_mo_active)
  lda CMDDATA0
  pha
  lda CMDDATA1
  pha
  lda #<mi_metadata
  sta CMDDATA0
  lda #>mi_metadata
  sta CMDDATA1
  jsr ta_set_context
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
  rts


mi_hide_cursor:
  jsr int_set_context
  jsr ta_show_cursor
  rts

mi_show_cursor:
  jsr int_set_context
  jsr ta_show_cursor
  rts

mi_repaint:
  jsr int_set_context
  jsr ta_repaint
  rts

mi_reset:
  jsr int_set_context
  jsr ta_shift_clear
  rts

mi_edit_move_cursor_up:
  jsr int_set_context
  jsr ta_edit_move_cursor_up
  rts

mi_edit_move_cursor_down:
  jsr int_set_context
  jsr ta_edit_move_cursor_down
  rts

; inputs:
;   CMDDATA0 - cursor behavior on wrap
mi_edit_move_cursor_left:
  jsr int_set_context
  jsr ta_edit_move_cursor_left
  rts

; inputs:
;   CMDDATA0 - cursor behavior on wrap
mi_edit_move_cursor_right:
  jsr int_set_context
  jsr ta_edit_move_cursor_right
  rts

; inputs:
;   CMDDATA0 - the char to type
mi_edit_type_char:
  jsr int_set_context
  jsr ta_edit_type_char
  rts

mi_edit_backspace:
  jsr int_set_context
  jsr ta_edit_backspace
  rts

mi_shift_clear:
  jsr int_set_context
  jsr ta_shift_clear
  rts

mi_edit_line_insert:
  jsr int_set_context
  jsr ta_edit_line_insert
  rts

mi_edit_char_insert:
  jsr int_set_context
  jsr ta_edit_char_insert
  rts

mi_edit_line_delete:
  jsr int_set_context
  jsr ta_edit_line_delete
  rts

mi_edit_char_delete:
  jsr int_set_context
  jsr ta_edit_char_delete
  rts

mi_metadata:              .tag TextArea
mi_data:                  .res SIZE
