; This implements a text area component with a cursor. 
; You can create your own text areas and can have more than one
; on the screen at a time, each with its own cursor.
;
; It supports readonly and editable.
;
; # About textarea contexts.
;
; The ta_* routines do all operations on a TextArea struct
; in the zero page.
;
; To do operations on your TextArea, you set the context. The
; context is simply a pointer to a text area.
;
; For the purposes of this explanation, there are two contexts to
; keep in mind:
; * Existing context: the context currently applied to the text area
; * New context: the context you are setting for the text area.
;
; When setting the context, the following happens:
; 1. It copies zero page TextArea to existing context ptr
;    location. It copies the full TextArea struct.
; 2. It then copies the new TextArea to the ZP TextArea.
; 3. It then updates its pointer to the location of the new
;    TextArea so that it can do Step (1) if the context
;    is changed again.
;
; There may be times where you want to swap out the existing context,
; set a new context, and swap back in the prior context. For example,
; during scrolling activities, you might want to scroll all the text
; areas up by one and restore the context from prior to the scroll.
;
; Here's How:
; 1. Call ta_push_context, which will save a pointer
;    to the existing TextArea.
; 2. Call ta_set_context, which will update the text area
;    to point to the new location (saving data first)
; 3. Do all your operations.
; 4. Call ta_pop_context, which will restore the context
;    and TextArea from the pushed location.
; Note: it's not actually a stack operation. You can only
;       push and pop one context.
;
; Note: the source only gets updated when a new context is set.
;       However, the cursor data updates any time the cursor
;       changes.
;
.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"
.INCLUDE "textarea.inc"

.IMPORT utils_atascii_to_icode
.IMPORT utils_dump_mem_row
.IMPORT copy_buffer40
.IMPORT copy_buffer40_size
.IMPORT scr_rows_lo,scr_rows_hi
.EXPORT ta_init_context
.EXPORT ta_set_context
.EXPORT ta_push_context
.EXPORT ta_pop_context
.EXPORT ta_init_textarea
.EXPORT ta_move_cursor_up
.EXPORT ta_move_cursor_down
.EXPORT ta_move_cursor_left
.EXPORT ta_move_cursor_right
.EXPORT ta_hide_cursor
.EXPORT ta_show_cursor
.EXPORT ta_typechar
.EXPORT ta_backspace
.EXPORT ta_shift_clear
.EXPORT ta_line_insert
.EXPORT ta_char_insert
.EXPORT ta_line_delete
.EXPORT ta_shift_all_up
.EXPORT ta_char_delete
.EXPORT ta_append_chars_fast
.EXPORT ta_scroll_up
.EXPORT ta_repaint
.EXPORT ta_move_cursor_to_start_of_last_line

.segment "ZEROPAGE"
context_ptr_lo:       .res 1
context_ptr_hi:       .res 1
context_ptr_saved_lo: .res 1
context_ptr_saved_hi: .res 1
scr_row_ptr_lo:       .res 1
scr_row_ptr_hi:       .res 1
data_ptr_lo:          .res 1
data_ptr_hi:          .res 1
local_metadata:       .tag TextArea

.segment "CODE"
first_row_data_ptr_lo    = local_metadata+TextArea::first_row_data_ptr
first_row_data_ptr_hi    = local_metadata+TextArea::first_row_data_ptr+1
first_row_scr_ptr_lo     = local_metadata+TextArea::first_row_scr_ptr
first_row_scr_ptr_hi     = local_metadata+TextArea::first_row_scr_ptr+1
cursor_scr_ptr_lo        = local_metadata+TextArea::cursor_scr_ptr
cursor_scr_ptr_hi        = local_metadata+TextArea::cursor_scr_ptr+1


ta_init_context:
  lda #0
  sta context_ptr_lo
  sta context_ptr_hi
  sta context_ptr_saved_lo
  sta context_ptr_saved_hi
  rts

; sets the context for the text area to the TextArea
; pointed to by CMDDATA0/1. Make sure that you called
; ta_init_context first or you might get some garbage.
;
; inputs:
;   CMDDATA0/1 - pointer to a text area
ta_set_context:
  lda context_ptr_hi
  bne cache_exists
  lda context_ptr_lo
  beq no_cache
cache_exists:
  ; copy our local cache to the existing source TextArea
  copy_struct_abs_to_zp local_metadata, context_ptr_lo, TextArea
no_cache:
  ; update our pointer to the new text area
  lda CMDDATA0
  sta context_ptr_lo
  lda CMDDATA1
  sta context_ptr_hi

  ; copy data from the new TextArea to the local cache in
  ; the zero page.
  copy_struct_zp_to_abs context_ptr_lo, local_metadata, TextArea
  rts

; saves the existing context ptr so that it can
; be reused. First updates the source TextArea with
; what is currently in the cache. Make sure there's
; actually a context set before doing this.
ta_push_context:
  pha
  txa
  pha
  tya
  pha
  copy_struct_abs_to_zp local_metadata, context_ptr_lo, TextArea
  lda context_ptr_lo
  sta context_ptr_saved_lo
  lda context_ptr_hi
  sta context_ptr_saved_hi
  pla
  tay
  pla
  tax
  pla
  rts

; restores pushed context to the local cache. Updates
; the context pointer and the cached data.
ta_pop_context:
  pha
  txa
  pha
  tya
  pha
  copy_struct_abs_to_zp local_metadata, context_ptr_lo, TextArea
  copy_struct_zp_to_abs context_ptr_saved_lo, local_metadata, TextArea
  lda context_ptr_saved_lo
  sta context_ptr_lo
  lda context_ptr_saved_hi
  sta context_ptr_hi
  pla
  tay
  pla
  tax
  pla
  rts

; initializes a text area, sets appropriate screen pointers
;
; assumes:
;   SCR_PTR_LO already set
ta_init_textarea:
  jsr int_update_cursor_pos
  jsr ta_repaint
  jsr ta_show_cursor
  rts

; flush cursor to backing store
int_flush_cursor:
  ldy #TextArea::cursorx
  lda local_metadata+TextArea::cursorx
  sta (context_ptr_lo),y
  ldy #TextArea::cursory
  lda local_metadata+TextArea::cursory
  sta (context_ptr_lo),y
  ldy #TextArea::cursorpos
  lda local_metadata+TextArea::cursorpos
  sta (context_ptr_lo),y
  ldy #TextArea::cursor_scr_ptr
  lda cursor_scr_ptr_lo
  sta (context_ptr_lo),y
  iny
  lda cursor_scr_ptr_hi
  sta (context_ptr_lo),y
  rts

; internal use only, updates the local cursor pos
; given the current cursor x and y
int_update_cursor_pos:
  lda #0
  tax
@data_loop:
  cpx local_metadata+TextArea::cursory
  beq @data_loop_done
  clc
  adc local_metadata+TextArea::width
  inx
  bne @data_loop
@data_loop_done:
  clc
  adc local_metadata+TextArea::cursorx
  sta local_metadata+TextArea::cursorpos

  ; now do the cursor_ptr in screen coords
  lda first_row_scr_ptr_lo
  clc
  adc local_metadata+TextArea::cursorx
  sta cursor_scr_ptr_lo
  lda first_row_scr_ptr_hi
  adc #0
  sta cursor_scr_ptr_hi

  ldy local_metadata+TextArea::cursory
  beq @done
@row_loop:
  lda cursor_scr_ptr_lo
  clc
  adc #SCREEN_WIDTH
  sta cursor_scr_ptr_lo
  bcc @nowrap
  inc cursor_scr_ptr_hi
@nowrap:
  dey
  bne @row_loop
@done:
  jsr int_flush_cursor
  rts

; internal use only, updates the cursor x/y
; given the current cursorpos
int_update_cursor_xy:
  lda local_metadata+TextArea::cursorpos
  ldx local_metadata+TextArea::width
  ldy #0
@div_loop:
  cmp local_metadata+TextArea::width
  bcc @div_done
  sec
  sbc local_metadata+TextArea::width
  iny
  bne @div_loop
@div_done:
  sta local_metadata+TextArea::cursorx
  sty local_metadata+TextArea::cursory
  rts


ta_hide_cursor:
  lda local_metadata+TextArea::use_cursor
  beq @done

  ldy #0
  lda (cursor_scr_ptr_lo),y
  and #%01111111
  sta (cursor_scr_ptr_lo),y
@done:
  rts

ta_show_cursor:
  lda local_metadata+TextArea::use_cursor
  beq @done

  ldy #0
  lda (cursor_scr_ptr_lo),y
  ora #%10000000
  sta (cursor_scr_ptr_lo),y
@done:
  rts

ta_move_cursor_up:
  jsr ta_hide_cursor

  lda local_metadata+TextArea::cursory
  beq @wrapped
  dec local_metadata+TextArea::cursory
  jmp @updated
@wrapped:
  lda local_metadata+TextArea::cursor_maxy
  sta local_metadata+TextArea::cursory
@updated:
  jsr int_update_cursor_pos
  jsr ta_show_cursor
  rts

ta_move_cursor_down:
  jsr ta_hide_cursor

  lda local_metadata+TextArea::cursory
  cmp local_metadata+TextArea::cursor_maxy
  beq @wrapped

  inc local_metadata+TextArea::cursory
  bne @updated
@wrapped:
  lda #0
  sta local_metadata+TextArea::cursory
@updated:
  jsr int_update_cursor_pos
  jsr ta_show_cursor
  rts

; moves the cursor left if possible.
;
; pass CMDDATA0 to define behavior when we wrap to the left.
; Zero will stay on the same line. Non-zero will move up a line.
; Used when we move the cursor based on arrow keys vs text changes.
;
; inputs:
;   CMDDATA0 - cursor behavior on wrap
ta_move_cursor_left:
  jsr ta_hide_cursor

  lda local_metadata+TextArea::cursorx
  beq @wrapped
  dec local_metadata+TextArea::cursorx
  jmp @updated
@wrapped:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  bit CMDDATA0
  bmi @wrapped_change_lines

  ; if here, just wrap around on the same line
  lda local_metadata+TextArea::cursor_maxx
  sta local_metadata+TextArea::cursorx
  bne @updated
@wrapped_change_lines:
  lda local_metadata+TextArea::cursory
  beq @done ; already at top, just ignore movement

  ; move up a line
  dec local_metadata+TextArea::cursory
  ; and move to the end of it
  lda local_metadata+TextArea::cursor_maxx
  sta local_metadata+TextArea::cursorx
@updated:
  jsr int_update_cursor_pos
@done:
  jsr ta_show_cursor
  rts

ta_move_cursor_right:
  jsr ta_hide_cursor

  lda local_metadata+TextArea::cursorx
  cmp local_metadata+TextArea::cursor_maxx
  beq @wrapped

  inc local_metadata+TextArea::cursorx
  bne @updated
@wrapped:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  bit CMDDATA0
  bmi @wrapped_change_lines

  ; if here, just wrap around on the same line
  lda #0
  sta local_metadata+TextArea::cursorx
  beq @updated
@wrapped_change_lines:
  lda local_metadata+TextArea::cursory
  cmp local_metadata+TextArea::cursor_maxy
  beq @done; already at bottom

  ; move down a line
  inc local_metadata+TextArea::cursory
  ; and move to the start of it
  lda #0
  sta local_metadata+TextArea::cursorx
@updated:
  jsr int_update_cursor_pos
@done:
  jsr ta_show_cursor

  rts

; updates a single character on the screen in
; the current row
int_update_screen_char:
  ldy local_metadata+TextArea::cursorpos
  lda (first_row_data_ptr_lo),y
  jsr utils_atascii_to_icode
  ldy #0
  sta (cursor_scr_ptr_lo),y
  rts

; sets the character at the current cursor location provided in A.
; moves the cursor to the right.
;
; inputs
;   - A the character
ta_typechar:
  ldy local_metadata+TextArea::cursorpos
  sta (first_row_data_ptr_lo),y
  jsr int_update_screen_char
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  sta CMDDATA0
  jsr ta_move_cursor_right
  rts

; erases character under cursor, moves cursor left.
; atari style doesn't shift data left.
ta_backspace:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  sta CMDDATA0
  jsr ta_move_cursor_left
  ldy local_metadata+TextArea::cursorpos
  lda #' '
  sta (first_row_data_ptr_lo),y
  jsr int_update_screen_char
  rts

int_cursor_home:
  lda #0
  sta local_metadata+TextArea::cursorx
  sta local_metadata+TextArea::cursory
  jsr int_update_cursor_pos
  rts

; clears all data between the markers
; inputs:
;   - update_marker_start (position to start)
;   - update_marker_end   (position to end, exclusive)
int_clear_data:
  ldy update_marker_start
@loop:
  lda #' '
  sta (first_row_data_ptr_lo),y
  iny
  cpy update_marker_end
  bne @loop
  rts


; repaints the entire screen area for the input
; box. Useful when data changes. Not so efficient,
; but I'll worry about that later.
ta_repaint:
  lda first_row_scr_ptr_lo
  sta scr_row_ptr_lo
  lda first_row_scr_ptr_hi
  sta scr_row_ptr_hi

  lda first_row_data_ptr_lo
  sta data_ptr_lo
  lda first_row_data_ptr_hi
  sta data_ptr_hi

  ldx #0
@row_loop:
  ldy #0
@col_loop:
  lda (data_ptr_lo),y
  jsr utils_atascii_to_icode
  sta (scr_row_ptr_lo),y
  iny
  cpy local_metadata+TextArea::width
  bne @col_loop
  inx
  cpx local_metadata+TextArea::height
  beq @done
  lda scr_row_ptr_lo
  clc
  adc #SCREEN_WIDTH
  sta scr_row_ptr_lo
  bcc @scr_nowrap
  inc scr_row_ptr_hi
@scr_nowrap: 
  lda data_ptr_lo
  clc
  adc local_metadata+TextArea::width
  sta data_ptr_lo
  bcc @data_nowrap
  inc data_ptr_hi
@data_nowrap:
  jmp @row_loop
@done:
  rts

; clears the data in the current row
int_clear_row_data:
  lda local_metadata+TextArea::cursorpos
  sec
  sbc local_metadata+TextArea::cursorx
  tay
  ldx local_metadata+TextArea::width
  lda #' '
@loop:
  sta (first_row_data_ptr_lo),y
  iny
  dex
  bne @loop
  rts

; just clears the last row of data. useful for scrolling
; or deleting lines
int_clear_last_row_data:
  lda local_metadata+TextArea::size
  sec
  sbc local_metadata+TextArea::width
  tay
  lda #' '
@loop:
  sta (first_row_data_ptr_lo),y
  iny
  cpy local_metadata+TextArea::size
  bne @loop
  rts

; clears all data in the area and returns the cursor home
ta_shift_clear:
  jsr ta_hide_cursor

  lda #0
  sta update_marker_start
  lda local_metadata+TextArea::size
  sta update_marker_end
  jsr int_clear_data

  jsr int_cursor_home
  jsr ta_repaint

  jsr ta_show_cursor
  rts

; shifts all lines from the cursor line downwards
; down by one
int_shift_lines_down:
  ; first find the start of the line we're on
  lda local_metadata+TextArea::cursorpos
  sec
  sbc local_metadata+TextArea::cursorx
  sta move_line_start_line_pos
  lda local_metadata+TextArea::size
  sec
  sbc #1
  sta move_line_cursor_to ; end of last line
  sec
  sbc local_metadata+TextArea::width
  sta move_line_cursor_from ; end of previous line
@loop:
  ldy move_line_cursor_from
  lda (first_row_data_ptr_lo),y
  ldy move_line_cursor_to
  sta (first_row_data_ptr_lo),y

  lda move_line_start_line_pos
  cmp move_line_cursor_from
  beq @done
  dec move_line_cursor_to
  dec move_line_cursor_from
  jmp @loop
@done:
  rts

; scrolls the text area up by the number of lines provided.
; backfills the new rows in the bottom with provided data.
;
; inputs:
;   CMDDATA0/1 - ptr to the data to backfill from
;   CMDDATA2/3 - ptr to mem to save discarded data (set if saving)
;   CMDDATA4   - num lines to scroll
;   CMDDATA5   - scroll flags
;              - TA_SCROLL_BACKFILL_ENABLED - backfills bottom of
;                text area with data from CMDDATA0
;              - TA_SCROLL_SAVE_DISCARDED_ENABLED - saves discarded data
;                from top of text area to CMDDATA2
ta_scroll_up:
  jsr ta_hide_cursor
  ldx CMDDATA4
  ; first let's see how many chars we'll be discarding
  lda #0
@char_loop:
  clc
  adc local_metadata+TextArea::width
  dex
  bne @char_loop
  sta scroll_num_chars_scrolled_off

  ; now see how many remaining characters we need to move
  ; to the top
  lda local_metadata+TextArea::size
  sec
  sbc scroll_num_chars_scrolled_off
  sta scroll_num_chars_remaining

  lda CMDDATA5
  and #TA_SCROLL_SAVE_DISCARDED_ENABLED 
  beq @shift

  ldy #0
@save_discarded_loop:
  lda (first_row_data_ptr_lo),y
  sta (CMDDATA2),y
  iny
  cpy scroll_num_chars_scrolled_off
  bne @save_discarded_loop

@shift:
  ldy scroll_num_chars_scrolled_off ; start of data to pull from
  ldx #0 ; start of data to push to
@shift_loop:
  lda (first_row_data_ptr_lo),y ; get char to shift
  pha
  sty move_line_tempy
  txa
  tay
  pla
  sta (first_row_data_ptr_lo),y ; save shifted char to new loc
  ldy move_line_tempy
  inx
  iny
  cpx scroll_num_chars_remaining
  bne @shift_loop

  lda CMDDATA5
  and #TA_SCROLL_BACKFILL_ENABLED 
  beq @done

@backfill:
  ldy #0
  ldx scroll_num_chars_remaining
@backfill_loop:
  lda (CMDDATA0),y ; backfill char
  pha
  sty move_line_tempy
  txa
  tay
  pla
  sta (first_row_data_ptr_lo),y ; save backfill
  ldy move_line_tempy
  inx
  iny
  cpy scroll_num_chars_scrolled_off
  bne @backfill_loop

@done:
  jsr ta_repaint
  jsr ta_show_cursor
  rts

; shifts all lines up from the provided starting point
; - move_line_start_line_pos - should point to start of line
int_shift_lines_up:
  lda move_line_start_line_pos
  sta move_line_cursor_to    ; start of current line
  clc
  adc local_metadata+TextArea::width
  sta move_line_cursor_from  ; start of next line

@loop:
  ldy move_line_cursor_from
  lda (first_row_data_ptr_lo),y
  ldy move_line_cursor_to
  sta (first_row_data_ptr_lo),y

  inc move_line_cursor_to
  inc move_line_cursor_from
  lda move_line_cursor_from
  cmp local_metadata+TextArea::size
  bne @loop
@done:
  rts

; shifts all lines from the cursor line downwards
; up by one
int_shift_lines_up_from_cursor:
  ; first find the start of the line we're on
  lda local_metadata+TextArea::cursorpos
  sec
  sbc local_metadata+TextArea::cursorx
  sta move_line_start_line_pos
  jsr int_shift_lines_up

  rts

; moves all lines down from current cursor
; including current line and clears current line
; cursor stays where it is.
ta_line_insert:
  lda local_metadata+TextArea::cursory
  cmp local_metadata+TextArea::cursor_maxy
  beq @done

  jsr ta_hide_cursor

  jsr int_shift_lines_down
  jsr int_clear_row_data
  jsr ta_repaint

  jsr ta_show_cursor
@done:
  rts

; shifts all characters from cursor position to the
; right by one. Last char is lost. Blanks the cursor
; position with a space.
int_shift_chars_right:
  ldy local_metadata+TextArea::size
  dey
@loop:
  dey
  lda (first_row_data_ptr_lo),y
  iny
  sta (first_row_data_ptr_lo),y
  dey
  cpy local_metadata+TextArea::cursorpos
  bne @loop
  lda #' '
  sta (first_row_data_ptr_lo),y          ; blank cursorpos
  rts

; shifts all characters to the right of the cursor
; to the left one space
int_shift_chars_left:
  ldy local_metadata+TextArea::cursorpos
@loop:
  iny
  cpy local_metadata+TextArea::size
  beq @last_char
  lda (first_row_data_ptr_lo),y
  dey
  sta (first_row_data_ptr_lo),y
  iny
  jmp @loop
@last_char: 
  dey
  lda #' '
  sta (first_row_data_ptr_lo),y
@done:
  rts

ta_char_insert:
  ldy local_metadata+TextArea::cursorpos
  iny
  beq @done ; rolled over
  cpy local_metadata+TextArea::size
  bcs @done ; at or beyond last char

  jsr ta_hide_cursor

  jsr int_shift_chars_right
  jsr ta_repaint

  jsr ta_show_cursor
@done:
  rts

ta_line_delete:
  jsr ta_hide_cursor
  lda local_metadata+TextArea::cursory
  cmp local_metadata+TextArea::cursor_maxy
  beq @last_line ; on last line

  jsr int_shift_lines_up_from_cursor
@last_line:
  jsr int_clear_last_row_data
  jsr ta_repaint

  jsr ta_show_cursor
  rts

ta_shift_all_up:
  jsr ta_hide_cursor
  lda #0
  sta move_line_start_line_pos
  jsr int_shift_lines_up
  jsr ta_repaint
  jsr ta_show_cursor
  rts

; erases the char under the cursor by moving all
; the characters to the right one space left.
ta_char_delete:
  ldy local_metadata+TextArea::cursorpos
  iny
  cpy local_metadata+TextArea::size
  beq @done ; at last char
 
  jsr ta_hide_cursor

  jsr int_shift_chars_left
  jsr ta_repaint
  ;jsr ta_move_cursor_left

  jsr ta_show_cursor
@done:
  rts

; appends chars to the text area without doing any bounds
; checking. assumes you know there is space when you call it.
; inputs:
;   CMDDATA0/1 - pointer to the data
;   CMDDATA2   - number of chars to add
ta_append_chars_fast:
  lda CMDDATA2
  beq @done
  ldy #0
@loop:
  lda (CMDDATA0),y
  sty append_tempy
  ldy local_metadata+TextArea::cursorpos
  sta (first_row_data_ptr_lo),y
  iny
  sty local_metadata+TextArea::cursorpos
  ldy append_tempy
  iny
  cpy CMDDATA2
  bne @loop

  jsr int_update_cursor_xy
  jsr int_update_cursor_pos
  jsr ta_repaint
@done:
  rts

ta_move_cursor_to_start_of_last_line:
  jsr ta_hide_cursor
  lda local_metadata+TextArea::cursor_maxy
  sta local_metadata+TextArea::cursory
  lda #0
  sta local_metadata+TextArea::cursorx
  jsr int_update_cursor_pos
  jsr ta_show_cursor
  rts

show_cursor_var0: .byte 0
update_marker_start: .byte 0
update_marker_end:   .byte 0

append_tempy: .byte 0

move_line_start_line_pos:      .byte 0
move_line_end_line_pos:        .byte 0
move_line_num_chars:           .byte 0
move_line_cursor_from:         .byte 0
move_line_cursor_to:           .byte 0
move_line_tempy:               .byte 0
scroll_num_chars_remaining:    .byte 0
scroll_num_chars_scrolled_off: .byte 0

init_last_row_offset:          .byte 0

repaint_tmp0:                  .byte 0
repaint_tmp1:                  .byte 0

get_line_offset:               .byte 0
get_line_num_chars:            .byte 0


