; Plan:
;   - Keep metadata ptr.
;   - Set absolute screen location of upper left and store it on init.
;   - Pointers to specific rows are calculated
;   - cursorpos is calculated as needed
;   - Start of functions, we grab what we need and store it local.
;   - Calculate data rows and scr ptr rows as needed.
;   
; TODO:
;   - don't modify any CMDDATA* variables beyond what each function accepts
;     as input
; This implements a text area component with a cursor. 
; You can create your own text areas and can have more than one
; on the screen at a time, each with its own cursor.
;
; It supports readonly and editable.
;
; The logic needed for everything is contained in this file.
; To use it, make an EXACT copy of the struct at the bottom of the file,
; and any time you want to call a function from this file,
; just make sure that it's operating on a copy of your metadata.
;
; General usage 
;   For performance reasons, this component operates on an
;   internal copy of the data. It will only update the src
;   if you explicitly tell it to or if you swap out the
;   component.
; 
;   You don't own your data once you set the metadata, so you
;   should not expect it to be current unless you swap it out
;   or you explicity ask for it to copy it.
;
;   ta_initsys           - initializes this handler. call once.
;   ta_init              - macro to help set up your text area (textarea.inc)
;   ta_set_metadata_ptr  - copies your metadata to local storage here
;                          and keeps a pointer to your metadata.
;                        - copies local metadata to the prior ptr
;   ta_*                 - functions that operate on the component.
;
; Commands take arguments from CMDDATA.*
;   NOTE: there is heavy usage of CMDDATA.* vars internally,
;         so there's no guarantee that the data in these
;         won't be modified when you call any function here.
;
.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"
.INCLUDE "textarea.inc"
.SEGMENT "CODE"

.IMPORT utils_atascii_to_icode
.IMPORT utils_dump_mem_row
.IMPORT copy_buffer40
.IMPORT copy_buffer40_size
.IMPORT copy_buffer240
.IMPORT copy_buffer240_size
.EXPORT ta_initsys
.EXPORT ta_init_textarea
.EXPORT ta_get_metadata_ptr
.EXPORT ta_set_metadata_ptr
.EXPORT ta_move_cursor_up
.EXPORT ta_move_cursor_down
.EXPORT ta_move_cursor_left
.EXPORT ta_move_cursor_right
.EXPORT ta_typechar
.EXPORT ta_backspace
.EXPORT ta_clear_all_data
.EXPORT ta_line_insert
.EXPORT ta_char_insert
.EXPORT ta_line_delete
.EXPORT ta_shift_all_up_one_line
.EXPORT ta_scroll_up
.EXPORT ta_paste_last_line
.EXPORT ta_char_delete
.EXPORT ta_copy_first_line
.EXPORT ta_copy_last_line
.EXPORT ta_copy_last_n_lines

ta_initsys:
  lda #0
  sta TA_METADATA_PTR_LO
  sta TA_METADATA_PTR_HI
  sta TA_CURSOR_ROW_DATA_PTR_LO 
  sta TA_CURSOR_ROW_DATA_PTR_HI 
  sta TA_FIRST_ROW_DATA_PTR_LO 
  sta TA_FIRST_ROW_DATA_PTR_HI 
  sta TA_LAST_ROW_DATA_PTR_LO 
  sta TA_LAST_ROW_DATA_PTR_HI 
  sta TA_CURSOR_ROW_SCR_PTR_LO
  sta TA_CURSOR_ROW_SCR_PTR_HI
  sta TA_FIRST_ROW_SCR_PTR_LO
  sta TA_FIRST_ROW_SCR_PTR_HI
  sta TA_LAST_ROW_SCR_PTR_LO
  sta TA_LAST_ROW_SCR_PTR_HI
  rts

; gets the pointer to the current metadata struct.
; useful if you want to swap yourself in and out.
; outputs:
;   CMDDATA0/1 pointer to the metadata
ta_get_metadata_ptr:
  lda TA_METADATA_PTR_LO
  sta CMDDATA0
  lda TA_METADATA_PTR_HI
  sta CMDDATA1
  rts

; swaps out which text area we're working on.
; updates prior struct with latest data.
;
; inputs:
;   CMDDATA0/1 - ptr to the new metadata struct
ta_set_metadata_ptr:
  lda TA_METADATA_PTR_HI
  bne @swap
  lda TA_METADATA_PTR_LO
  beq @noswap
@swap:
  copy_struct_abs_to_zp local_metadata, TA_METADATA_PTR_LO, TextArea

@noswap:
  copy_struct_zp_to_abs CMDDATA0, local_metadata, TextArea
  
  lda CMDDATA0
  sta TA_METADATA_PTR_LO
  lda CMDDATA1
  sta TA_METADATA_PTR_HI

  lda local_metadata+TextArea::first_row_data_ptr_lo
  sta TA_FIRST_ROW_DATA_PTR_LO 
  lda local_metadata+TextArea::first_row_data_ptr_hi
  sta TA_FIRST_ROW_DATA_PTR_HI

  lda local_metadata+TextArea::cursor_row_data_ptr_lo
  sta TA_CURSOR_ROW_DATA_PTR_LO 
  lda local_metadata+TextArea::cursor_row_data_ptr_hi
  sta TA_CURSOR_ROW_DATA_PTR_HI

  lda local_metadata+TextArea::last_row_data_ptr_lo
  sta TA_LAST_ROW_DATA_PTR_LO 
  lda local_metadata+TextArea::last_row_data_ptr_hi
  sta TA_LAST_ROW_DATA_PTR_HI

  lda local_metadata+TextArea::first_row_scr_ptr_lo
  sta TA_FIRST_ROW_SCR_PTR_LO
  lda local_metadata+TextArea::first_row_scr_ptr_hi
  sta TA_FIRST_ROW_SCR_PTR_HI

  lda local_metadata+TextArea::cursor_row_scr_ptr_lo
  sta TA_CURSOR_ROW_SCR_PTR_LO
  lda local_metadata+TextArea::cursor_row_scr_ptr_hi
  sta TA_CURSOR_ROW_SCR_PTR_HI

  lda local_metadata+TextArea::last_row_scr_ptr_lo
  sta TA_LAST_ROW_SCR_PTR_LO
  lda local_metadata+TextArea::last_row_scr_ptr_hi
  sta TA_LAST_ROW_SCR_PTR_HI
  rts

; internal use only, updates the local cursor pos
; given the current cursor x and y
int_update_cursor_pos:
  clc
  lda #0
  tax
@row_loop:
  cpx local_metadata+TextArea::cursory
  beq @row_loop_done
  clc
  adc local_metadata+TextArea::width
  inx
  bne @row_loop
@row_loop_done:
  clc
  adc local_metadata+TextArea::cursorx
  sta local_metadata+TextArea::cursorpos
  rts

int_hide_cursor:
  lda local_metadata+TextArea::use_cursor
  beq @done

  ldy local_metadata+TextArea::cursorx

  lda (TA_CURSOR_ROW_SCR_PTR_LO),y
  and #%01111111
  sta (TA_CURSOR_ROW_SCR_PTR_LO),y
@done:
  rts

int_show_cursor:
  lda local_metadata+TextArea::use_cursor
  beq @done

  ldy local_metadata+TextArea::cursorx

  lda (TA_CURSOR_ROW_SCR_PTR_LO),y
  ora #%10000000
  sta (TA_CURSOR_ROW_SCR_PTR_LO),y
@done:
  rts

temp:
  ldy TextArea::cursory
  lda (TA_METADATA_PTR_LO),y

  lda
  
  rts

int_cursor_moved_up:
  dec local_metadata+TextArea::cursory
  lda TA_CURSOR_ROW_SCR_PTR_LO
  sec
  sbc #SCREEN_WIDTH
  sta TA_CURSOR_ROW_SCR_PTR_LO
  lda TA_CURSOR_ROW_SCR_PTR_HI
  sbc #0
  sta TA_CURSOR_ROW_SCR_PTR_HI

  lda TA_CURSOR_DATA_ROW_PTR_LO
  sec
  sbc local_metadata+TextArea::width
  sta TA_CURSOR_ROW_DATA_PTR_LO
  lda TA_CURSOR_ROW_DATA_PTR_HI
  sbc #0
  sta TA_CURSOR_ROW_DATA_PTR_HI

  rts

int_cursor_moved_down:
  inc local_metadata+TextArea::cursory
  lda TA_CURSOR_ROW_SCR_PTR_LO
  clc
  adc #SCREEN_WIDTH
  sta TA_CURSOR_ROW_SCR_PTR_LO
  lda TA_CURSOR_ROW_SCR_PTR_HI
  adc #0
  sta TA_CURSOR_ROW_SCR_PTR_HI

  lda TA_CURSOR_DATA_ROW_PTR_LO
  clc
  adc local_metadata+TextArea::width
  sta TA_CURSOR_ROW_DATA_PTR_LO
  lda TA_CURSOR_ROW_DATA_PTR_HI
  adc #0
  sta TA_CURSOR_ROW_DATA_PTR_HI

  rts

int_cursor_moved_to_first_line:
  lda #0
  sta local_metadata+TextArea::cursory
  lda TA_FIRST_ROW_SCR_PTR_LO
  sta TA_CURSOR_ROW_SCR_PTR_LO
  lda TA_FIRST_ROW_SCR_PTR_HI
  sta TA_CURSOR_ROW_SCR_PTR_HI
  lda TA_FIRST_ROW_DATA_PTR_LO
  sta TA_CURSOR_ROW_DATA_PTR_LO
  lda TA_FIRST_ROW_DATA_PTR_HI
  sta TA_CURSOR_ROW_DATA_PTR_HI
  rts

int_cursor_moved_to_last_line:
  lda local_metadata+TextArea::cursor_maxy
  sta local_metadata+TextArea::cursory
  lda TA_LAST_ROW_SCR_PTR_LO
  sta TA_CURSOR_ROW_SCR_PTR_LO
  lda TA_LAST_ROW_SCR_PTR_HI
  sta TA_CURSOR_ROW_SCR_PTR_HI
  lda TA_LAST_ROW_DATA_PTR_LO
  sta TA_CURSOR_ROW_DATA_PTR_LO
  lda TA_LAST_ROW_DATA_PTR_HI
  sta TA_CURSOR_ROW_DATA_PTR_HI
  rts

ta_move_cursor_up:
  jsr int_hide_cursor
  lda local_metadata+TextArea::cursory
  beq @wrapped
  jsr int_cursor_moved_up
  jmp @done
@wrapped:
  jsr int_cursor_moved_to_last_line
@updated:
  jsr int_show_cursor
  rts

ta_move_cursor_down:
  jsr int_hide_cursor
  lda local_metadata+TextArea::cursory
  cmp local_metadata+TextArea::cursor_maxy
  beq @wrapped
  jsr int_cursor_moved_down
  bne @done
@wrapped:
  jsr int_cursor_moved_to_first_line
@done:
  jsr int_show_cursor
  rts

; moves the cursor left if possible.
;
; pass CMDARG0 to define behavior when we
; wrap to the left. Zero will stay on the same
; line. Non-zero will move up a line. Used
; when we move the cursor based on arrow keys vs
; text changes.
ta_move_cursor_left:
  jsr int_hide_cursor

  lda local_metadata+TextArea::cursorx
  beq @wrapped
  dec local_metadata+TextArea::cursorx
  jmp @done
@wrapped:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  bit CMDDATA0
  bmi @wrapped_change_lines

  ; if here, just wrap around on the same line
  lda local_metadata+TextArea::cursor_maxx
  sta local_metadata+TextArea::cursorx
  bne @done
@wrapped_change_lines:
  lda local_metadata+TextArea::cursory
  beq @done ; already at top, just ignore movement

  ; otherwise, just move up a line and to the end of it
  jsr int_cursor_moved_up
  lda local_metadata+TextArea::cursor_maxx
  sta local_metadata+TextArea::cursorx
@done:
  jsr int_show_cursor
  rts

ta_move_cursor_right:
  jsr int_hide_cursor

  lda local_metadata+TextArea::cursorx
  cmp local_metadata+TextArea::cursor_maxx
  beq @wrapped

  inc local_metadata+TextArea::cursorx
  bne @done
@wrapped:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  bit CMDDATA0
  bmi @wrapped_change_lines

  ; if here, just wrap around on the same line
  lda #0
  sta local_metadata+TextArea::cursorx
  beq @done
@wrapped_change_lines:
  lda local_metadata+TextArea::cursory
  cmp local_metadata+TextArea::cursor_maxy
  beq @done; already at bottom

  ; otherwise, move down a line and to the start of it
  jsr int_cursor_moved_down
  lda #0
  sta local_metadata+TextArea::cursorx
@done:
  jsr int_show_cursor
  rts

; sets the character at the current cursor location provided in A.
; moves the cursor to the right.
;
; inputs
;   - A the character
ta_typechar:
  ldy local_metadata+TextArea::cursorx
  sta (TA_CURSOR_ROW_DATA_PTR_LO),y
  jsr utils_atascii_to_icode
  sta (TA_CURSOR_ROW_SCR_PTR_LO),y
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  sta CMDDATA0
  jsr ta_move_cursor_right
  rts

; erases character under cursor, moves cursor left.
; atari style doesn't shift data left.
ta_backspace:
  jsr int_hide_cursor
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  sta CMDDATA0
  jsr ta_move_cursor_left
  ldy local_metadata+TextArea::cursorx
  lda #' '
  sta (TA_CURSOR_ROW_DATA_PTR_LO),y
  jsr utils_atascii_to_icode
  sta (TA_CURSOR_ROW_SCR_PTR_LO),y
  jsr int_show_cursor
  rts

int_cursor_home:
  jsr int_hide_cursor
  lda #0
  sta local_metadata+TextArea::cursory
  sta local_metadata+TextArea::cursorx
  jsr int_cursor_moved_to_first_line
  jsr int_show_cursor
  rts

; clears all data between the markers
; inputs:
;   - update_marker_start (position to start)
;   - update_marker_end   (position to end, exclusive)
int_clear_data:
  ldy update_marker_start
@loop:
  lda #' '
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
  iny
  cpy update_marker_end
  bcc @loop
  rts


; repaints the entire screen area for the input
; box. Useful when data changes. Not so efficient,
; but I'll worry about that later.
int_repaint:
  ldx #0
@row_loop:
  lda (TA_FIRST_ROW_SCR_PTR_LO),y
  sta (TA_LAST_ROW_SCR_PTR_LO),y
  inx
  cpx local_metadata+TextArea::height
  bne @row_loop

  ; lo byte pointer to first row
  lda local_metadata+TextArea::scr_row_ptr_table_lo
  sta CMDDATA0
  lda local_metadata+TextArea::scr_row_ptr_table_lo+1
  sta CMDDATA1

  ; hi byte pointer to first row
  lda local_metadata+TextArea::scr_row_ptr_table_hi
  sta CMDDATA2
  lda local_metadata+TextArea::scr_row_ptr_table_hi+1
  sta CMDDATA3

  ; now save the ptr to first row
  ldy #0
  lda (CMDDATA0),y
  sta CMDDATA0
  lda (CMDDATA2),y
  sta CMDDATA1

; basic algorithm:
; start at the first screen row where our input lives.
; have a loop that starts margin_left over and goes until width
; keep a cursor offset for the actual data as you move right
; each character.
  ldx #0 ; temporary cursor
@screen_row_loop:
  lda local_metadata+TextArea::margin_left
  tay
  lda local_metadata+TextArea::width
  clc
  adc local_metadata+TextArea::margin_left
  sta repaint_tmp1
@screen_col_loop:
  sty repaint_tmp0
  txa
  tay
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  jsr utils_atascii_to_icode
  ldy repaint_tmp0
  sta (CMDDATA0),y
  inx
  iny
  cpy repaint_tmp1
  bcc @screen_col_loop
  cpx local_metadata+TextArea::size
  bcs @done
  lda CMDDATA0
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1
  jmp @screen_row_loop
@done:
  rts

; clears the current row
int_clear_row:
  lda #' '
  ldy local_metadata+TextArea::width
  dey
@loop:
  sta (TA_CURSOR_ROW_DATA_PTR_LO),y
  dey
  bpl @loop
  rts

; just clears the last row. useful for scrolling
; or deleting lines
int_clear_last_row:
  lda #' '
  ldy local_metadata+TextArea::width
  dey
@loop:
  sta (TA_LAST_ROW_DATA_PTR_LO),y
  jsr utils_atascii_to_icode
  sta (TA_LAST_ROW_SCR_PTR_LO),y
  dey
  bpl @loop
  rts

; clears all data in the area and returns the cursor home
ta_clear_all_data:
  jsr int_hide_cursor

  lda #0
  sta update_marker_start
  lda local_metadata+TextArea::size
  sta update_marker_end
  jsr int_clear_data

  jsr int_cursor_home
  jsr int_repaint

  jsr int_show_cursor
  rts

; shifts all lines below the cursor line
; upwards by one.
; cursor line is overwritten by the line below it.
; last line remains unchanged.
int_shift_up_to_cursor_line:
  ; number of chars to copy is the difference
  ; between the start of the last row and the
  ; start of the cursor row
  lda TA_LAST_ROW_DATA_PTR_LO
  sec
  sbc TA_CURSOR_ROW_DATA_PTR_LO
  sta delete_line_num_chars

  ta_next_data_row_ptr local_metadata, TA_TEMP_CURSOR_ROW_DATA_PTR_LO, TA_TEMP_LOWER_ROW_DATA_PTR_LO

  ldy #0
@copy_loop:
  lda (TA_TEMP_LOWER_ROW_DATA_PTR_LO),y
  sta (TA_TEMP_CURSOR_ROW_DATA_PTR_LO),y
  iny
  cpy delete_line_num_chars
  bne @copy_loop

  rts

; moves all lines down from current cursor line.
; cursor line is unchanged (will be duplicate of one below it).
; cursor stays on cursor line.
int_shift_down_from_cursor_line:
  ; number of chars to copy is the difference
  ; between the start of the last row and the
  ; start of the cursor row
  lda TA_LAST_ROW_DATA_PTR_LO
  sec
  sbc TA_CURSOR_ROW_DATA_PTR_LO
  sta delete_line_num_chars

  ta_next_data_row_ptr local_metadata, TA_TEMP_CURSOR_ROW_DATA_PTR_LO, TA_TEMP_LOWER_ROW_DATA_PTR_LO

  ldy delete_line_num_chars
  dey
@copy_loop:
  lda (TA_TEMP_CURSOR_ROW_DATA_PTR_LO),y
  sta (TA_TEMP_TO_ROW_DATA_PTR_LO),y
  dey
  cpy #$ff
  bne @copy_loop
  rts


; moves all lines down from current cursor
; including current line and clears current line.
; cursor stays where it is.
ta_line_insert:
  lda local_metadata+TextArea::cursory
  cmp local_metadata+TextArea::cursor_maxy
  beq @done

  jsr int_hide_cursor

  jsr int_shift_down_from_cursor_line
  jsr int_clear_row
  jsr int_repaint

  jsr int_show_cursor
@done:
  rts

; shifts all characters from cursor to the
; right to the right
int_shift_chars_right:
  ldy local_metadata+TextArea::size
  dey
@loop:
  dey
  cpy local_metadata+TextArea::cursorpos
  beq @first_char
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  iny
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
  cpy #1
  beq @done
  dey
  jmp @loop
@first_char:
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  iny
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
  dey
  lda #' '
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
@done:
  rts

; shifts all characters to the right of the cursor
; to the left one space
int_shift_chars_left:
  ldy local_metadata+TextArea::cursorpos
@loop:
  iny
  cpy local_metadata+TextArea::size
  beq @last_char
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  dey
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
  iny
  jmp @loop
@last_char: 
  dey
  lda #' '
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
@done:
  rts

ta_char_insert:
  ldy local_metadata+TextArea::cursorpos
  iny
  beq @done ; rolled over
  cpy local_metadata+TextArea::size
  bcs @done ; at or beyond last char

  jsr int_hide_cursor

  jsr int_shift_chars_right
  jsr int_repaint

  jsr int_show_cursor
@done:
  rts

ta_line_delete:
  lda local_metadata+TextArea::cursory
  cmp local_metadata+TextArea::cursor_maxy
  beq @last_line ; on last line

  jsr int_hide_cursor

  jsr int_shift_lines_up_from_cursor
@last_line:
  jsr int_clear_last_row
  jsr int_repaint

  jsr int_show_cursor
  rts

; inputs:
;   - copy_buffer40
;   - copy_buffer40_size
ta_line_append:
  jsr int_hide_cursor

  ; shift all lines up
  lda #0
  sta move_line_start_line_pos
  jsr int_shift_lines_up

  lda copy_buffer40_size
  beq @copy_done; nothing to copy

  ldy #0
@loop:
  lda copy_buffer40,y
  sta (TA_LAST_ROW_DATA_PTR_LO),y
  iny
  cpy copy_buffer40_size
  bne @loop
@copy_done:
  ; repaint the text area. it all changed
  jsr int_repaint
  jsr int_show_cursor
@done:
  rts

ta_shift_all_up_one_line:
  jsr int_hide_cursor
  lda #0
  sta move_line_start_line_pos
  jsr int_shift_lines_up
  jsr int_repaint
  jsr int_show_cursor
  rts

; pastes over last line with copy_buffer40
ta_paste_last_line:
  jsr int_hide_cursor
  ldy #0
@loop:
  lda copy_buffer40,y
  sta (TA_LAST_ROW_DATA_PTR_LO),y
  iny
  cpy local_metadata+TextArea::width
  beq @done
  cpy copy_buffer40_size
  bne @loop
@done:
  jsr int_repaint
  jsr int_show_cursor
  rts

; copies the first line to copy_buffer40
ta_copy_first_line:
  ldy #0
@loop:
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  sta copy_buffer40,y
  iny
  cpy local_metadata+TextArea::width
  bne @loop
  sty copy_buffer40_size
  rts

; copies the last line to copy_buffer40
ta_copy_last_line:
  ldy #0
@loop:
  lda (TA_LAST_ROW_DATA_PTR_LO),y
  sta copy_buffer40,y
  iny
  cpy local_metadata+TextArea::width
  bne @loop
  sty copy_buffer40_size
  rts

; scrolls the entire text area up by N lines.
; stores the discarded data into discard_buffer240
; pastes the data from copy_buffer240 to the bottom
; of the remaining data.
; cursor does not move.
;
; inputs:
;   - CMDDATA0 - number of lines to scroll
; outputs:
;   - CMDDATA1 - number of lines actually scrolled off
;   - CMDDATA2 - width of each data row
;   - discard_buffer240 - the lines discarded from the top
ta_scroll_up:
  ldx CMDDATA0
  beq @skipped

  jsr int_hide_cursor

  ; make sure they don't ask for more lines than we have
  cpx local_metadata+TextArea::height
  bcc @rowsok
  beq @rowsok
  ldx local_metadata+TextArea::height
@rowsok:
  stx CMDDATA1 ; actual number of lines to copy

  ; basic algorithm:
  ; - copy N lines from top to discard_buffer240
  ; - move remaining lines up by N
  ; - blank out remainder

  ; use these pointers, but return them to their prior
  ; state at the end
  lda TA_CURSOR_ROW_SCR_PTR_LO
  pha
  lda TA_CURSOR_ROW_SCR_

  ldx #0 ; line index
  ldy #0 ; char index
@loop:
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  sta discard_buffer240,y
  iny

@copied:
  jsr int_show_cursor
@done:

  
  
  ; y is used to track how many chars to copy
  ; if here, already need to know we need to
  ; do the last row
  ldy local_metadata+TextArea::width
@find_start:
  dex
  beq @found_start
  ; move the data ptr up a line
  lda TA_FIRST_ROW_DATA_PTR_LO
  sec
  sbc local_metadata+TextArea::width
  sta TA_FIRST_ROW_DATA_PTR_LO
  lda TA_FIRST_ROW_DATA_PTR_HI
  sbc #0
  sta TA_FIRST_ROW_DATA_PTR_HI

  ; add to our number of chars to copy
  tya
  clc ; we assume < 256 chars copied
  adc local_metadata+TextArea::width
  tay
  bne @find_start
@found_start:
  ; y now contains the number of chars to copy
  sty copy_buffer240_size
  dey
@loop:
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  sta copy_buffer240,y
  dey
  cpy #$ff
  bne @loop

  pla
  sta TA_FIRST_ROW_DATA_PTR_HI
  pla
  sta TA_FIRST_ROW_DATA_PTR_LO

  jmp @done
@skipped:
  lda #0
  sta CMDDATA1
@done:
  lda local_metadata+TextArea::width
  sta CMDDATA2
  rts




; copies last n (<6) rows to copy_buffer240.
; inputs:
;   - CMDDATA0   - number of lines to copy (<= 240)
; outputs:
;   - CMDDATA1   - number of lines actually copied
;   - CMDDATA2   - width of each data row
ta_copy_last_n_lines:
  ldx CMDDATA0
  beq @skipped

  ; make sure they don't ask for more lines than we have
  cpx local_metadata+TextArea::height
  bcc @rowsok
  beq @rowsok
  ldx local_metadata+TextArea::height
@rowsok:
  stx CMDDATA1 ; actual number of lines to copy

  ; we'll use these, but need to return them
  ; to their prior state afterwards
  lda TA_LAST_ROW_DATA_PTR_LO
  pha
  lda TA_LAST_ROW_DATA_PTR_HI
  pha

  ; y is used to track how many chars to copy
  ; if here, already need to know we need to
  ; do the last row
  ldy local_metadata+TextArea::width
@find_start:
  dex
  beq @found_start
  ; move the data ptr up a line
  lda TA_LAST_ROW_DATA_PTR_LO
  sec
  sbc local_metadata+TextArea::width
  sta TA_LAST_ROW_DATA_PTR_LO
  lda TA_LAST_ROW_DATA_PTR_HI
  sbc #0
  sta TA_LAST_ROW_DATA_PTR_HI

  ; add to our number of chars to copy
  tya
  clc ; we assume < 256 chars copied
  adc local_metadata+TextArea::width
  tay
  bne @find_start
@found_start:
  ; y now contains the number of chars to copy
  sty copy_buffer240_size
  dey
@loop:
  lda (TA_LAST_ROW_DATA_PTR_LO),y
  sta copy_buffer240,y
  dey
  cpy #$ff
  bne @loop

  pla
  sta TA_LAST_ROW_DATA_PTR_HI
  pla
  sta TA_LAST_ROW_DATA_PTR_LO

  jmp @done
@skipped:
  lda #0
  sta CMDDATA1
@done:
  lda local_metadata+TextArea::width
  sta CMDDATA2
  rts

; erases the char under the cursor by moving all
; the characters to the right one space left.
ta_char_delete:
  ldy local_metadata+TextArea::cursorpos
  iny
  cpy local_metadata+TextArea::size
  beq @done ; at last char
 
  jsr int_hide_cursor

  jsr int_shift_chars_left
  jsr int_repaint
  jsr ta_move_cursor_left

  jsr int_show_cursor
@done:
  rts

show_cursor_var0: .byte 0
update_marker_start: .byte 0
update_marker_end:   .byte 0

append_tempy: .byte 0

move_line_start_line_pos: .byte 0
move_line_cursor_from:    .byte 0
move_line_cursor_to:      .byte 0

init_row_scr_lo:          .byte 0
init_row_scr_hi:          .byte 0
init_row_data_lo:         .byte 0
init_row_data_hi:         .byte 0
init_last_row_offset:     .byte 0

repaint_tmp0:             .byte 0
repaint_tmp1:             .byte 0

get_line_offset:          .byte 0
get_line_num_chars:       .byte 0

delete_line_num_chars:    .byte 0
copy_lines_start_lo:      .byte 0
copy_lines_start_hi:      .byte 0

; internal copy
local_metadata: .tag TextArea

