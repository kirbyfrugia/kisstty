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
;   ta_set_metadata_ptr  - copies your metadata to local storage here
;                          and keeps a pointer to your metadata.
;                        - copies local data to the prior source.
;   ta_init_textarea     - used to initialize the text area once you
;                          know where on the screen it will be
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
.EXPORT ta_initsys
.EXPORT ta_init_textarea
.EXPORT ta_set_metadata_ptr
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
.EXPORT ta_paste_last_line
.EXPORT ta_char_delete
.EXPORT ta_copy_first_line
.EXPORT ta_copy_last_line
.EXPORT ta_scroll_up
.EXPORT ta_repaint

ta_initsys:
  lda #0
  sta TA_METADATA_PTR_LO
  sta TA_METADATA_PTR_HI
  sta TA_FIRST_ROW_DATA_PTR_LO 
  sta TA_FIRST_ROW_DATA_PTR_HI 
  sta TA_LAST_ROW_DATA_PTR_LO 
  sta TA_LAST_ROW_DATA_PTR_HI 
  sta TA_CURSOR_SCR_ROW_PTR_LO
  sta TA_CURSOR_SCR_ROW_PTR_HI
  sta TA_FIRST_ROW_SCR_ROW_PTR_LO
  sta TA_FIRST_ROW_SCR_ROW_PTR_HI
  sta TA_LAST_ROW_SCR_ROW_PTR_LO
  sta TA_LAST_ROW_SCR_ROW_PTR_HI
  rts

; swaps out which text area we're working on.
; updates prior struct with latest data.
;
; inputs:
;   CMDDATA0/1 - ptr to the source metadata struct
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

  lda local_metadata+TextArea::first_row_data_ptr
  sta TA_FIRST_ROW_DATA_PTR_LO 
  lda local_metadata+TextArea::first_row_data_ptr+1
  sta TA_FIRST_ROW_DATA_PTR_HI

  lda local_metadata+TextArea::last_row_data_ptr
  sta TA_LAST_ROW_DATA_PTR_LO 
  lda local_metadata+TextArea::last_row_data_ptr+1
  sta TA_LAST_ROW_DATA_PTR_HI

  lda local_metadata+TextArea::cursor_scr_row_ptr
  sta TA_CURSOR_SCR_ROW_PTR_LO
  lda local_metadata+TextArea::cursor_scr_row_ptr+1
  sta TA_CURSOR_SCR_ROW_PTR_HI

  lda local_metadata+TextArea::first_row_scr_row_ptr
  sta TA_FIRST_ROW_SCR_ROW_PTR_LO
  lda local_metadata+TextArea::first_row_scr_row_ptr+1
  sta TA_FIRST_ROW_SCR_ROW_PTR_HI

  lda local_metadata+TextArea::last_row_scr_row_ptr
  sta TA_LAST_ROW_SCR_ROW_PTR_LO
  lda local_metadata+TextArea::last_row_scr_row_ptr+1
  sta TA_LAST_ROW_SCR_ROW_PTR_HI

  ;jsr debug_dump_data

  rts

; initializes a text area, sets appropriate screen pointers
;
; assumes:
;   SCR_PTR_LO already set
ta_init_textarea:
  ; each row in the text area corresponds to a row in the screen.
  ; we keep track of the location of these rows for faster computation
  ; when we're editing text, moving cursors, etc.
  ; the pointer points to the beginning of the screen row, which may be
  ; further left than the margin.
  ;
  ; this data is stored in the following format:
  ;  scr_rows_lo: .byte 0,0,0...N-1 rows
  ;  scr_rows_hi: .byte 0,0,0...N-1 rows
  ; where each pair represents a row, starting with the
  ; first row of the text area.
  ;
  ; e.g. the second row is at scr_rows_lo+1, scr_rows_hi+1

  ; get the pointers to where we store the screen row pointers,
  ; which are pointers to screen memory locations

  ; get pointer to pointer data for lo byte of screen rows
  lda local_metadata+TextArea::scr_row_ptr_table_lo
  sta CMDDATA0
  lda local_metadata+TextArea::scr_row_ptr_table_lo+1
  sta CMDDATA1

  ; get pointer to pointer data for hi byte of screen rows
  lda local_metadata+TextArea::scr_row_ptr_table_hi
  sta CMDDATA2
  lda local_metadata+TextArea::scr_row_ptr_table_hi+1
  sta CMDDATA3

  ; CMDDATA4/5 are a pointer to each actual screen row
  lda SCR_PTR_LO
  sta CMDDATA4
  lda SCR_PTR_HI
  sta CMDDATA5

; skip the screen rows that are in the top margin
  ldy #0
@margin_row_loop:
  cpy local_metadata+TextArea::margin_top
  beq @margin_row_loop_done

  lda CMDDATA4
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA4
  bcc @nowrap_margin_row
  inc CMDDATA5
@nowrap_margin_row:
  iny
  jmp @margin_row_loop
@margin_row_loop_done:

  ; set base pointer to start of screen area
  lda CMDDATA4
  sta TA_SCR_PTR_LO
  sta local_metadata+TextArea::first_row_scr_row_ptr
  lda CMDDATA5
  sta TA_SCR_PTR_HI
  sta local_metadata+TextArea::first_row_scr_row_ptr+1

  ; now update all our row pointers
  ldy #0
@row_loop:
  cpy local_metadata+TextArea::height
  beq @row_done

  lda CMDDATA5
  sta (CMDDATA2),y
  sta local_metadata+TextArea::last_row_scr_row_ptr+1
  sta TA_LAST_ROW_SCR_ROW_PTR_HI
  lda CMDDATA4
  sta (CMDDATA0),y
  sta local_metadata+TextArea::last_row_scr_row_ptr
  sta TA_LAST_ROW_SCR_ROW_PTR_LO

  clc
  adc #SCREEN_WIDTH
  sta CMDDATA4
  bcc @nowrap_row
  inc CMDDATA5
@nowrap_row:
  iny
  jmp @row_loop
@row_done:
  lda local_metadata+TextArea::size
  sec
  sbc local_metadata+TextArea::width
  sta init_last_row_offset

  lda local_metadata+TextArea::first_row_data_ptr
  sta TA_FIRST_ROW_DATA_PTR_LO
  clc
  adc init_last_row_offset
  sta local_metadata+TextArea::last_row_data_ptr
  sta TA_LAST_ROW_DATA_PTR_LO

  lda local_metadata+TextArea::first_row_data_ptr+1
  sta TA_FIRST_ROW_DATA_PTR_LO+1
  adc #0
  sta local_metadata+TextArea::last_row_data_ptr+1
  sta TA_LAST_ROW_DATA_PTR_LO+1
 

  jsr int_update_cursor_pos
  jsr int_update_cursor_scr_row_ptr

  jsr ta_repaint

  jsr ta_show_cursor

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

; updates the ptr to point to the scr row that the cursor is on
; TODO: probably shouldn't overwrite CMDDATA* in int_ functions
;       so as not to introduce unexpected behaviors
int_update_cursor_scr_row_ptr:
  ldy local_metadata+TextArea::cursory

  ; get the pointer to where we store the screen row pointers
  ; it's a pointer to pointers
  lda local_metadata+TextArea::scr_row_ptr_table_lo
  sta CMDDATA2
  lda local_metadata+TextArea::scr_row_ptr_table_lo+1
  sta CMDDATA3
  lda (CMDDATA2),y
  sta local_metadata+TextArea::cursor_scr_row_ptr
  sta TA_CURSOR_SCR_ROW_PTR_LO

  lda local_metadata+TextArea::scr_row_ptr_table_hi
  sta CMDDATA4
  lda local_metadata+TextArea::scr_row_ptr_table_hi+1
  sta CMDDATA5
  lda (CMDDATA4),y
  sta local_metadata+TextArea::cursor_scr_row_ptr+1
  sta TA_CURSOR_SCR_ROW_PTR_HI

  rts

ta_hide_cursor:
  lda local_metadata+TextArea::use_cursor
  beq @done

  lda local_metadata+TextArea::cursor_scr_row_ptr
  sta CMDDATA2
  lda local_metadata+TextArea::cursor_scr_row_ptr+1
  sta CMDDATA3

  lda local_metadata+TextArea::margin_left
  clc
  adc local_metadata+TextArea::cursorx
  tay

  lda (CMDDATA2),y
  and #%01111111
  sta (CMDDATA2),y
@done:
  rts

ta_show_cursor:
  lda local_metadata+TextArea::use_cursor
  beq @done

  lda local_metadata+TextArea::cursor_scr_row_ptr
  sta CMDDATA2
  lda local_metadata+TextArea::cursor_scr_row_ptr+1
  sta CMDDATA3

  lda local_metadata+TextArea::margin_left
  clc
  adc local_metadata+TextArea::cursorx
  tay

  lda (CMDDATA2),y
  ora #%10000000
  sta (CMDDATA2),y
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
  jsr int_update_cursor_scr_row_ptr

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
  jsr int_update_cursor_scr_row_ptr

  jsr ta_show_cursor

  rts

; moves the cursor left if possible.
;
; pass CMDARG0 to define behavior when we
; wrap to the left. Zero will stay on the same
; line. Non-zero will move up a line. Used
; when we move the cursor based on arrow keys vs
; text changes.
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
  jsr int_update_cursor_scr_row_ptr
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
  jsr int_update_cursor_scr_row_ptr
@done:
  jsr ta_show_cursor

  rts

; updates a single character on the screen in
; the current row
int_update_screen_char:
  ldy local_metadata+TextArea::cursorpos
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  jsr utils_atascii_to_icode
  pha
  lda local_metadata+TextArea::margin_left
  clc
  adc local_metadata+TextArea::cursorx
  tay
  pla
  sta (TA_CURSOR_SCR_ROW_PTR_LO),y
  rts

; sets the character at the current cursor location provided in A.
; moves the cursor to the right.
;
; inputs
;   - A the character
ta_typechar:
  ldy local_metadata+TextArea::cursorpos
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
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
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
  jsr int_update_screen_char
  jsr ta_show_cursor
  rts

int_cursor_home:
  lda #0
  sta local_metadata+TextArea::cursory
  sta local_metadata+TextArea::cursorx
  sta local_metadata+TextArea::cursorpos
  jsr int_update_cursor_pos
  jsr int_update_cursor_scr_row_ptr
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
ta_repaint:
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
  lda local_metadata+TextArea::cursorpos
  sec
  sbc local_metadata+TextArea::cursorx
  tay
  ldx local_metadata+TextArea::width
  lda #' '
@loop:
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
  iny
  dex
  bne @loop
  rts

; just clears the last row. useful for scrolling
; or deleting lines
int_clear_last_row:
  lda local_metadata+TextArea::size
  sec
  sbc local_metadata+TextArea::width
  tay
  lda #' '
@loop:
  sta (TA_FIRST_ROW_DATA_PTR_LO),y
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
  sbc local_metadata+TextArea::width
  sta move_line_cursor_from ; end of previous line
@loop:
  ldy move_line_cursor_from
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  ldy move_line_cursor_to
  sta (TA_FIRST_ROW_DATA_PTR_LO),y

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
  clc
@char_loop:
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
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  sta (CMDDATA2),y
  iny
  cpy scroll_num_chars_scrolled_off
  bne @save_discarded_loop

@shift:
  ldy scroll_num_chars_scrolled_off ; start of data to pull from
  ldx #0 ; start of data to push to
@shift_loop:
  lda (TA_FIRST_ROW_DATA_PTR_LO),y ; get char to shift
  pha
  sty move_line_tempy
  txa
  tay
  pla
  sta (TA_FIRST_ROW_DATA_PTR_LO),y ; save shifted char to new loc
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
  sta (TA_FIRST_ROW_DATA_PTR_LO),y ; save backfill
  ldy move_line_tempy
  inx
  iny
  cpy scroll_num_chars_scrolled_off
  bne @backfill_loop

  jsr ta_repaint
  jsr ta_show_cursor
@done:
  rts

; shifts all lines up from the provided starting point
; - move_line_start_line_pos - should point to start of line
int_shift_lines_up:
  lda move_line_start_line_pos
  sta move_line_cursor_to    ; start of current line
  clc
  adc local_metadata+TextArea::width
  sta move_line_cursor_from  ; start of next line

  ldx local_metadata+TextArea::cursory
@row_loop:
  ldy #0
@loop:
  ldy move_line_cursor_from
  lda (TA_FIRST_ROW_DATA_PTR_LO),y
  ldy move_line_cursor_to
  sta (TA_FIRST_ROW_DATA_PTR_LO),y

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
  jsr int_clear_row
  jsr ta_repaint

  jsr ta_show_cursor
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

  jsr ta_hide_cursor

  jsr int_shift_chars_right
  jsr ta_repaint

  jsr ta_show_cursor
@done:
  rts

ta_line_delete:
  lda local_metadata+TextArea::cursory
  cmp local_metadata+TextArea::cursor_maxy
  beq @last_line ; on last line

  jsr ta_hide_cursor

  jsr int_shift_lines_up_from_cursor
@last_line:
  jsr int_clear_last_row
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

; pastes over last line with copy_buffer40
ta_paste_last_line:
  jsr ta_hide_cursor
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
  jsr ta_repaint
  jsr ta_show_cursor
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
  jsr ta_move_cursor_left

  jsr ta_show_cursor
@done:
  rts

debug_dump_data:
  lda SCR_PTR_LO
  clc
  adc #40
  sta CMDDATA0
  lda SCR_PTR_HI
  adc #0
  sta CMDDATA1
  lda #<update_marker_start
  sta CMDDATA2
  lda #>update_marker_start
  sta CMDDATA3
  jsr utils_dump_mem_row
 
  lda SCR_PTR_LO
  clc
  adc #80
  sta CMDDATA0
  lda SCR_PTR_HI
  adc #0
  sta CMDDATA1
  lda local_metadata+TextArea::first_row_data_ptr
  sta CMDDATA2
  lda local_metadata+TextArea::first_row_data_ptr+1
  sta CMDDATA3
  ldx #0
@loop:
  jsr utils_dump_mem_row
  lda CMDDATA0
  clc
  adc #40
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  lda CMDDATA2
  clc
  adc #8
  sta CMDDATA2
  lda CMDDATA3
  adc #0
  sta CMDDATA3
  
  inx
  cpx #15
  bne @loop
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

init_last_row_offset:     .byte 0

repaint_tmp0:             .byte 0
repaint_tmp1:             .byte 0

get_line_offset:            .byte 0
get_line_num_chars:            .byte 0

debug_tmp0: .byte 0

; internal copy
local_metadata: .tag TextArea

