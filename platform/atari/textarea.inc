.ifndef TEXT_AREA_INC
.define TEXT_AREA_INC 1

.SEGMENT "CODE"

.define TA_SCROLL_BACKFILL_ENABLED       %10000000 ; when scrolling, backfill
.define TA_SCROLL_SAVE_DISCARDED_ENABLED %01000000 ; when scrolling, save discarded
.define TA_SCROLL_JUST_SCROLL            %00000000

.define CURSOR_FLAG_WRAP_SAME_LINE        %10000000
.define CURSOR_FLAG_WRAP_DIFF_LINE        %00000000
.define CURSOR_FLAG_ENABLED               %10000000
.define CURSOR_FLAG_DISABLED              %00000000
.define CURSOR_BEHAVIOR_WRAP_CHANGE_LINES %10000000
.define CURSOR_BEHAVIOR_WRAP_SAME_LINE    %00000000

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
  cursor_row_scr_ptr    .word
  first_row_scr_row_ptr .word
  last_row_scr_row_ptr  .word
.endstruct

.endif
