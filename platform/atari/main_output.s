; A screen is made up of multiple output text areas and a single input
; text area. In some cases, we have a single line input (e.g. char mode)
; and in others we have a multi-line input.
;
; The screen uses multiple output text areas to keep their size below 256
; bytes Each text area has its own cursor, but it isn't visible in output
; text areas. The cursor is used to know where to insert text, even
; if it is not visible.
;
; main_output is responsible for managing flow between the text areas.
; For example, if we receive text over serial, that text goes to the
; upper left of the upper text area. It keeps getting added to that text
; area until it overflows. At that point, new text goes to the next
; output text area downwards.
;
; Once text reaches the bottom right of the bottom text area, all output
; text areas scroll upwards and a new line is added at the bottom. The
; cursor moves to the start of that line and we continue.
;
; Users only interact with the input text area. The input area can
; be in one of two modes. In line mode, users interact with it until
; they are done. They then hit return to accept their input.
;
; If it's line mode, there are 4 lines of text at the bottom and
; only have three output text areas active. If it's char mode,
; there is only one line of text at the bottom and we have the
; "EXTRA" text area in use.
;
.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"
.INCLUDE "terminal.inc"
.INCLUDE "textarea.inc"

.IMPORT cfg_saved_config
.IMPORT copy_buffer40
.IMPORT copy_buffer40_size
.IMPORT ta_append_chars
.IMPORT ta_init_textarea
.IMPORT ta_set_context
.IMPORT ta_push_context
.IMPORT ta_pop_context
.IMPORT ta_move_cursor_to_start_of_last_line
.IMPORT ta_repaint
.IMPORT ta_shift_clear
.IMPORT ta_scroll_up
.EXPORT mo_init
.EXPORT mo_append_chars
.EXPORT mo_repaint
.EXPORT mo_reset

.SEGMENT "CODE"
.define MARGIN_LEFT       1
.define WIDTH             38
.define AREA_HEIGHT_TOP3  6
.define AREA_SIZE_TOP3    WIDTH * AREA_HEIGHT_TOP3
.define AREA_HEIGHT_EXTRA 3
.define AREA_SIZE_EXTRA   WIDTH * AREA_HEIGHT_EXTRA

FULL_FLAG_AREA0 = %10000000
FULL_FLAG_AREA1 = %01000000
FULL_FLAG_AREA2 = %00100000
FULL_FLAG_AREAE = %00010000
; initializes the text output area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mo_init:
  lda #0
  sta full_flag
  sta area0_metadata+TextArea::cursorx
  sta area0_metadata+TextArea::cursory
  sta area0_metadata+TextArea::cursorpos
  sta area1_metadata+TextArea::cursorx
  sta area1_metadata+TextArea::cursory
  sta area1_metadata+TextArea::cursorpos
  sta area2_metadata+TextArea::cursorx
  sta area2_metadata+TextArea::cursory
  sta area2_metadata+TextArea::cursorpos
  sta areaE_metadata+TextArea::cursorx
  sta areaE_metadata+TextArea::cursory
  sta areaE_metadata+TextArea::cursorpos

  lda #CURSOR_FLAG_DISABLED
  sta area0_metadata+TextArea::use_cursor
  sta area1_metadata+TextArea::use_cursor
  sta area2_metadata+TextArea::use_cursor
  sta areaE_metadata+TextArea::use_cursor

  MARGIN_TOP .set 1
  lda #MARGIN_TOP
  sta area0_metadata+TextArea::margin_top
  lda #<(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  clc
  adc SCR_PTR_LO
  sta area0_metadata+TextArea::first_row_scr_ptr
  lda #>(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  adc SCR_PTR_HI
  sta area0_metadata+TextArea::first_row_scr_ptr+1

  MARGIN_TOP .set 7
  lda #MARGIN_TOP
  sta area1_metadata+TextArea::margin_top
  lda #<(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  clc
  adc SCR_PTR_LO
  sta area1_metadata+TextArea::first_row_scr_ptr
  lda #>(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  adc SCR_PTR_HI
  sta area1_metadata+TextArea::first_row_scr_ptr+1

  MARGIN_TOP .set 13
  lda #MARGIN_TOP
  sta area2_metadata+TextArea::margin_top
  lda #<(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  clc
  adc SCR_PTR_LO
  sta area2_metadata+TextArea::first_row_scr_ptr
  lda #>(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  adc SCR_PTR_HI
  sta area2_metadata+TextArea::first_row_scr_ptr+1

  MARGIN_TOP .set 19
  lda #MARGIN_TOP
  sta areaE_metadata+TextArea::margin_top
  lda #<(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  clc
  adc SCR_PTR_LO
  sta areaE_metadata+TextArea::first_row_scr_ptr
  lda #>(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  adc SCR_PTR_HI
  sta areaE_metadata+TextArea::first_row_scr_ptr+1

  lda #MARGIN_LEFT
  sta area0_metadata+TextArea::margin_left
  sta area1_metadata+TextArea::margin_left
  sta area2_metadata+TextArea::margin_left
  sta areaE_metadata+TextArea::margin_left

  lda #WIDTH
  sta area0_metadata+TextArea::width
  sta area1_metadata+TextArea::width
  sta area2_metadata+TextArea::width
  sta areaE_metadata+TextArea::width

  lda #AREA_HEIGHT_TOP3
  sta area0_metadata+TextArea::height
  sta area1_metadata+TextArea::height
  sta area2_metadata+TextArea::height
  lda #AREA_HEIGHT_EXTRA
  sta areaE_metadata+TextArea::height

  lda #AREA_SIZE_TOP3
  sta area0_metadata+TextArea::size
  sta area1_metadata+TextArea::size
  sta area2_metadata+TextArea::size
  lda #AREA_SIZE_EXTRA
  sta areaE_metadata+TextArea::size

  lda #(WIDTH-1)
  sta area0_metadata+TextArea::cursor_maxx
  sta area1_metadata+TextArea::cursor_maxx
  sta area2_metadata+TextArea::cursor_maxx
  sta areaE_metadata+TextArea::cursor_maxx

  lda #(AREA_HEIGHT_TOP3-1)
  sta area0_metadata+TextArea::cursor_maxy
  sta area1_metadata+TextArea::cursor_maxy
  sta area2_metadata+TextArea::cursor_maxy
  lda #(AREA_HEIGHT_EXTRA-1)
  sta areaE_metadata+TextArea::cursor_maxy

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
  lda #<areaE_data
  sta areaE_metadata+TextArea::first_row_data_ptr
  lda #>areaE_data
  sta areaE_metadata+TextArea::first_row_data_ptr+1

  ldy #0
  lda #' '
@top3_loop:
  sta area0_data,y
  sta area1_data,y
  sta area2_data,y
  iny
  cpy #AREA_SIZE_TOP3
  bne @top3_loop

  ldy #0
  lda #' '
@extra_loop:
  sta areaE_data,y
  iny
  cpy #AREA_SIZE_EXTRA
  bne @extra_loop


  lda #<area0_metadata
  sta CMDDATA0
  lda #>area0_metadata
  sta CMDDATA1
  jsr ta_set_context
  jsr ta_init_textarea

  lda #<area1_metadata
  sta CMDDATA0
  lda #>area1_metadata
  sta CMDDATA1
  jsr ta_set_context
  jsr ta_init_textarea

  lda #<area2_metadata
  sta CMDDATA0
  lda #>area2_metadata
  sta CMDDATA1
  jsr ta_set_context
  jsr ta_init_textarea

  lda #<areaE_metadata
  sta CMDDATA0
  lda #>areaE_metadata
  sta CMDDATA1
  jsr ta_set_context
  jsr ta_init_textarea

  rts

int_set_area0_active:
  lda CMDDATA0
  pha
  lda CMDDATA1
  pha
  lda #<area0_metadata
  sta CMDDATA0
  lda #>area0_metadata
  sta CMDDATA1
  jsr ta_set_context
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
  rts

int_set_area1_active:
  lda CMDDATA0
  pha
  lda CMDDATA1
  pha
  lda #<area1_metadata
  sta CMDDATA0
  lda #>area1_metadata
  sta CMDDATA1
  jsr ta_set_context
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
  rts

int_set_area2_active:
  lda CMDDATA0
  pha
  lda CMDDATA1
  pha
  lda #<area2_metadata
  sta CMDDATA0
  lda #>area2_metadata
  sta CMDDATA1
  jsr ta_set_context
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
  rts

int_set_areaE_active:
  lda CMDDATA0
  pha
  lda CMDDATA1
  pha
  lda #<areaE_metadata
  sta CMDDATA0
  lda #>areaE_metadata
  sta CMDDATA1
  jsr ta_set_context
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
  rts

mo_repaint:
  jsr int_set_area0_active
  jsr ta_repaint
  jsr int_set_area1_active
  jsr ta_repaint
  jsr int_set_area2_active
  jsr ta_repaint

  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::LINE
  beq @repaint_done
  jsr int_set_areaE_active
  jsr ta_repaint
@repaint_done:
  rts

mo_reset:
  lda #0
  sta full_flag

  jsr int_set_area0_active
  jsr ta_shift_clear
  jsr int_set_area1_active
  jsr ta_shift_clear
  jsr int_set_area2_active
  jsr ta_shift_clear

  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::LINE
  beq @reset_done
  jsr int_set_areaE_active
  jsr ta_shift_clear
@reset_done:
  rts

;TODO: be smarter about repainting the text areas. Only
;      repaint the areas that changed.
;      If scroll, repaint all.
;      If data added to a text area, repaint it.
      
.macro scroll_up area_num, backfill_data
  lda CMDDATA0
  pha
  lda CMDDATA1
  pha
  lda #<backfill_data
  sta CMDDATA0
  lda #>backfill_data
  sta CMDDATA1
  lda #1
  sta CMDDATA4
  lda #TA_SCROLL_BACKFILL_ENABLED
  sta CMDDATA5
  jsr ta_scroll_up
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
.endmacro

.macro append_to_area area_full_flag, jmp_if_done, branch_if_overflow
  .local area_full
  .local nowrap
  jsr ta_append_chars
  bcs area_full
  jmp jmp_if_done ; area not full, so done
area_full:
  lda full_flag
  ora #area_full_flag
  sta full_flag

  ; move the ptr to the next data to write
  lda CMDDATA0
  clc
  adc CMDDATA3
  sta CMDDATA0
  bcc nowrap
  inc CMDDATA1
nowrap:
  lda CMDDATA2
  bne branch_if_overflow
  jmp jmp_if_done ; wrote all chars, so done
.endmacro

; appends N chars to the output
;
; warn: you should make sure the input and
;       output lines are the same length
;
; inputs:
;   CMDDATA0/1 - pointer to the data to append
;   CMDDATA2   - num chars to append
; modifies:
;   CMDDATA0/1/2
mo_append_chars:
  ; basic algorithm:
  ; is there space remaining in the top area?
  ;   yes, fill what we can. if 
  ;   no, go to next text area.
  lda full_flag
  and #FULL_FLAG_AREA0
  bne area0_is_full
  jmp mac_area0
area0_is_full:
  lda full_flag
  and #FULL_FLAG_AREA1
  bne area1_is_full
  jmp mac_area1
area1_is_full:
  lda full_flag
  and #FULL_FLAG_AREA2
  bne area2_is_full
  jmp mac_area2
area2_is_full:
  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::LINE
  beq all_are_full
  lda full_flag
  and #FULL_FLAG_AREAE
  bne all_are_full
  jmp mac_areaE
all_are_full:
  jmp mac_all_overflowed
mac_area0:
  jsr int_set_area0_active
  append_to_area FULL_FLAG_AREA0, mac_done, mac_area1
mac_area1:
  jsr int_set_area1_active
  append_to_area FULL_FLAG_AREA1, mac_done, mac_area2
mac_area2:
  jsr int_set_area2_active
mac_area2_already_active:
  append_to_area FULL_FLAG_AREA2, mac_done, mac_area2_overflowed
mac_area2_overflowed:
  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::CHAR
  bne mac_all_overflowed
mac_areaE:
  jsr int_set_areaE_active
mac_areaE_already_active:
  append_to_area FULL_FLAG_AREAE, mac_done, mac_all_overflowed
mac_all_overflowed:
  jsr int_set_area0_active
  scroll_up "0", area1_data
  jsr int_set_area1_active
  scroll_up "1", area2_data
  lda cfg_saved_config+Config::mode
  cmp #TERMINAL_MODE::CHAR
  beq mac_scroll_char_mode
  jsr int_set_area2_active
  scroll_up "2", new_line
  jsr ta_move_cursor_to_start_of_last_line
  lda full_flag
  eor #FULL_FLAG_AREA2
  sta full_flag
  jmp mac_area2_already_active
mac_scroll_char_mode:
  jsr int_set_area2_active
  scroll_up "2", areaE_data
  jsr int_set_areaE_active
  scroll_up "E", new_line
  jsr ta_move_cursor_to_start_of_last_line
  lda full_flag
  eor #FULL_FLAG_AREAE
  sta full_flag
  jmp mac_areaE_already_active
mac_scroll_done:
mac_done:
  jsr ta_pop_context
  rts

full_flag:                  .res 1

area0_metadata:             .tag TextArea
area0_data:                 .res AREA_SIZE_TOP3

area1_metadata:             .tag TextArea
area1_data:                 .res AREA_SIZE_TOP3

area2_metadata:             .tag TextArea
area2_data:                 .res AREA_SIZE_TOP3

areaE_metadata:             .tag TextArea
areaE_data:                 .res AREA_SIZE_EXTRA

new_line: .repeat SCREEN_WIDTH, I
             .byte ' '
           .endrepeat
