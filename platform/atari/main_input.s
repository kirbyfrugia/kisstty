.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "textarea.inc"
.SEGMENT "CODE"

.IMPORT utils_dump_mem_row
.IMPORT ta_init_textarea
.IMPORT ta_set_metadata_ptr
.IMPORT ta_hide_cursor
.IMPORT ta_show_cursor
.IMPORT ta_repaint
.EXPORT mi_init
.EXPORT mi_repaint
.EXPORT mi_hide_cursor
.EXPORT mi_show_cursor
.EXPORT mi_metadata
.EXPORT mi_data

MARGIN_LEFT   = 1
MARGIN_TOP    = 20
WIDTH         = 38
HEIGHT        = 4
SIZE          = WIDTH * HEIGHT

; initializes the text input area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mi_init:
  lda #0
  sta mi_metadata+TextArea::cursorx
  sta mi_metadata+TextArea::cursory
  sta mi_metadata+TextArea::cursorpos

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

  ; set pointers to table where screen row data is stored
  lda #<input_scr_rows_lo
  sta mi_metadata+TextArea::scr_row_ptr_table_lo
  lda #>input_scr_rows_lo
  sta mi_metadata+TextArea::scr_row_ptr_table_lo+1

  lda #<input_scr_rows_hi
  sta mi_metadata+TextArea::scr_row_ptr_table_hi
  lda #>input_scr_rows_hi
  sta mi_metadata+TextArea::scr_row_ptr_table_hi+1

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
  jsr ta_set_metadata_ptr
  jsr ta_init_textarea

  rts

mi_hide_cursor:
  jsr ta_show_cursor
  rts

mi_show_cursor:
  jsr ta_show_cursor
  rts

mi_repaint:
  jsr ta_repaint
  rts

mi_metadata:        .tag TextArea
input_scr_rows_lo:  .res HEIGHT
input_scr_rows_hi:  .res HEIGHT
mi_data:            .res SIZE
