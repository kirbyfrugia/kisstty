.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "textarea.inc"
.SEGMENT "CODE"

.IMPORT utils_dump_mem_row
.IMPORT ta_init_textarea
.IMPORT ta_set_metadata
.IMPORT ta_line_append
.EXPORT mo_init
.EXPORT mo_set_active
.EXPORT mo_append

MARGIN_LEFT   = 1
WIDTH         = 38
HEIGHT        = 6
SIZE          = WIDTH * HEIGHT

; initializes the text output area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mo_init:
  lda #0
  sta area0_metadata+TextArea::cursorx
  sta area0_metadata+TextArea::cursory
  sta area0_metadata+TextArea::cursorpos
  sta area1_metadata+TextArea::cursorx
  sta area1_metadata+TextArea::cursory
  sta area1_metadata+TextArea::cursorpos
  sta area2_metadata+TextArea::cursorx
  sta area2_metadata+TextArea::cursory
  sta area2_metadata+TextArea::cursorpos

  lda #0
  sta area0_metadata+TextArea::margin_top
  lda #6
  sta area1_metadata+TextArea::margin_top
  lda #12
  sta area2_metadata+TextArea::margin_top

  lda #MARGIN_LEFT
  sta area0_metadata+TextArea::margin_left
  sta area1_metadata+TextArea::margin_left
  sta area2_metadata+TextArea::margin_left

  lda #WIDTH
  sta area0_metadata+TextArea::width
  sta area1_metadata+TextArea::width
  sta area2_metadata+TextArea::width

  lda #HEIGHT
  sta area0_metadata+TextArea::height
  sta area1_metadata+TextArea::height
  sta area2_metadata+TextArea::height

  lda #SIZE
  sta area0_metadata+TextArea::size
  sta area1_metadata+TextArea::size
  sta area2_metadata+TextArea::size

  lda #(WIDTH-1)
  sta area0_metadata+TextArea::cursor_maxx
  sta area1_metadata+TextArea::cursor_maxx
  sta area2_metadata+TextArea::cursor_maxx

  lda #(HEIGHT-1)
  sta area0_metadata+TextArea::cursor_maxy
  sta area1_metadata+TextArea::cursor_maxy
  sta area2_metadata+TextArea::cursor_maxy

  lda #<area0_data
  sta area0_metadata+TextArea::data_ptr
  lda #>area0_data
  sta area0_metadata+TextArea::data_ptr+1
  lda #<area1_data
  sta area1_metadata+TextArea::data_ptr
  lda #>area1_data
  sta area1_metadata+TextArea::data_ptr+1
  lda #<area2_data
  sta area2_metadata+TextArea::data_ptr
  lda #>area2_data
  sta area2_metadata+TextArea::data_ptr+1


  ; set pointers to table where screen row data is stored
  lda #<area0_scr_row_ptr_table_lo
  sta area0_metadata+TextArea::scr_row_ptr_table_lo
  lda #>area0_scr_row_ptr_table_lo
  sta area0_metadata+TextArea::scr_row_ptr_table_lo+1
  lda #<area1_scr_row_ptr_table_lo
  sta area1_metadata+TextArea::scr_row_ptr_table_lo
  lda #>area1_scr_row_ptr_table_lo
  sta area1_metadata+TextArea::scr_row_ptr_table_lo+1
  lda #<area2_scr_row_ptr_table_lo
  sta area2_metadata+TextArea::scr_row_ptr_table_lo
  lda #>area2_scr_row_ptr_table_lo
  sta area2_metadata+TextArea::scr_row_ptr_table_lo+1

  lda #<area0_scr_row_ptr_table_hi
  sta area0_metadata+TextArea::scr_row_ptr_table_hi
  lda #>area0_scr_row_ptr_table_hi
  sta area0_metadata+TextArea::scr_row_ptr_table_hi+1
  lda #<area1_scr_row_ptr_table_hi
  sta area1_metadata+TextArea::scr_row_ptr_table_hi
  lda #>area1_scr_row_ptr_table_hi
  sta area1_metadata+TextArea::scr_row_ptr_table_hi+1
  lda #<area2_scr_row_ptr_table_hi
  sta area2_metadata+TextArea::scr_row_ptr_table_hi
  lda #>area2_scr_row_ptr_table_hi
  sta area2_metadata+TextArea::scr_row_ptr_table_hi+1

  ; fill the data
  ldy #0
  lda #' '
@loop:
  sta area0_data,y
  sta area1_data,y
  sta area2_data,y
  iny
  cpy #SIZE
  bne @loop

  lda #<area0_metadata
  sta CMDDATA0
  lda #>area0_metadata
  sta CMDDATA1
  jsr ta_set_metadata
  jsr ta_init_textarea

  lda #<area1_metadata
  sta CMDDATA0
  lda #>area1_metadata
  sta CMDDATA1
  jsr ta_set_metadata
  jsr ta_init_textarea

  lda #<area2_metadata
  sta CMDDATA0
  lda #>area2_metadata
  sta CMDDATA1
  jsr ta_set_metadata
  jsr ta_init_textarea

  rts

; inputs:
;   - CMDDATA0/1 - pointer to the data to append
;   - CMDDATA2   - number of chars. On you if you exceed
mo_append:
  jsr ta_line_append
  rts

mo_set_active:
  lda #<area2_metadata
  sta CMDDATA0
  lda #>area2_metadata
  sta CMDDATA1
  jsr ta_set_metadata
  rts

area0_metadata:             .tag TextArea
area0_scr_row_ptr_table_lo: .res HEIGHT
area0_scr_row_ptr_table_hi: .res HEIGHT
area0_data:                 .res SIZE

area1_metadata:             .tag TextArea
area1_scr_row_ptr_table_lo: .res HEIGHT
area1_scr_row_ptr_table_hi: .res HEIGHT
area1_data:                 .res SIZE

area2_metadata:             .tag TextArea
area2_scr_row_ptr_table_lo: .res HEIGHT
area2_scr_row_ptr_table_hi: .res HEIGHT
area2_data:                 .res SIZE

tmp_dump: .byte 0
