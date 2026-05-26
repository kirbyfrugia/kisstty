.ifndef TEXT_AREA_INC
TEXT_AREA_INC = 1

.struct TextArea
  data_ptr             .word
  scr_row_ptr_table_lo .word
  scr_row_ptr_table_hi .word
  margin_left          .byte
  margin_top           .byte
  width                .byte
  height               .byte
  size                 .byte
  cursorx              .byte
  cursory              .byte
  cursor_maxx          .byte
  cursor_maxy          .byte
  cursorpos            .byte
  use_cursor           .byte
  cursor_scr_row_ptr   .word
.endstruct

.endif
