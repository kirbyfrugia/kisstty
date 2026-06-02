.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "textarea.inc"

.IMPORT utils_dump_mem_row
.IMPORT ta_init_textarea
.IMPORT ta_set_context
.IMPORT ta_hide_cursor
.IMPORT ta_show_cursor
.IMPORT ta_repaint
.EXPORT mi_init
.EXPORT mi_reset
.EXPORT mi_hide_cursor
.EXPORT mi_show_cursor
.EXPORT mi_metadata
.EXPORT mi_data

.SEGMENT "CODE"

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
  sta mi_metadata+TextArea::cursorpos

  lda #<(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  clc
  adc SCR_PTR_LO
  sta mi_metadata+TextArea::first_row_scr_ptr
  lda #>(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  adc SCR_PTR_HI
  sta mi_metadata+TextArea::first_row_scr_ptr+1

  lda #CURSOR_FLAG_ENABLED
  sta mi_metadata+TextArea::use_cursor

  lda #<mi_data
  sta mi_metadata+TextArea::first_row_data_ptr
  lda #>mi_data
  sta mi_metadata+TextArea::first_row_data_ptr+1
  lda #MARGIN_LEFT
  sta mi_metadata+TextArea::margin_left
  lda #MARGIN_TOP
  sta mi_metadata+TextArea::margin_top
  lda #WIDTH
  sta mi_metadata+TextArea::width
  lda #HEIGHT
  sta mi_metadata+TextArea::height
  lda #SIZE
  sta mi_metadata+TextArea::size
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

  lda #<mi_metadata
  sta CMDDATA0
  lda #>mi_metadata
  sta CMDDATA1
  jsr ta_set_context
  jsr ta_init_textarea

  rts

mi_hide_cursor:
  jsr ta_show_cursor
  rts

mi_show_cursor:
  jsr ta_show_cursor
  rts

mi_reset:
  jsr ta_repaint
  rts

mi_metadata:              .tag TextArea
mi_data:                  .res SIZE
