.ifndef TEXT_AREA_INC
TEXT_AREA_INC = 1

; get the current metadata_ptr from the text area
; and push it to the stack
.macro save_metadata_ptr
  lda TA_METADATA_PTR_LO
  pha
  lda TA_METADATA_PTR_HI
  pha
.endmacro

.macro restore_metadata_ptr
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
  jsr ta_set_metadata_ptr
.endmacro

; initializes the data for this text area
.macro ta_init metadata, MARGIN_TOP, MARGIN_LEFT, WIDTH, HEIGHT, USE_CURSOR
  SIZE = WIDTH * HEIGHT

  lda #0
  sta metadata+TextArea::cursorx
  sta metadata+TextArea::cursory
  sta metadata+TextArea::cursorpos

  lda #USE_CURSOR
  sta metadata+TextArea::use_cursor

  lda #MARGIN_TOP
  sta metadata+TextArea::margin_top

  lda #MARGIN_LEFT
  sta metadata+TextArea::margin_left

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

  lda SCR_PTR_LO
  clc
  adc #MARGIN_LEFT
  adc #<(MARGIN_TOP*SCREEN_WIDTH)
  sta metadata+TextArea::first_row_scr_ptr_lo
  sta metadata+TextArea::cursor_row_scr_ptr_lo
  lda SCR_PTR_HI
  adc #>(MARGIN_TOP*SCREEN_WIDTH)
  sta metadata+TextArea::first_row_scr_ptr_hi
  sta metadata+TextArea::cursor_row_scr_ptr_hi

  lda metadata+TextArea::first_row_scr_ptr_lo
  clc
  adc #<((HEIGHT-1)*SCREEN_WIDTH)
  sta metadata+TextArea::last_row_scr_ptr_lo
  lda metadata+TextArea::first_row_scr_ptr_hi
  adc #>((HEIGHT-1)*SCREEN_WIDTH)
  sta metadata+TextArea::last_row_scr_ptr_hi

  lda #>data_ptr
  sta CMDDATA5
  lda #<data_ptr
  sta CMDDATA4
  clc
  adc #<((HEIGHT-1)*WIDTH)
  sta CMDDATA6
  lda CMDDATA5
  adc #>((HEIGHT-1)*WIDTH)
  sta CMDDATA7
.endmacro

.struct TextArea
  first_row_data_ptr_lo  .byte
  first_row_data_ptr_hi  .byte
  cursor_row_data_ptr_lo .byte
  cursor_row_data_ptr_hi .byte
  last_row_data_ptr_lo   .byte
  last_row_data_ptr_hi   .byte
  first_row_scr_ptr_lo   .byte
  first_row_scr_ptr_hi   .byte
  cursor_row_scr_ptr_lo  .byte
  cursor_row_scr_ptr_hi  .byte
  last_row_scr_ptr_lo    .byte
  last_row_scr_ptr_hi    .byte
  margin_left            .byte
  margin_top             .byte
  width                  .byte
  height                 .byte
  size                   .byte
  cursorx                .byte
  cursory                .byte
  cursor_maxx            .byte
  cursor_maxy            .byte
  cursorpos              .byte
  use_cursor             .byte
.endstruct

.macro ta_prev_data_row_ptr metadata, src_data_row_ptr, dest_data_row_ptr
  lda src_data_row_ptr
  sec
  sbc metadata+TextArea::width
  sta dest_data_row_ptr
  lda src_data_row_ptr+1
  sbc #0
  sta dest_data_row_ptr+1
.endmacro

.macro ta_next_data_row_ptr metadata, src_data_row_ptr, dest_data_row_ptr
  lda src_data_row_ptr
  clc
  adc metadata+TextArea::width
  sta dest_data_row_ptr
  lda src_data_row_ptr+1
  adc #0
  sta dest_data_row_ptr+1
.endmacro

.macro ta_copy_data_row_ptr src_data_row_ptr, dest_data_row_ptr
  lda scr_data_row_ptr
  sta dest_data_row_ptr
  lda scr_data_row_ptr+1
  sta dest_data_row_ptr+1
.endmacro

.endmacro

.endif
