.setcpu "6502"
.include "main_input.inc"
.include "common.inc"
.include "config.inc"
.include "textarea.inc"

.segment "CODE"

.define MARGIN_LEFT   1
.define MARGIN_TOP    20
.define WIDTH         38
.define HEIGHT        4
.define SIZE          WIDTH * HEIGHT

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

  ; fill the data
  lda #' '
  ldy #0
@loop:
  sta mi_data,y
  iny
  cpy #SIZE
  bne @loop

  jsr int_set_context
  jsr ta_init_textarea
  rts

int_set_context:
  lda #<mi_metadata
  sta CMDDATA0
  lda #>mi_metadata
  sta CMDDATA1
  jsr ta_set_context
  rts


mi_hide_cursor:
  jsr ta_show_cursor
  rts

mi_show_cursor:
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

mi_metadata:              .tag TextArea
mi_data:                  .res SIZE
