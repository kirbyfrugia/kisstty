.ifndef TEXT_AREA_INC
TEXT_AREA_INC = 1
.SEGMENT "CODE"

TA_SCROLL_BACKFILL_ENABLED       = %10000000 ; when scrolling, backfill
TA_SCROLL_SAVE_DISCARDED_ENABLED = %01000000 ; when scrolling, save discarded
TA_SCROLL_JUST_SCROLL            = %00000000

; get the current metadata_ptr from the text area
; and push it to the stack
.macro pha_metadata_ptr
  lda TA_METADATA_PTR_LO
  pha
  lda TA_METADATA_PTR_HI
  pha
.endmacro

.macro pla_metadata_ptr
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
.endmacro

.struct TextArea
  first_row_data_ptr    .word
  last_row_data_ptr     .word
  scr_row_ptr_table_lo  .word
  scr_row_ptr_table_hi  .word
  margin_left           .byte
  margin_top            .byte
  width                 .byte
  height                .byte
  size                  .byte
  cursorx               .byte
  cursory               .byte
  cursor_maxx           .byte
  cursor_maxy           .byte
  cursorpos             .byte
  use_cursor            .byte
  cursor_scr_row_ptr    .word
  first_row_scr_row_ptr .word
  last_row_scr_row_ptr  .word
.endstruct

.endif
