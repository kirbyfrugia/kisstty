.setcpu "6502"
.include "config.inc"
.include "globals.inc"
.include "macros.inc"
.include "main_output.inc"
.include "terminal.inc"
.include "textarea.inc"

.segment "CODE"
MARGIN_LEFT = 1
WIDTH       = 38
HEIGHT      = 18
SIZE        = WIDTH*HEIGHT

; initializes the text output area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mo_init:
  lda #0
  sta mo_metadata+TextArea::cursorx
  sta mo_metadata+TextArea::cursory
  sta mo_metadata+TextArea::cursor_line_scr_ptr
  sta mo_metadata+TextArea::cursor_line_scr_ptr+1

  lda #TA_TYPE_OUTPUT
  sta mo_metadata+TextArea::type

  MARGIN_TOP .set 1
  lda #<(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  clc
  adc SCR_PTR_LO
  sta mo_metadata+TextArea::first_line_scr_ptr
  lda #>(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  adc SCR_PTR_HI
  sta mo_metadata+TextArea::first_line_scr_ptr+1

  lda #WIDTH
  sta mo_metadata+TextArea::width
  lda #HEIGHT
  sta mo_metadata+TextArea::height
  lda #<SIZE
  sta mo_metadata+TextArea::size
  lda #>SIZE
  sta mo_metadata+TextArea::size+1
  lda #(WIDTH-1)
  sta mo_metadata+TextArea::cursor_maxx
  lda #(HEIGHT-1)
  sta mo_metadata+TextArea::cursor_maxy

  lda #<mo_data
  sta mo_metadata+TextArea::first_line_data_ptr
  lda #>mo_data
  sta mo_metadata+TextArea::first_line_data_ptr+1

  lda #<mo_metadata
  sta CMDDATA0
  lda #>mo_metadata
  sta CMDDATA1
  jsr ta_set_context
  jsr ta_init_textarea
  jsr ta_shift_clear

  rts

int_set_context:
  lda CMDDATA0
  pha
  lda CMDDATA1
  pha
  lda #<mo_metadata
  sta CMDDATA0
  lda #>mo_metadata
  sta CMDDATA1
  jsr ta_set_context
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
  rts

mo_repaint:
  jsr int_set_context
  jsr ta_repaint
  rts

mo_reset:
  jsr int_set_context
  jsr ta_shift_clear
@reset_done:
  rts


mo_println:
  jsr int_set_context
  jsr ta_out_println
  rts

; appends the char to the output area, scrolling
; if needed.
; inputs:
;   CMDDATA0 - the char
mo_append_char:
  jsr int_set_context
  jsr ta_out_append_char
  rts

; inputs:
;   CMDDATA0/1 - pointer to the data to append
;   CMDDATA2   - number of lines to append
mo_append_lines:
  jsr int_set_context
  jsr ta_out_append_lines
  rts

mo_metadata: .tag TextArea
mo_data:     .res SIZE

new_line: .repeat SCREEN_WIDTH, I
             .byte ' '
           .endrepeat
