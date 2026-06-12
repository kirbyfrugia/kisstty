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
.include "common.inc"
.include "config.inc"
.include "macros.inc"
.include "memmove.inc"
.include "textarea.inc"


.IMPORT utils_atascii_to_icode
.IMPORT utils_dump_mem_line
.IMPORT copy_buffer40
.IMPORT copy_buffer40_size
.IMPORT scr_rows_lo,scr_rows_hi

.segment "ZEROPAGE"
ta_metadata:           .tag TextArea
context_ptr_lo:        .res 1
context_ptr_hi:        .res 1
context_ptr_saved_lo:  .res 1
context_ptr_saved_hi:  .res 1
; temp pointers used by various functions
temp_line_scr_ptr_lo:  .res 1
temp_line_scr_ptr_hi:  .res 1
temp_line_data_ptr_lo: .res 1
temp_line_data_ptr_hi: .res 1


.segment "CODE"
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
  copy_struct_abs_to_zp ta_metadata, context_ptr_lo, TextArea
no_cache:
  ; update our pointer to the new text area
  lda CMDDATA0
  sta context_ptr_lo
  lda CMDDATA1
  sta context_ptr_hi

  ; copy data from the new TextArea to the local cache in
  ; the zero page.
  copy_struct_zp_to_abs context_ptr_lo, ta_metadata, TextArea
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
  copy_struct_abs_to_zp ta_metadata, context_ptr_lo, TextArea
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
  copy_struct_abs_to_zp ta_metadata, context_ptr_lo, TextArea
  copy_struct_zp_to_abs context_ptr_saved_lo, ta_metadata, TextArea
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

; initializes a text area
;
; assumes:
;   SCR_PTR_LO already set
ta_init_textarea:
  jsr int_update_cursor_line
  jsr ta_clear_and_repaint
  jsr ta_show_cursor
  rts

; subtracts one line from the scr_line and data_line
; ptrs
int_prev_line:
  lda temp_line_data_ptr_lo
  sec
  sbc ta_metadata+TextArea::width
  sta temp_line_data_ptr_lo
  lda temp_line_data_ptr_hi
  sbc #0
  sta temp_line_data_ptr_hi

  lda temp_line_scr_ptr_lo
  sec
  sbc #SCREEN_WIDTH
  sta temp_line_scr_ptr_lo
  lda temp_line_scr_ptr_hi
  sbc #0
  sta temp_line_scr_ptr_hi
  rts

; sets temp_line_data_ptr_lo/hi and temp_line_scr_ptr_lo/hi
; to the start of the last line
ta_find_last_line:
  ; note: use cursory because it'll always be faster
  ;       given it's >= first_line. And last line always
  ;       has to be >= cursor_line
  lda cursor_line_data_ptr_lo
  sta temp_line_data_ptr_lo
  lda cursor_line_data_ptr_hi
  sta temp_line_data_ptr_hi

  lda cursor_line_scr_ptr_lo
  sta temp_line_scr_ptr_lo
  lda cursor_line_scr_ptr_hi
  sta temp_line_scr_ptr_hi

  ldy ta_metadata+TextArea::cursory
@loop:
  cpy ta_metadata+TextArea::cursor_maxy
  beq @done
  
  lda temp_line_data_ptr_lo
  clc
  adc ta_metadata+TextArea::width
  sta temp_line_data_ptr_lo
  bcc @nowrap_data
  inc temp_line_data_ptr_hi
@nowrap_data:
  lda temp_line_scr_ptr_lo
  clc
  adc #SCREEN_WIDTH
  sta temp_line_scr_ptr_lo
  bcc @nowrap_scr
  inc temp_line_scr_ptr_hi
@nowrap_scr:
  iny
  bne @loop
@done:
  rts

; flush cursor to backing store
int_flush_cursor:
  ldy #TextArea::cursorx
  lda ta_metadata+TextArea::cursorx
  sta (context_ptr_lo),y

  ldy #TextArea::cursory
  lda ta_metadata+TextArea::cursory
  sta (context_ptr_lo),y

  ldy #TextArea::cursor_line_scr_ptr
  lda cursor_line_scr_ptr_lo
  sta (context_ptr_lo),y
  iny
  lda cursor_line_scr_ptr_hi
  sta (context_ptr_lo),y

  ldy #TextArea::cursor_line_data_ptr
  lda cursor_line_data_ptr_lo
  sta (context_ptr_lo),y
  iny
  lda cursor_line_data_ptr_hi
  sta (context_ptr_lo),y

  rts

; updates the cursor line given based on
; the current cursorx/cursory
int_update_cursor_line:
  lda first_line_data_ptr_lo
  sta cursor_line_data_ptr_lo
  lda first_line_data_ptr_hi
  sta cursor_line_data_ptr_hi

  lda first_line_scr_ptr_lo
  sta cursor_line_scr_ptr_lo
  lda first_line_scr_ptr_hi
  sta cursor_line_scr_ptr_hi

  ldy #0
@loop:
  cpy ta_metadata+TextArea::cursory
  beq @done
  
  lda cursor_line_data_ptr_lo
  clc
  adc ta_metadata+TextArea::width
  sta cursor_line_data_ptr_lo
  bcc @nowrap_data
  inc cursor_line_data_ptr_hi
@nowrap_data:
  lda cursor_line_scr_ptr_lo
  clc
  adc #SCREEN_WIDTH
  sta cursor_line_scr_ptr_lo
  bcc @nowrap_scr
  inc cursor_line_scr_ptr_hi
@nowrap_scr:
  iny
  bne @loop
@done:
  rts

; moves cursorx/cursory after appending chars after the cursor
; inputs:
;   CMDDATA0/1 - number of chars added after the cursor
;   cursorx/cursory - current (pre-append) cursor position
int_move_cursor_xy:
  ; total = count + cursorx  (16-bit, in CMDDATA0/1)
  lda CMDDATA0
  clc
  adc ta_metadata+TextArea::cursorx
  sta CMDDATA0
  bcc @added_wrap
  inc CMDDATA1
@added_wrap:
  ; cursory += total / width, remainder -> cursorx
@div_loop:
  lda CMDDATA1
  bne @subtract ; total > width, keep going
  lda CMDDATA0
  cmp ta_metadata+TextArea::width
  bcc @done     ; total < width -> remainder is in CMDDATA0
@subtract:
  lda CMDDATA0
  sec
  sbc ta_metadata+TextArea::width
  sta CMDDATA0
  bcs @no_borrow
  dec CMDDATA1
@no_borrow:
  inc ta_metadata+TextArea::cursory
  jmp @div_loop
@done:
  lda CMDDATA0
  sta ta_metadata+TextArea::cursorx
  jsr int_update_cursor_line
  rts

ta_hide_cursor:
  lda ta_metadata+TextArea::type
  cmp #TA_TYPE_OUTPUT
  beq @done

  ldy ta_metadata+TextArea::cursorx
  lda (cursor_line_scr_ptr_lo),y
  and #%01111111
  sta (cursor_line_scr_ptr_lo),y
@done:
  rts

ta_show_cursor:
  lda ta_metadata+TextArea::type
  cmp #TA_TYPE_OUTPUT
  beq @done

  ldy ta_metadata+TextArea::cursorx
  lda (cursor_line_scr_ptr_lo),y
  ora #%10000000
  sta (cursor_line_scr_ptr_lo),y
@done:
  rts

int_cursor_home:
  lda #0
  sta ta_metadata+TextArea::cursorx
  sta ta_metadata+TextArea::cursory
  jsr int_update_cursor_line
  rts

; TODO: done, not tested
ta_clear_and_repaint:
  lda first_line_scr_ptr_lo
  sta temp_line_scr_ptr_lo
  lda first_line_scr_ptr_hi
  sta temp_line_scr_ptr_hi

  lda first_line_data_ptr_lo
  sta temp_line_data_ptr_lo
  lda first_line_data_ptr_hi
  sta temp_line_data_ptr_hi

  ldx ta_metadata+TextArea::height
@line_loop:
  ldy ta_metadata+TextArea::width
  dey
@col_loop:
  lda #' '
  sta (temp_line_data_ptr_lo),y
  lda #$00 ; space icode
  sta (temp_line_scr_ptr_lo),y
  dey
  bpl @col_loop
  dex
  beq @done

  lda temp_line_scr_ptr_lo
  clc
  adc #SCREEN_WIDTH
  sta temp_line_scr_ptr_lo
  bcc @scr_nowrap
  inc temp_line_scr_ptr_hi
@scr_nowrap: 
  lda temp_line_data_ptr_lo
  clc
  adc ta_metadata+TextArea::width
  sta temp_line_data_ptr_lo
  bcc @data_nowrap
  inc temp_line_data_ptr_hi
@data_nowrap:
  jmp @line_loop
@done:
  rts

; TODO: done, not tested
; repaints the entire text area. Useful when data changes.
; Not so efficient, but I'll worry about that later.
ta_repaint:
  lda first_line_scr_ptr_lo
  sta temp_line_scr_ptr_lo
  lda first_line_scr_ptr_hi
  sta temp_line_scr_ptr_hi

  lda first_line_data_ptr_lo
  sta temp_line_data_ptr_lo
  lda first_line_data_ptr_hi
  sta temp_line_data_ptr_hi

  ldx ta_metadata+TextArea::height
@line_loop:
  ldy ta_metadata+TextArea::width
  dey
@col_loop:
  lda (temp_line_data_ptr_lo),y
  jsr utils_atascii_to_icode
  sta (temp_line_scr_ptr_lo),y
  dey
  bpl @col_loop
  dex
  beq @done

  lda temp_line_scr_ptr_lo
  clc
  adc #SCREEN_WIDTH
  sta temp_line_scr_ptr_lo
  bcc @scr_nowrap
  inc temp_line_scr_ptr_hi
@scr_nowrap: 
  lda temp_line_data_ptr_lo
  clc
  adc ta_metadata+TextArea::width
  sta temp_line_data_ptr_lo
  bcc @data_nowrap
  inc temp_line_data_ptr_hi
@data_nowrap:
  jmp @line_loop
@done:
  rts

; clears all data in the area, repaints, and returns the cursor home
ta_shift_clear:
  jsr ta_hide_cursor
  jsr int_cursor_home
  jsr ta_clear_and_repaint
  jsr ta_show_cursor
  rts

; TODO: done, not tested
; shifts all lines from the cursor line downwards
; down by one. 
int_shift_lines_down:
  ; figure out how many lines we need to move
  lda ta_metadata+TextArea::cursor_maxy
  sec
  sbc ta_metadata+TextArea::cursory
  beq @done ; no shift if on last line
  tax ; num lines to copy downward

  jsr ta_find_last_line
  jsr int_prev_line ; penultimate line
@line_loop:
  ; copy line to line below it
  ldy ta_metadata+TextArea::width
@col_loop:
  lda (temp_line_data_ptr_lo),y
  pha
  lda (temp_line_scr_ptr_lo),y
  pha
  sty tempy
  tya
  clc
  adc ta_metadata+TextArea::width
  tay
  pla
  sta (temp_line_scr_ptr_lo),y
  pla
  sta (temp_line_data_ptr_lo),y
  ldy tempy
  dey
  bpl @col_loop
  dex
  beq @done
  jsr int_prev_line
  jmp @line_loop
 @done: 
  rts

; TODO: done, not tested
; calculates the bytes remaining from the cursor
; position to the end of the buffer
; outputs:
;   MM_SIZEL/MM_SIZEH
ta_bytes_remaining:
  ; calculate the number of bytes to move, formula:
  ;   end of buffer = start of buffer + size
  ;   num bytes = end of buffer - cursor line start - cursorx - 1
  ;   * note: end of buffer is actually one past end of buffer
  ;   * note: the "-1" is because the last char drops off 

  ; end of buffer
  lda first_line_data_ptr_lo
  clc
  adc ta_metadata+TextArea::size
  sta MM_SIZEL
  lda first_line_data_ptr_hi
  adc ta_metadata+TextArea::size+1
  sta MM_SIZEH

  ; end - cursor start of line
  lda MM_SIZEL
  sec
  sbc cursor_line_data_ptr_lo
  sta MM_SIZEL
  lda MM_SIZEH
  sbc cursor_line_data_ptr_hi
  sta MM_SIZEH

  ; - cursorx - 1
  lda MM_SIZEL
  sec
  sbc ta_metadata+TextArea::cursorx
  sbc #1
  sta MM_SIZEL
  lda MM_SIZEH
  sbc #0
  sta MM_SIZEH
  rts

ta_move_cursor_to_start_of_last_line:
  jsr ta_hide_cursor
  lda ta_metadata+TextArea::cursor_maxy
  sta ta_metadata+TextArea::cursory
  lda #0
  sta ta_metadata+TextArea::cursorx
  jsr int_update_cursor_line
  jsr ta_show_cursor
  rts


; TODO: check for repaints

; TODO: done, not tested
.export ta_edit_move_cursor_up
ta_edit_move_cursor_up:
  jsr ta_hide_cursor

  lda ta_metadata+TextArea::cursory
  beq @wrapped
  dec ta_metadata+TextArea::cursory
  jmp @updated
@wrapped:
  lda ta_metadata+TextArea::cursor_maxy
  sta ta_metadata+TextArea::cursory
@updated:
  jsr int_update_cursor_line
  jsr ta_show_cursor
  rts

; TODO: done, not tested
.export ta_edit_move_cursor_down
ta_edit_move_cursor_down:
  jsr ta_hide_cursor

  lda ta_metadata+TextArea::cursory
  cmp ta_metadata+TextArea::cursor_maxy
  beq @wrapped

  inc ta_metadata+TextArea::cursory
  bne @updated
@wrapped:
  lda #0
  sta ta_metadata+TextArea::cursory
@updated:
  jsr int_update_cursor_line
  jsr ta_show_cursor
  rts

; TODO: done, not tested
; moves the cursor left if possible.
;
; pass CMDDATA0 to define behavior when we wrap to the left.
; Zero will stay on the same line. Non-zero will move up a line.
; Used when we move the cursor based on arrow keys vs text changes.
;
; inputs:
;   CMDDATA0 - cursor behavior on wrap
.export ta_edit_move_cursor_left
ta_edit_move_cursor_left:
  jsr ta_hide_cursor

  lda ta_metadata+TextArea::cursorx
  beq @wrapped
  dec ta_metadata+TextArea::cursorx
  jmp @updated
@wrapped:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  bit CMDDATA0
  bmi @wrapped_change_lines

  ; if here, just wrap around on the same line
  lda ta_metadata+TextArea::cursor_maxx
  sta ta_metadata+TextArea::cursorx
  bne @updated
@wrapped_change_lines:
  lda ta_metadata+TextArea::cursory
  beq @done ; already at top, just ignore movement

  ; move up a line
  dec ta_metadata+TextArea::cursory
  ; and move to the end of it
  lda ta_metadata+TextArea::cursor_maxx
  sta ta_metadata+TextArea::cursorx
@updated:
  jsr int_update_cursor_line
@done:
  jsr ta_show_cursor
  rts

; TODO: done, not tested
.export ta_edit_move_cursor_right
ta_edit_move_cursor_right:
  jsr ta_hide_cursor

  lda ta_metadata+TextArea::cursorx
  cmp ta_metadata+TextArea::cursor_maxx
  beq @wrapped

  inc ta_metadata+TextArea::cursorx
  bne @updated
@wrapped:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  bit CMDDATA0
  bmi @wrapped_change_lines

  ; if here, just wrap around on the same line
  lda #0
  sta ta_metadata+TextArea::cursorx
  beq @updated
@wrapped_change_lines:
  lda ta_metadata+TextArea::cursory
  cmp ta_metadata+TextArea::cursor_maxy
  beq @done; already at bottom

  ; move down a line
  inc ta_metadata+TextArea::cursory
  ; and move to the start of it
  lda #0
  sta ta_metadata+TextArea::cursorx
@updated:
  jsr int_update_cursor_line
@done:
  jsr ta_show_cursor

  rts

; TODO: done, not tested
; updates the char at the current cursor position
; to A.
; modifies:
;   A
int_update_char:
  ldy ta_metadata+TextArea::cursorx
  sta (cursor_line_data_ptr_lo),y
  jsr utils_atascii_to_icode
  sta (cursor_line_scr_ptr_lo),y
  rts

; TODO: done, not tested
; sets the character at the current cursor location to A.
; moves the cursor to the right.
;
; inputs
;   - A the character
.export ta_edit_type_char
ta_edit_type_char:
  jsr int_update_char
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  sta CMDDATA0
  jsr ta_edit_move_cursor_right
  rts

; TODO: done, not tested
; erases character under cursor, moves cursor left.
; atari style doesn't shift data left.
.export ta_edit_backspace
ta_edit_backspace:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  sta CMDDATA0
  jsr ta_edit_move_cursor_left
  lda #' '
  jsr int_update_char
  rts

; moves all lines down from current cursor
; including current line and clears current line
; cursor stays where it is.
.export ta_edit_line_insert
ta_edit_line_insert:
  lda ta_metadata+TextArea::cursory
  cmp ta_metadata+TextArea::cursor_maxy
  beq @done

  jsr ta_hide_cursor

  jsr int_shift_lines_down
  jsr int_clear_cursor_line

  jsr ta_show_cursor
@done:
  rts

; TODO - done, not tested
.export ta_edit_char_insert
ta_edit_char_insert:
  jsr ta_hide_cursor
  jsr int_shift_chars_right
  lda #' '
  jsr int_update_char
  jsr ta_show_cursor
@done:
  rts

; TODO: done, not tested
.export ta_edit_line_delete
ta_edit_line_delete:
  jsr ta_hide_cursor
  lda ta_metadata+TextArea::cursory
  cmp ta_metadata+TextArea::cursor_maxy
  beq @last_line ; on last line

  jsr int_shift_lines_up_from_cursor
@last_line:
  jsr int_clear_last_line
  jsr ta_show_cursor
  rts

; TODO: done, not tested
; erases the char under the cursor by moving all
; the characters to the right one space left.
.export ta_edit_char_delete
ta_edit_char_delete:
  ldy ta_metadata+TextArea::cursory
  cpy ta_metadata+TextArea::cursor_maxy
  bcc @not_at_end
  ldy ta_metadata+TextArea::cursorx
  cpy ta_metadata+TextArea::cursor_maxx
  bcc @not_at_end
  bcs @done
@not_at_end:
  jsr ta_hide_cursor
  jsr int_shift_chars_left
  jsr int_clear_last_char
  jsr ta_show_cursor
@done:
  rts

; TODO: done, not tested
; clears the data in the current line
int_clear_cursor_line:
  ldy ta_metadata+TextArea::width
  dey
  lda #' '
@loop:
  sta (cursor_line_data_ptr_lo),y
  jsr utils_atascii_to_icode
  sta (cursor_line_scr_ptr_lo),y
  dey
  bpl @loop
  rts

; TODO: done, not tested
int_clear_last_char:
  jsr ta_find_last_line
  ldy ta_metadata+TextArea::width
  dey
  lda #' '
  sta (temp_line_data_ptr_lo),y
  jsr utils_atascii_to_icode
  sta (temp_line_scr_ptr_lo),y
  rts

; TODO: done, not tested
int_clear_last_line:
  jsr ta_find_last_line
  jsr int_clear_line
  rts

; TODO: done, not tested
; inputs:
;   temp_line_data_ptr_lo/hi
int_clear_line:
  ldy ta_metadata+TextArea::width
  dey
  lda #' '
@loop:
  sta (temp_line_data_ptr_lo),y
  jsr utils_atascii_to_icode
  sta (temp_line_scr_ptr_lo),y
  dey
  bpl @loop
  rts

; TODO: done, not tested
; shifts all characters from cursor position to the
; right by one. Last char is lost. Blanks the cursor
; position with a space.
; modifies:
;   ZPB0/1/2/3/4/5
int_shift_chars_right:
  jsr ta_bytes_remaining
  lda cursor_line_data_ptr_lo
  sta MM_FROM
  sta MM_TO
  lda cursor_line_data_ptr_hi
  sta MM_FROM+1
  sta MM_TO+1

  inc MM_TO
  bne @nowrap_dest
  inc MM_TO+1
@nowrap_dest:
  jsr MM_MOVEUP_SS

  lda #' '
  jsr int_update_char

  rts

; TODO: done, not tested
; shifts all characters to the right of the cursor
; to the left one space, leaving last space garbage.
int_shift_chars_left:
  jsr ta_bytes_remaining
  lda cursor_line_data_ptr_lo
  sta MM_FROM
  sta MM_TO
  lda cursor_line_data_ptr_hi
  sta MM_FROM+1
  sta MM_TO+1

  lda MM_TO
  bne @nowrap_dest
  dec MM_TO+1
@nowrap_dest:
  dec MM_TO

  jsr MM_MOVEDOWN
  rts

; TODO: done, not tested
; shifts all lines up from below the cursor line
; to the cursor line, leaving last line garbage
int_shift_lines_up_from_cursor:
  lda cursor_line_data_ptr_lo
  sta MM_TO
  lda cursor_line_data_ptr_hi
  sta MM_TO+1

  lda MM_TO
  clc
  adc ta_metadata+TextArea::width
  sta MM_FROM
  lda MM_TO+1
  adc #0
  sta MM_FROM+1

  jsr ta_find_last_line
  lda temp_line_data_ptr_lo
  sec
  sbc MM_TO
  sta MM_SIZEL
  lda temp_line_data_ptr_hi
  sbc MM_TO+1
  sta MM_SIZEH

  jsr MM_MOVEDOWN
  rts

; scrolls the entire text area up one line.
; cursor stays where it is.
ta_out_scroll_up_one_line:
  lda first_line_data_ptr_lo
  sta MM_TO
  clc
  adc ta_metadata+TextArea::width
  sta MM_FROM
  lda first_line_data_ptr_hi
  sta MM_TO+1
  adc #0
  sta MM_FROM+1

  lda ta_metadata+TextArea::size
  sec
  sbc ta_metadata+TextArea::width
  sta MM_SIZEL
  lda ta_metadata+TextArea::size+1
  sbc #0
  sta MM_SIZEH
  jsr MM_MOVEDOWN

  ; now clear the last row
  lda first_line_data_ptr_lo
  clc
  adc ta_metadata+TextArea::size
  sta temp_line_data_ptr_lo
  lda first_line_data_ptr_hi
  adc ta_metadata+TextArea::size+1
  sta temp_line_data_ptr_hi

  lda temp_line_data_ptr_lo
  sec
  sbc ta_metadata+TextArea::width
  sta temp_line_data_ptr_lo
  lda temp_line_data_ptr_hi
  sbc #0
  sta temp_line_data_ptr_hi

  lda #' '
  ldy ta_metadata+TextArea::width
  dey
@clear_loop:
  sta (temp_line_data_ptr_lo),y
  dey
  bpl @clear_loop

  jsr ta_repaint
  rts

; appends the data char by char until an eol ($9b)
; is reached. Moves cursor to the next line,
; scrolling the viewport up if needed.
ta_out_append_chars_eol:
  rts

; appends the char. If it's an eol or we reach
; the end of the line, it moves to the next line,
; scrolling the viewport up if needed.
;
; inputs:
;   CMDDATA0 - the char
ta_out_append_char:
  jsr ta_hide_cursor
  lda CMDDATA0
  cmp #$9b
  beq @eol
  jsr int_update_char

  ldx ta_metadata+TextArea::cursorx
  cpx ta_metadata+TextArea::cursor_maxx
  beq @eol
  inx
  stx ta_metadata+TextArea::cursorx
  bne @done
@eol:
  ldx ta_metadata+TextArea::cursory
  cpx ta_metadata+TextArea::cursor_maxy
  beq @scroll
  inc ta_metadata+TextArea::cursory
  lda #0
  sta ta_metadata+TextArea::cursorx
  beq @done
@scroll:
  jsr ta_out_scroll_up_one_line
  ; no need to set cursory, was already on
  ; last line
  lda #0
  sta ta_metadata+TextArea::cursorx
@done:
  jsr int_update_cursor_line
  jsr ta_show_cursor
  rts

; appends the given lines of data starting one row
; below the current cursor. Cursor will be at the
; end of the appended lines
ta_out_append_lines:
  rts

;; appends the given data starting at the current cursor
;; location and moves the cursor to the end of the new data.
;; Also repaints.
;;
;; Note: it's up to you to make sure that number of chars
;;       is <= the size of this buffer.
;; Note: it also assumes that your data does not overlap
;;       with this text area.
;;
;; inputs:
;;   CMDDATA0/1 - ptr to data to append
;;   CMDDATA2/3 - number of chars to append
;ta_add_chars:
;  jsr ta_hide_cursor
;  ; Basic algorithm
;  ; 1. See if there's space to fit the new chars.
;  ;    If yes, go to step 5.
;  ; 2. Figure out how much space we need to add.
;  ; 3. Move the existing data up by the amount needed.
;  ; 4. Set the cursor position to the end of the existing
;  ;    data.
;  ; 5. Move the new data to the cursor position.
;  ; 6. Repaint the part of the text area that changed.
;  ; first let's make room for the new chars
;  ; by moving
;
;  jsr ta_bytes_remaining
;
;  cmp16 CMDDATA2, MM_SIZEL, @fits, @fits, @make_space
;@make_space:
;  ; if here, num chars to add is greater than space we
;  ; have remaining.
;
;  ; subtract the num to add - space we have remaining
;  lda CMDDATA2
;  sec
;  sbc MM_SIZEL
;  sta MM_SIZEL
;  lda CMDDATA3
;  sbc MM_SIZEH
;  sta MM_SIZEH
;
;  ; and move up by that amount
;  lda first_line_data_ptr_lo
;  sta MM_TO
;  clc
;  adc MM_SIZEL
;  sta MM_FROM
;  lda first_line_data_ptr_hi
;  sta MM_TO+1
;  adc MM_SIZEH
;  sta MM_FROM+1
;  jsr MM_MOVEUP_SS
;@fits:
;  lda CMDDATA2
;  sta MM_SIZEL
;  lda CMDDATA3
;  sta MM_SIZEH
;@append_text:
;  lda CMDDATA0
;  sta MM_FROM
;  lda CMDDATA1
;  sta MM_FROM+1
;
;  lda cursor_line_data_ptr_lo
;  clc
;  adc ta_metadata+TextArea::cursorx
;  sta MM_TO
;  lda cursor_line_data_ptr_hi
;  adc #0
;  sta MM_TO+1
;  ; doesn't matter if up or down, since it's not overlapping
;  ; move down is probably a little faster, so using it
;  jsr MM_MOVEDOWN
;
;  ; now move the cursor
;  lda MM_SIZEL
;  sta CMDDATA0
;  lda MM_SIZEH
;  sta CMDDATA1
;  jsr int_move_cursor_xy
;  ; TODO: only repaint what changed
;  jsr ta_repaint
;  
;  jsr ta_show_cursor
;  rts


tempy:                         .byte 0
