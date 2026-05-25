.ifndef TEXT_AREA_INC
TEXT_AREA_INC = 1

.struct TextArea
  data_ptr                  .word ; INPUTS_DATA_PTR_OFFSET            = 0
  scr_row_ptr_table_lo      .word ; INPUTS_SCR_ROWS_PTR_LOC_LO_OFFSET = 2
  scr_row_ptr_table_hi      .word ; INPUTS_SCR_ROWS_PTR_LOC_HI_OFFSET = 4
  margin_left               .byte ; INPUTS_MARGIN_LEFT_OFFSET         = 6
  margin_top                .byte ; INPUTS_MARGIN_TOP_OFFSET          = 7
  width                     .byte ; INPUTS_WIDTH_OFFSET               = 8
  height                    .byte ; INPUTS_HEIGHT_OFFSET              = 9
  size                      .byte ; INPUTS_SIZE_OFFSET                = 10
  cursorx                   .byte ; INPUTS_CURSORX_OFFSET             = 11
  cursory                   .byte ; INPUTS_CURSORY_OFFSET             = 12
  cursor_maxx               .byte ; INPUTS_CURSOR_MAXX_OFFSET         = 13
  cursor_maxy               .byte ; INPUTS_CURSOR_MAXY_OFFSET         = 14
  cursorpos                 .byte ; INPUTS_CURSORPOS_OFFSET           = 15
  cursor_scr_row_ptr        .word ; INPUTS_CURSOR_SCR_ROW_PTR         = 16 ; and 17
.endstruct

.endif
