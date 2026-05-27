.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "textarea.inc"
.SEGMENT "CODE"

.IMPORT utils_dump_mem_row
.IMPORT ta_init_textarea
.IMPORT ta_set_metadata_ptr
.EXPORT mti_init
.EXPORT mti_tmp_dump_data

MARGIN_LEFT   = 1
MARGIN_TOP    = 20
WIDTH         = 38
HEIGHT        = 4
SIZE          = WIDTH * HEIGHT

; get rid of this, only here for debug
; inputs: a -
mti_tmp_dump_data:
  sta tmp_dump
  lda SCR_PTR_LO
  sta CMDDATA0
  lda SCR_PTR_HI
  sta CMDDATA1

  lda CMDDATA0
  clc
  adc tmp_dump
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  lda #<metadata
  sta CMDDATA2
  lda #>metadata
  sta CMDDATA3
  ldy #0
  jsr utils_dump_mem_row

  lda CMDDATA0
  clc
  adc #40
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  lda #<(metadata+8)
  sta CMDDATA2
  lda #>(metadata+8)
  sta CMDDATA3
  ldy #0
  jsr utils_dump_mem_row

  lda CMDDATA0
  clc
  adc #40
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  lda #<input_scr_rows_lo
  sta CMDDATA2
  lda #>input_scr_rows_lo
  sta CMDDATA3
  ldy #0
  jsr utils_dump_mem_row

  lda CMDDATA0
  clc
  adc #40
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  lda #<input_scr_rows_hi
  sta CMDDATA2
  lda #>input_scr_rows_hi
  sta CMDDATA3
  ldy #0
  jsr utils_dump_mem_row

  lda tmp_dump
  rts

; initializes the text input area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mti_init:
  lda #0
  sta metadata+TextArea::cursorx
  sta metadata+TextArea::cursory
  sta metadata+TextArea::cursorpos

  lda #CURSOR_FLAG_ENABLED
  sta metadata+TextArea::use_cursor

  lda #<mti_main_input_data
  sta metadata+TextArea::first_row_data_ptr
  lda #>mti_main_input_data
  sta metadata+TextArea::first_row_data_ptr+1
  lda #MARGIN_LEFT
  sta metadata+TextArea::margin_left
  lda #MARGIN_TOP
  sta metadata+TextArea::margin_top
  lda #WIDTH
  sta metadata+TextArea::width
  lda #HEIGHT
  sta metadata+TextArea::height
  lda #SIZE
  sta metadata+TextArea::size
  lda #(WIDTH-1)
  sta metadata+TextArea::cursor_maxx
  lda #(HEIGHT-1)
  sta metadata+TextArea::cursor_maxy

  ; set pointers to table where screen row data is stored
  lda #<input_scr_rows_lo
  sta metadata+TextArea::scr_row_ptr_table_lo
  lda #>input_scr_rows_lo
  sta metadata+TextArea::scr_row_ptr_table_lo+1

  lda #<input_scr_rows_hi
  sta metadata+TextArea::scr_row_ptr_table_hi
  lda #>input_scr_rows_hi
  sta metadata+TextArea::scr_row_ptr_table_hi+1

  ; fill the data
  lda #' '
  ldy #0
@loop:
  sta mti_main_input_data,y
  iny
  cpy #SIZE
  bne @loop

  lda #<metadata
  sta CMDDATA0
  lda #>metadata
  sta CMDDATA1
  jsr ta_set_metadata_ptr
  jsr ta_init_textarea

  rts

metadata: .tag TextArea

input_scr_rows_lo:   .res HEIGHT
input_scr_rows_hi:   .res HEIGHT
mti_main_input_data: .res SIZE

tmp_dump: .byte 0
