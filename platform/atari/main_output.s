.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "textarea.inc"
.SEGMENT "CODE"

.IMPORT copy_buffer40
.IMPORT copy_buffer40_size
.IMPORT utils_dump_mem_row
.IMPORT ta_init_textarea
.IMPORT ta_get_metadata_ptr
.IMPORT ta_set_metadata_ptr
.IMPORT ta_repaint
.IMPORT ta_shift_clear
.IMPORT ta_scroll_up
.EXPORT mo_init
.EXPORT mo_append
.EXPORT mo_append_line_from_copy_buffer40
.EXPORT mo_repaint

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

  lda #CURSOR_FLAG_DISABLED
  sta area0_metadata+TextArea::use_cursor
  sta area1_metadata+TextArea::use_cursor
  sta area2_metadata+TextArea::use_cursor

  lda #1
  sta area0_metadata+TextArea::margin_top
  lda #7
  sta area1_metadata+TextArea::margin_top
  lda #13
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
  sta area0_metadata+TextArea::first_row_data_ptr
  lda #>area0_data
  sta area0_metadata+TextArea::first_row_data_ptr+1
  lda #<area1_data
  sta area1_metadata+TextArea::first_row_data_ptr
  lda #>area1_data
  sta area1_metadata+TextArea::first_row_data_ptr+1
  lda #<area2_data
  sta area2_metadata+TextArea::first_row_data_ptr
  lda #>area2_data
  sta area2_metadata+TextArea::first_row_data_ptr+1


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
  jsr ta_set_metadata_ptr
  jsr ta_init_textarea

  lda #<area1_metadata
  sta CMDDATA0
  lda #>area1_metadata
  sta CMDDATA1
  jsr ta_set_metadata_ptr
  jsr ta_init_textarea

  lda #<area2_metadata
  sta CMDDATA0
  lda #>area2_metadata
  sta CMDDATA1
  jsr ta_set_metadata_ptr
  jsr ta_init_textarea

  rts

int_set_area0_active:
  lda #<area0_metadata
  sta CMDDATA0
  lda #>area0_metadata
  sta CMDDATA1
  jsr ta_set_metadata_ptr
  rts

int_set_area1_active:
  lda #<area1_metadata
  sta CMDDATA0
  lda #>area1_metadata
  sta CMDDATA1
  jsr ta_set_metadata_ptr
  rts

int_set_area2_active:
  lda #<area2_metadata
  sta CMDDATA0
  lda #>area2_metadata
  sta CMDDATA1
  jsr ta_set_metadata_ptr
  rts

mo_repaint:
  pha_metadata_ptr
  jsr int_set_area0_active
  jsr ta_repaint
  jsr int_set_area1_active
  jsr ta_repaint
  jsr int_set_area2_active
  jsr ta_repaint
  pla_metadata_ptr
  jsr ta_set_metadata_ptr
  rts

; appends N lines to the output
;
; warn: you should make sure the input and
;       output lines are the same length
;
; inputs:
;   CMDDATA0/1 - pointer to the data to append
;   CMDDATA4   - num lines to ppend
mo_append:
  lda CMDDATA0
  pha
  lda CMDDATA1
  pha

  ; scroll area1 into area0
  jsr int_set_area0_active

  lda #<area1_data
  sta CMDDATA0
  lda #>area1_data
  sta CMDDATA1
  lda #TA_SCROLL_BACKFILL_ENABLED
  sta CMDDATA5
  jsr ta_scroll_up

  ; scroll area2 into area1
  jsr int_set_area1_active

  lda #<area2_data
  sta CMDDATA0
  lda #>area2_data
  sta CMDDATA1
  lda #TA_SCROLL_BACKFILL_ENABLED
  sta CMDDATA5
  jsr ta_scroll_up

  ; scroll input into area2
  jsr int_set_area2_active

  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
  lda #TA_SCROLL_BACKFILL_ENABLED
  sta CMDDATA5
  jsr ta_scroll_up

  rts


; appends data to the output area. will
; blank out anything beyond copy_buffer40_size
; inputs:
;   copy_buffer40, copy_buffer40_size (num chars)
mo_append_line_from_copy_buffer40:
  lda #' '
  ldy copy_buffer40_size
@fill:
  cpy #40
  bcs @fill_done
  sta copy_buffer40,y
  iny
  bne @fill
@fill_done:
  lda #<copy_buffer40
  sta CMDDATA0
  lda #>copy_buffer40
  sta CMDDATA1
  lda #1
  sta CMDDATA4
  jsr mo_append

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

