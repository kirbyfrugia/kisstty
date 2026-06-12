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
.setcpu "6502"
.include "common.inc"
.include "config.inc"
.include "macros.inc"
.include "main_output.inc"
.include "terminal.inc"
.include "textarea.inc"

.import cfg_saved_config
.import copy_buffer40
.import copy_buffer40_size

.segment "CODE"
MARGIN_LEFT = 1
WIDTH       = 38
HEIGHT      = 18
SIZE        = WIDTH*HEIGHT

; initializes the text output area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mo_init:
  lda #0
;  sta full_flag
  sta mo_metadata+TextArea::cursorx
  sta mo_metadata+TextArea::cursory
  sta mo_metadata+TextArea::cursor_line_scr_ptr
  sta mo_metadata+TextArea::cursor_line_scr_ptr+1

  ;lda #TA_TYPE_OUTPUT
  lda #TA_TYPE_INPUT
  sta mo_metadata+TextArea::type

  MARGIN_TOP .set 1
  lda #<(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  clc
  adc SCR_PTR_LO
  sta mo_metadata+TextArea::first_line_scr_ptr
  lda #>(MARGIN_TOP*SCREEN_WIDTH+MARGIN_LEFT)
  adc SCR_PTR_HI
  sta mo_metadata+TextArea::first_line_scr_ptr+1

  lda #WIDTH
  sta mo_metadata+TextArea::width
  lda #HEIGHT
  sta mo_metadata+TextArea::height
  lda #<SIZE
  sta mo_metadata+TextArea::size
  lda #>SIZE
  sta mo_metadata+TextArea::size+1
  lda #(WIDTH-1)
  sta mo_metadata+TextArea::cursor_maxx
  lda #(HEIGHT-1)
  sta mo_metadata+TextArea::cursor_maxy

  lda #<mo_data
  sta mo_metadata+TextArea::first_line_data_ptr
  lda #>mo_data
  sta mo_metadata+TextArea::first_line_data_ptr+1

  lda #<mo_metadata
  sta CMDDATA0
  lda #>mo_metadata
  sta CMDDATA1
  jsr ta_set_context
  jsr ta_init_textarea
  jsr ta_shift_clear

  rts

int_set_mo_active:
  lda CMDDATA0
  pha
  lda CMDDATA1
  pha
  lda #<mo_metadata
  sta CMDDATA0
  lda #>mo_metadata
  sta CMDDATA1
  jsr ta_set_context
  pla
  sta CMDDATA1
  pla
  sta CMDDATA0
  rts

mo_repaint:
  jsr int_set_mo_active
  jsr ta_repaint
  rts

mo_reset:
;  lda #0
;  sta full_flag

  jsr int_set_mo_active
  jsr ta_shift_clear
@reset_done:
  rts

;;TODO: be smarter about repainting the text areas. Only
;;      repaint the areas that changed.
;;      If scroll, repaint all.
;;      If data added to a text area, repaint it.
;
;;THOUGHT:
;;pre-emptively scroll however much we need to scroll. Then
;;But does that actually help???
;      
;.macro scroll_up area_num, backfill_data
;  lda CMDDATA0
;  pha
;  lda CMDDATA1
;  pha
;  lda #<backfill_data
;  sta CMDDATA0
;  lda #>backfill_data
;  sta CMDDATA1
;  lda #1
;  sta CMDDATA4
;  lda #TA_SCROLL_BACKFILL_ENABLED
;  sta CMDDATA5
;  jsr ta_out_scroll_up
;  pla
;  sta CMDDATA1
;  pla
;  sta CMDDATA0
;.endmacro
;
;.macro append_to_area area_full_flag, jmp_if_done, branch_if_overflow
;  .local area_full
;  .local nowrap
;  jsr ta_out_append_chars
;  bcs area_full
;  jmp jmp_if_done ; area not full, so done
;area_full:
;  lda full_flag
;  ora #area_full_flag
;  sta full_flag
;
;  ; move the ptr to the next data to write
;  lda CMDDATA0
;  clc
;  adc CMDDATA3
;  sta CMDDATA0
;  bcc nowrap
;  inc CMDDATA1
;nowrap:
;  lda CMDDATA2
;  bne branch_if_overflow
;  jmp jmp_if_done ; wrote all chars, so done
;.endmacro
;
;; appends N chars to the output
;;
;; warn: you should make sure the input and
;;       output lines are the same length
;;
;; inputs:
;;   CMDDATA0/1 - pointer to the data to append
;;   CMDDATA2   - num chars to append
;; modifies:
;;   CMDDATA0/1/2
;mo_append_chars:
;  ; basic algorithm:
;  ; is there space remaining in the top area?
;  ;   yes, fill what we can. if 
;  ;   no, go to next text area.
;  lda full_flag
;  and #FULL_FLAG_AREA0
;  bne mi_is_full
;  jmp mac_mi
;mi_is_full:
;  lda full_flag
;  and #FULL_FLAG_AREA1
;  bne area1_is_full
;  jmp mac_area1
;area1_is_full:
;  lda full_flag
;  and #FULL_FLAG_AREA2
;  bne area2_is_full
;  jmp mac_area2
;area2_is_full:
;  lda cfg_saved_config+Config::mode
;  cmp #TERMINAL_MODE::LINE
;  beq all_are_full
;  lda full_flag
;  and #FULL_FLAG_AREAE
;  bne all_are_full
;  jmp mac_areaE
;all_are_full:
;  jmp mac_all_overflowed
;mac_mi:
;  jsr int_set_mi_active
;  append_to_area FULL_FLAG_AREA0, mac_done, mac_area1
;mac_area1:
;  jsr int_set_area1_active
;  append_to_area FULL_FLAG_AREA1, mac_done, mac_area2
;mac_area2:
;  jsr int_set_area2_active
;mac_area2_already_active:
;  append_to_area FULL_FLAG_AREA2, mac_done, mac_area2_overflowed
;mac_area2_overflowed:
;  lda cfg_saved_config+Config::mode
;  cmp #TERMINAL_MODE::CHAR
;  bne mac_all_overflowed
;mac_areaE:
;  jsr int_set_areaE_active
;mac_areaE_already_active:
;  append_to_area FULL_FLAG_AREAE, mac_done, mac_all_overflowed
;mac_all_overflowed:
;  jsr int_set_mi_active
;  scroll_up "0", area1_data
;  jsr int_set_area1_active
;  scroll_up "1", area2_data
;  lda cfg_saved_config+Config::mode
;  cmp #TERMINAL_MODE::CHAR
;  beq mac_scroll_char_mode
;  jsr int_set_area2_active
;  scroll_up "2", new_line
;  jsr ta_out_move_cursor_to_start_of_last_line
;  lda full_flag
;  eor #FULL_FLAG_AREA2
;  sta full_flag
;  jmp mac_area2_already_active
;mac_scroll_char_mode:
;  jsr int_set_area2_active
;  scroll_up "2", areaE_data
;  jsr int_set_areaE_active
;  scroll_up "E", new_line
;  jsr ta_out_move_cursor_to_start_of_last_line
;  lda full_flag
;  eor #FULL_FLAG_AREAE
;  sta full_flag
;  jmp mac_areaE_already_active
;mac_scroll_done:
;mac_done:
;  jsr ta_pop_context
;  rts

; appends the char to the output area, scrolling
; if needed. eol handled appropriately
; inputs:
;   CMDDATA0 - the char
mo_append_char:
  jsr int_set_mo_active
  jsr ta_out_append_char
  rts

; inputs:
;   CMDDATA0/1 - pointer to the data to append
;   CMDDATA2/3 - num chars to append
mo_append_chars:
;  jsr int_set_mo_active
;  jsr ta_add_chars
  rts

mo_metadata: .tag TextArea
mo_data:     .res SIZE

new_line: .repeat SCREEN_WIDTH, I
             .byte ' '
           .endrepeat
