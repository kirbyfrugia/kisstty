; TODO: some of this should move to terminal.s or elsewhere. It's a bit
; weird for the output to manage the input...
;
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
; main_output keeps track of where text goes across the areas when it
; overflows. For example, until we've reached the bottom of the upper
; text area, text is just drawn in that area.
;
; So once we've reach the bottom, the output always scrolls.
;
; Users only interact with the input text area. The input area can
; be in one of two modes. In line mode, users interact with it until
; they are done. They then hit return to accept their input.
;
; In other modes, the input area is a single line. The cursor doesn't
; move
;
.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"
.INCLUDE "textarea.inc"

.IMPORT copy_buffer40
.IMPORT copy_buffer40_size
.IMPORT ta_append_chars_fast
.IMPORT ta_init_textarea
.IMPORT ta_set_context
.IMPORT ta_push_context
.IMPORT ta_pop_context
.IMPORT ta_repaint
.IMPORT ta_move_cursor_to_start_of_last_line
.IMPORT ta_shift_clear
.IMPORT ta_scroll_up
.EXPORT mo_init
.EXPORT mo_append_chars
.EXPORT mo_repaint

.SEGMENT "ZEROPAGE"
mo_data_ptr_lo:     .res 1
mo_data_ptr_hi:     .res 1

.SEGMENT "CODE"
.define MARGIN_LEFT   1
.define WIDTH         38
.define HEIGHT        6
.define SIZE          WIDTH * HEIGHT

OVERFLOW_FLAG_AREA0 = %10000000
OVERFLOW_FLAG_AREA1 = %01000000
OVERFLOW_FLAG_AREA2 = %00100000
; initializes the text output area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mo_init:
  lda #0
  sta overflow_flag
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

  rts

int_set_area0_active:
  lda #<area0_metadata
  sta CMDDATA0
  lda #>area0_metadata
  sta CMDDATA1
  jsr ta_set_context
  rts

int_set_area1_active:
  lda #<area1_metadata
  sta CMDDATA0
  lda #>area1_metadata
  sta CMDDATA1
  jsr ta_set_context
  rts

int_set_area2_active:
  lda #<area2_metadata
  sta CMDDATA0
  lda #>area2_metadata
  sta CMDDATA1
  jsr ta_set_context
  rts

mo_repaint:
  jsr ta_push_context
  jsr int_set_area0_active
  jsr ta_repaint
  jsr int_set_area1_active
  jsr ta_repaint
  jsr int_set_area2_active
  jsr ta_repaint
  jsr ta_pop_context
  rts

.macro append_chars area_num, metadata, next_jmp
  lda chars_remaining
  bne @chars_left
  jmp mac_done
@chars_left:
  lda metadata+TextArea::size
  sec
  sbc metadata+TextArea::cursorpos
  sta space_remaining
  min8 space_remaining, chars_remaining, chars_added

  lda chars_added
  cmp space_remaining
  bcc @no_overflow
  lda overflow_flag
  ora #.ident(.concat("OVERFLOW_FLAG_AREA",area_num))
  sta overflow_flag
@no_overflow:
  lda mo_data_ptr_lo
  sta CMDDATA0
  lda mo_data_ptr_hi
  sta CMDDATA1
  lda chars_added
  sta CMDDATA2

  jsr ta_append_chars_fast
 
  lda chars_remaining
  sec
  sbc chars_added
  sta chars_remaining
  bne @more_to_do
  jmp mac_done
@more_to_do:
  lda mo_data_ptr_lo
  clc
  adc chars_added
  sta mo_data_ptr_lo
  bcc next_jmp
  inc mo_data_ptr_hi
.endmacro

.macro scroll_up area_num, backfill_data
  lda #<backfill_data
  sta CMDDATA0
  lda #>backfill_data
  sta CMDDATA1
  lda #1
  sta CMDDATA4
  lda #TA_SCROLL_BACKFILL_ENABLED
  sta CMDDATA5
  jsr ta_scroll_up
.endmacro

; appends N chars to the output
;
; warn: you should make sure the input and
;       output lines are the same length
;
; inputs:
;   CMDDATA0/1 - pointer to the data to append
;   CMDDATA2   - num chars to append
mo_append_chars:
  jsr ta_push_context
  lda CMDDATA0
  sta mo_data_ptr_lo
  lda CMDDATA1
  sta mo_data_ptr_hi
  lda CMDDATA2
  sta chars_remaining
  lda #0
  sta chars_added

  ; basic algorithm:
  ; is there space remaining in the top area?
  ;   yes, fill what we can. if 
  ;   no, go to next text area.
  ; first see if there's space remaining in the upper
  ; text area. If so, how much?

  ; TODO: make sure the text area always updates the
  ;       cursor position, and efficiently

  lda overflow_flag
  and #OVERFLOW_FLAG_AREA0
  bne mac_check_area1
  jmp mac_area0
mac_check_area1:
  lda overflow_flag
  and #OVERFLOW_FLAG_AREA1
  bne mac_check_area2
  jmp mac_area1
mac_check_area2:
  lda overflow_flag
  and #OVERFLOW_FLAG_AREA2
  bne mac_gotta_scroll
  jmp mac_area2
mac_gotta_scroll:
  jmp mac_scroll
mac_area0:
  jsr int_set_area0_active
  append_chars "0", area0_metadata, mac_area1
mac_area1:
  jsr int_set_area1_active
  append_chars "1", area1_metadata, mac_area2
mac_area2:
  jsr int_set_area2_active
mac_area2_already_active:
  append_chars "2", area2_metadata, mac_scroll
mac_scroll:
  jsr int_set_area0_active
  scroll_up "0", area1_data
  jsr int_set_area1_active
  scroll_up "1", area2_data
  jsr int_set_area2_active
  scroll_up "2", new_line

  jsr ta_move_cursor_to_start_of_last_line

  lda overflow_flag
  eor #OVERFLOW_FLAG_AREA2
  sta overflow_flag
  jmp mac_area2_already_active
mac_done:
  jsr ta_pop_context
  rts


chars_remaining:            .res 1
space_remaining:            .res 1
chars_added:                .res 1
overflow_flag:              .res 1

area0_metadata:             .tag TextArea
area0_data:                 .res SIZE

area1_metadata:             .tag TextArea
area1_data:                 .res SIZE

area2_metadata:             .tag TextArea
area2_data:                 .res SIZE

new_line: .repeat SCREEN_WIDTH, I
             .byte ' '
           .endrepeat
