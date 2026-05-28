.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "textarea.inc"
.SEGMENT "CODE"

.IMPORT utils_dump_mem_row
.IMPORT ta_init_textarea
.IMPORT ta_get_metadata_ptr
.IMPORT ta_set_metadata_ptr
.IMPORT ta_copy_first_line
.IMPORT ta_copy_last_n_lines
.IMPORT ta_paste_last_line
.IMPORT ta_shift_all_up_n_lines
.EXPORT mo_init
.EXPORT mo_scroll_up_four
.EXPORT mo_paste_last_line

MARGIN_TOP_AREA0 = 0
MARGIN_TOP_AREA1 = 6
MARGIN_TOP_AREA2 = 12
MARGIN_LEFT   = 1
WIDTH         = 38
HEIGHT        = 6
SIZE          = WIDTH * HEIGHT

; initializes the text output area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mo_init:
  ta_init area0_data, MARGIN_TOP_AREA0, MARGIN_LEFT, WIDTH, HEIGHT, #CURSOR_FLAG_DISABLED
  ta_init area1_data, MARGIN_TOP_AREA1, MARGIN_LEFT, WIDTH, HEIGHT, #CURSOR_FLAG_DISABLED
  ta_init area2_data, MARGIN_TOP_AREA2, MARGIN_LEFT, WIDTH, HEIGHT, #CURSOR_FLAG_DISABLED

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

  lda #<area1_metadata
  sta CMDDATA0
  lda #>area1_metadata
  sta CMDDATA1
  jsr ta_set_metadata_ptr

  lda #<area2_metadata
  sta CMDDATA0
  lda #>area2_metadata
  sta CMDDATA1
  jsr ta_set_metadata_ptr

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

mo_scroll_up_four:
  lda #1
  sta CMDDATA0

  jsr ta_copy_last_n_lines
  jsr ta_shift_all_up_n_lines

  save_metadata_ptr

  jsr int_set_area0_active
  jsr ta_shift_all_up_one_line

  jsr int_set_area1_active
  jsr ta_copy_first_line
  jsr ta_shift_all_up_one_line

  jsr int_set_area0_active
  jsr ta_paste_last_line

  jsr int_set_area2_active
  jsr ta_copy_first_line
  jsr ta_shift_all_up_one_line

  jsr int_set_area1_active
  jsr ta_paste_last_line
  
  restore_metadata_ptr
  rts

mo_paste_last_line:
  save_metadata_ptr

  jsr int_set_area2_active
  jsr ta_paste_last_line

  restore_metadata_ptr
  
  rts

area0_metadata: .tag TextArea
area0_data:     .res SIZE
area1_metadata: .tag TextArea
area1_data:     .res SIZE
area2_metadata: .tag TextArea
area2_data:     .res SIZE
