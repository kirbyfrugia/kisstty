.setcpu "6502"
.include "config.inc"
.include "globals.inc"
.include "macros.inc"
.include "main_output.inc"
.include "terminal.inc"
.include "textarea.inc"

.segment "CODE"
MO_MARGIN_LEFT = 1
MO_WIDTH       = 38
MO_MAX_SIZE    = MO_WIDTH*MO_MAX_HEIGHT

mo_init:
  lda #0
  sta mo_metadata+TextArea::cursorx
  sta mo_metadata+TextArea::cursory
  sta mo_metadata+TextArea::cursor_line_scr_ptr
  sta mo_metadata+TextArea::cursor_line_scr_ptr+1

  lda #TA_TYPE_OUTPUT
  sta mo_metadata+TextArea::type

  MARGIN_TOP .set 1
  lda #<(MARGIN_TOP*SCREEN_WIDTH+MO_MARGIN_LEFT)
  clc
  adc SCR_PTR_LO
  sta mo_metadata+TextArea::first_line_scr_ptr
  lda #>(MARGIN_TOP*SCREEN_WIDTH+MO_MARGIN_LEFT)
  adc SCR_PTR_HI
  sta mo_metadata+TextArea::first_line_scr_ptr+1

  lda #MO_WIDTH
  sta mo_metadata+TextArea::width
  lda #(MO_WIDTH-1)
  sta mo_metadata+TextArea::cursor_maxx

  lda #<mo_data
  sta mo_metadata+TextArea::first_line_data_ptr
  lda #>mo_data
  sta mo_metadata+TextArea::first_line_data_ptr+1

  lda #MO_LINE_HEIGHT
  jsr mo_resize

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

; resizes the output area to a new height
; inputs:
;   a - the new height in rows
mo_resize:
  pha
  jsr int_set_context
  pla

  sta ta_metadata+TextArea::height
  sec
  sbc #1
  sta ta_metadata+TextArea::cursor_maxy

  lda #0
  sta ta_metadata+TextArea::size
  sta ta_metadata+TextArea::size+1
  ldx ta_metadata+TextArea::height
@size_loop:
  lda ta_metadata+TextArea::size
  clc
  adc #MO_WIDTH
  sta ta_metadata+TextArea::size
  bcc @size_nowrap
  inc ta_metadata+TextArea::size+1
@size_nowrap:
  dex
  bne @size_loop

  jsr ta_shift_clear
  rts

; see ta_out_println for what this does. Not super
; efficient, but fine for short strings like "welcome"
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

; appends N lines to the current row if blank
; or the next blank row, scrolling if necessary
; inputs:
;   CMDDATA0/1 - pointer to the data to append
;   CMDDATA2   - number of lines to append
mo_append_lines:
  jsr int_set_context
  jsr ta_out_append_lines
  rts

mo_metadata: .tag TextArea
mo_data:     .res MO_MAX_SIZE

new_line: .repeat SCREEN_WIDTH, I
             .byte ' '
           .endrepeat
