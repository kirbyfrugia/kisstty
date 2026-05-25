; This implements a text input component with a cursor. 
; You can create your own text inputs and can have more than one
; on the screen at a time, each with its own cursor.
;
; The logic needed for everything is contained in this file.
; To use it, make an EXACT copy of the struct at the bottom of the file,
; and any time you want to call a function from this file,
; just make sure that it's operating on a copy of your metadata.
;
; This isn't super efficient. If you're frequently changing between
; text inputs, you're doing a fair amount of copying. If performance
; is an issue, this is a good place to look for improvements.
;
; General usage 
;   ti_set_metadata - copies your metadata to local storage here
;                     and keeps a pointer to your metadata
;                     for updating. Any time you call this, you
;                     replace the local storage and update pointers
;   ti_init         - used to initialize the text input once you
;                     know where on the screen it will be
;   ti_*            - functions that operate on the component. if
;                     any metadata changes, these functions will
;                     copy the locally stored metadata to your source.
;
; Commands take arguments from CMDDATA.*
;   NOTE: there is heavy usage of CMDDATA.* vars internally,
;         so there's no guarantee that the data in these
;         won't be modified when you call any function here.
;
.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "textinput.inc"
.SEGMENT "CODE"

.IMPORT utils_atascii_to_icode
.IMPORT utils_dump_mem_row
.EXPORT ti_init
.EXPORT ti_set_metadata
.EXPORT ti_move_cursor_up
.EXPORT ti_move_cursor_down
.EXPORT ti_move_cursor_left
.EXPORT ti_move_cursor_right
.EXPORT ti_show_cursor
.EXPORT ti_typechar
.EXPORT ti_backspace
.EXPORT ti_shift_clear
.EXPORT ti_line_insert
.EXPORT ti_char_insert
.EXPORT ti_line_delete
.EXPORT ti_char_delete

; takes source text input metadata and copies it
; to local storage, including the pointer to
; this metadata.
;
; inputs:
;   CMDDATA0/1 - ptr to the source metadata struct
ti_set_metadata:
  lda CMDDATA0
  sta TI_METADATA_PTR_LO
  lda CMDDATA1
  sta TI_METADATA_PTR_HI

  ldy #(METADATA_SIZE-1)
@loop:
  lda (TI_METADATA_PTR_LO),y
  sta metadata,y
  dey
  bpl @loop

  lda data_ptr
  sta TI_DATA_PTR_LO 
  lda data_ptr+1
  sta TI_DATA_PTR_HI
  rts

; takes our local text input metadata and copies it out
;
; inputs:
;   CMDDATA0/1 - ptr to the text input struct
copy_out:
  ldy #(METADATA_SIZE-1)
@loop:
  lda metadata,y
  sta (TI_METADATA_PTR_LO),y
  dey
  bpl @loop
  rts


; initializes a text input, sets appropriate screen pointers
;
; assumes:
;   SCR_PTR_LO already set
ti_init:
  ; each row in the text input corresponds to a row in the screen.
  ; we keep track of the location of these rows for faster computation
  ; when we're editing text, moving cursors, etc.
  ; the pointer points to the beginning of the screen row, which may be
  ; further left than the margin.
  ;
  ; this data is stored in the following format:
  ;  scr_rows_lo: .byte 0,0,0
  ;  scr_rows_hi: .byte 0,0,0
  ; where each pair represents a row, starting with the
  ; first row of the text input. each index is a row.
  ;
  ; any text input will have its own location in memory
  ; where this data is stored, and it's pointed at by
  ; the metadata struct scr_rows_ptr_loc_lo/hi.

  ; get the pointers to where we store the screen row pointers,
  ; which are pointers to screen memory locations

  ; get pointer to pointer data for lo byte of screen rows
  lda scr_rows_ptr_loc_lo
  sta CMDDATA0
  lda scr_rows_ptr_loc_lo+1
  sta CMDDATA1

  ; get pointer to pointer data for hi byte of screen rows
  lda scr_rows_ptr_loc_hi
  sta CMDDATA2
  lda scr_rows_ptr_loc_hi+1
  sta CMDDATA3

  ; CMDDATA4/5 are a pointer to each actual screen row
  lda SCR_PTR_LO
  sta CMDDATA4
  lda SCR_PTR_HI
  sta CMDDATA5

; skip the screen rows that are in the margin
  ldy #0
@margin_row_loop:
  cpy margin_top
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

  lda CMDDATA4
  sta TI_SCR_PTR_LO
  lda CMDDATA5
  sta TI_SCR_PTR_HI
  ; now update all our row pointers
  ldy #0
@row_loop:
  cpy height
  beq @row_done

  lda CMDDATA5
  sta (CMDDATA2),y
  lda CMDDATA4
  sta (CMDDATA0),y

  clc
  adc #SCREEN_WIDTH
  sta CMDDATA4
  bcc @nowrap_row
  inc CMDDATA5
@nowrap_row:
  iny
  jmp @row_loop
@row_done:
  jsr update_cursor_pos
  jsr update_cursor_scr_row_ptr

  lda #CURSOR_FLAG_ENABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  jsr copy_out
  rts



; interface needed:
;   set cursor position
;   move cursor up/down, left/right
;   insert char
;     - writes a space under current cursor
;     - moves all characters after cursor to right
;   backspace (other style, later)
;     - erase character under cursor
;     - shift all data after cursor left
;   delete line
;     - removes whole line
;     - moves subsequent lines up
;   delete char (at cursor)
;     - moves all characters after cursor one char to the left

; raw composable functions needed
;   Note: keep data separate from presentation
;   set cursor position
;   move cursor left/right/up/down
;   hide/show cursor
;   redraw row (with offset)
;   redraw
;   insert char
;   delete char
;   delete row (with offset)
;   replace char


; internal use only, updates the local cursor pos
; given the current cursor x and y
update_cursor_pos:
  clc
  lda #0
  tax
@row_loop:
  cpx cursory
  beq @row_loop_done
  clc
  adc width
  inx
  bne @row_loop
@row_loop_done:
  clc
  ;adc margin_left
  adc cursorx
  sta cursorpos
  rts

; internal only, assumes local_data is populated
update_cursor_scr_row_ptr:
  ldy cursory

  ; get the pointer to where we store the screen row pointers
  ; it's a pointer to pointers
  lda scr_rows_ptr_loc_lo
  sta CMDDATA2
  lda scr_rows_ptr_loc_lo+1
  sta CMDDATA3
  lda (CMDDATA2),y
  sta cursor_scr_row_ptr
  sta TI_SCR_ROW_PTR_LO

  lda scr_rows_ptr_loc_hi
  sta CMDDATA4
  lda scr_rows_ptr_loc_hi+1
  sta CMDDATA5
  lda (CMDDATA4),y
  sta cursor_scr_row_ptr+1
  sta TI_SCR_ROW_PTR_HI

  rts

; shows the cursor
; inputs:
;   CMDDATA0   - CURSOR_FLAG
ti_show_cursor:
  lda CMDDATA0
  sta show_cursor_var0
internal_show_cursor:
  lda cursor_scr_row_ptr
  sta CMDDATA2
  lda cursor_scr_row_ptr+1
  sta CMDDATA3

  lda margin_left
  clc
  adc cursorx
  tay

  lda #CURSOR_FLAG_ENABLE
  bit show_cursor_var0
  bmi @show_cursor
  
  lda (CMDDATA2),y
  and #%01111111
  sta (CMDDATA2),y
  jmp @done
@show_cursor:
  lda (CMDDATA2),y
  ora #%10000000
  sta (CMDDATA2),y
@done:
  rts

ti_move_cursor_up:
  lda #CURSOR_FLAG_DISABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  lda cursory
  beq @wrapped
  dec cursory
  jmp @updated
@wrapped:
  lda cursor_maxy
  sta cursory
@updated:
  jsr update_cursor_pos
  jsr update_cursor_scr_row_ptr

  lda #CURSOR_FLAG_ENABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  jsr copy_out

  rts

ti_move_cursor_down:
  lda #CURSOR_FLAG_DISABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  lda cursory
  cmp cursor_maxy
  beq @wrapped

  inc cursory
  bne @updated
@wrapped:
  lda #0
  sta cursory
@updated:
  jsr update_cursor_pos
  jsr update_cursor_scr_row_ptr

  lda #CURSOR_FLAG_ENABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  jsr copy_out
  rts

; moves the cursor left if possible.
;
; pass CMDARG0 to define behavior when we
; wrap to the left. Zero will stay on the same
; line. Non-zero will move up a line. Used
; when we move the cursor based on arrow keys vs
; text changes.
;
; inputs:
;   - CMDDATA0 - BIT 7 determines be
ti_move_cursor_left:
  lda #CURSOR_FLAG_DISABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  lda cursorx
  beq @wrapped
  dec cursorx
  jmp @updated
@wrapped:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  bit CMDDATA0
  bmi @wrapped_change_lines

  ; if here, just wrap around on the same line
  lda cursor_maxx
  sta cursorx
  bne @updated
@wrapped_change_lines:
  lda cursory
  beq @done ; already at top, just ignore movement

  ; move up a line
  dec cursory
  ; and move to the end of it
  lda cursor_maxx
  sta cursorx
@updated:
  jsr update_cursor_pos
  jsr update_cursor_scr_row_ptr
@done:
  lda #CURSOR_FLAG_ENABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  jsr copy_out
  rts

ti_move_cursor_right:
  lda #CURSOR_FLAG_DISABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  lda cursorx
  cmp cursor_maxx
  beq @wrapped

  inc cursorx
  bne @updated
@wrapped:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  bit CMDDATA0
  bmi @wrapped_change_lines

  ; if here, just wrap around on the same line
  lda #0
  sta cursorx
  beq @updated
@wrapped_change_lines:
  lda cursory
  cmp cursor_maxy
  beq @done; already at bottom

  ; move down a line
  inc cursory
  ; and move to the start of it
  lda #0
  sta cursorx
@updated:
  jsr update_cursor_pos
  jsr update_cursor_scr_row_ptr
@done:
  lda #CURSOR_FLAG_ENABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  jsr copy_out
  rts

; updates a single character on the screen in
; the current row
internal_update_screen_char:
  ldy cursorpos
  lda (TI_DATA_PTR_LO),y
  jsr utils_atascii_to_icode
  pha
  lda margin_left
  clc
  adc cursorx
  tay
  pla
  sta (TI_SCR_ROW_PTR_LO),y
  rts

; sets the character at the current cursor location provided in A.
; moves the cursor to the right.
;
; inputs
;   - A the character
ti_typechar:
  ldy cursorpos
  sta (TI_DATA_PTR_LO),y
  jsr internal_update_screen_char
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  sta CMDDATA0
  jsr ti_move_cursor_right
  rts

; erases character under cursor, moves cursor left.
; atari style doesn't shift data left.
ti_backspace:
  lda #CURSOR_BEHAVIOR_WRAP_CHANGE_LINES
  sta CMDDATA0
  jsr ti_move_cursor_left
  ldy cursorpos
  lda #' '
  sta (TI_DATA_PTR_LO),y
  jsr internal_update_screen_char
  lda #CURSOR_FLAG_ENABLE
  sta show_cursor_var0
  jsr internal_show_cursor
  rts

internal_cursor_home:
  lda #0
  sta cursory
  sta cursorx
  sta cursorpos
  jsr update_cursor_pos
  jsr update_cursor_scr_row_ptr
  rts

; clears all data between the markers
; inputs:
;   - update_marker_start (position to start)
;   - update_marker_end   (position to end, exclusive)
internal_clear_data:
  ldy update_marker_start
@loop:
  lda #' '
  sta (TI_DATA_PTR_LO),y
  iny
  cpy update_marker_end
  bcc @loop
  rts


; repaints the entire screen area for the input
; box. Useful when data changes. Not so efficient,
; but I'll worry about that later.
; basic algorithm:
; start at the first screen row where our input lives.
; have a loop that starts margin_left over and goes until width
; keep a cursor counter for the actual data.
internal_repaint:
  ; lo byte pointer to first row
  lda scr_rows_ptr_loc_lo
  sta CMDDATA0
  lda scr_rows_ptr_loc_lo+1
  sta CMDDATA1

  ; hi byte pointer to first row
  lda scr_rows_ptr_loc_hi
  sta CMDDATA2
  lda scr_rows_ptr_loc_hi+1
  sta CMDDATA3

  ; now save the ptr to first row
  ldy #0
  lda (CMDDATA0),y
  sta CMDDATA0
  lda (CMDDATA2),y
  sta CMDDATA1

  ldx #0 ; temporary cursor
@screen_row_loop:
  lda margin_left
  tay
  lda width
  clc
  adc #2
  sta repaint_tmp1
@screen_col_loop:
  sty repaint_tmp0
  txa
  tay
  lda (TI_DATA_PTR_LO),y
  jsr utils_atascii_to_icode
  ldy repaint_tmp0
  sta (CMDDATA0),y
  inx
  iny
  cpy repaint_tmp1
  bcc @screen_col_loop
  cpx size
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
internal_clear_row:
  lda cursorpos
  sec
  sbc cursorx
  tay
  ldx width
  lda #' '
@loop:
  sta (TI_DATA_PTR_LO),y
  iny
  dex
  bne @loop
  rts

; clears all data in the input and returns the cursor home
ti_shift_clear:
  lda #CURSOR_FLAG_DISABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  lda #0
  sta update_marker_start
  lda size
  sta update_marker_end
  jsr internal_clear_data

  jsr internal_cursor_home
  jsr internal_repaint

  jsr copy_out

  lda #CURSOR_FLAG_ENABLE
  sta show_cursor_var0
  jsr internal_show_cursor
  rts

internal_shift_lines_down:
  ; first find the start of the line we're on
  lda cursorpos
  sec
  sbc cursorx
  sta move_line_start_line_pos
  lda size
  sec
  sbc #1
  sta move_line_cursor_to ; end of last line
  sbc width
  sta move_line_cursor_from ; end of previous line
@loop:
  ldy move_line_cursor_from
  lda (TI_DATA_PTR_LO),y
  ldy move_line_cursor_to
  sta (TI_DATA_PTR_LO),y

  lda move_line_start_line_pos
  cmp move_line_cursor_from
  beq @done
  dec move_line_cursor_to
  dec move_line_cursor_from
  jmp @loop
@done:

  rts

; moves all lines down from current cursor
; including current line and clears current line
; cursor stays where it is.
ti_line_insert:
  lda cursory
  cmp cursor_maxy
  beq @done

  lda #CURSOR_FLAG_DISABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  jsr internal_shift_lines_down
  jsr internal_clear_row
  jsr internal_repaint

  jsr copy_out

  lda #CURSOR_FLAG_ENABLE
  sta show_cursor_var0
  jsr internal_show_cursor
@done:
  rts

; shifts all characters from cursor to the
; right to the right
internal_shift_chars_right:
  ldy size
  dey
@loop:
  dey
  cpy cursorpos
  beq @first_char
  lda (TI_DATA_PTR_LO),y
  iny
  sta (TI_DATA_PTR_LO),y
  cpy #1
  beq @done
  dey
  jmp @loop
@first_char:
  lda (TI_DATA_PTR_LO),y
  iny
  sta (TI_DATA_PTR_LO),y
  dey
  lda #' '
  sta (TI_DATA_PTR_LO),y
@done:
  rts

ti_char_insert:
  ldy cursorpos
  iny
  beq @done ; rolled over
  cpy size
  bcs @done ; at or beyond last char

  lda #CURSOR_FLAG_DISABLE
  sta show_cursor_var0
  jsr internal_show_cursor

  jsr internal_shift_chars_right
  jsr internal_repaint

  jsr copy_out

  lda #CURSOR_FLAG_ENABLE
  sta show_cursor_var0
  jsr internal_show_cursor
@done:
  rts

ti_line_delete:
  rts

ti_char_delete:
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
  lda data_ptr
  sta CMDDATA2
  lda data_ptr+1
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
  cpx #10
  bne @loop
  rts


newchar0: .byte 0
show_cursor_var0: .byte 0
update_marker_start: .byte 0
update_marker_end:   .byte 0

move_line_start_line_pos: .byte 0
move_line_cursor_from:    .byte 0
move_line_cursor_to:      .byte 0

repaint_tmp0:             .byte 0
repaint_tmp1:             .byte 0

; internal copy
metadata:
data_ptr:            .byte 0,0 ; ptr to input area data
scr_rows_ptr_loc_lo: .byte 0,0 ; ptr to table of pointers for location of start of each screen row, lo byte
scr_rows_ptr_loc_hi: .byte 0,0 ; ptr to table of pointers for location of start of each screen row, hi byte
margin_left:         .byte 0   ; margin from left of screen to left of text area
margin_top:          .byte 0   ; margin from top of screen to top of text area
width:               .byte 0   ; width of area in screen columns
height:              .byte 0   ; height of area in screen rows
size:                .byte 0   ; number of characters for input area
cursorx:             .byte 0   ; cursor x position relative to upper left of input area
cursory:             .byte 0   ; cursor y position relative to upper left of input area
cursor_maxx:         .byte 0   ; maximum x position for cursor relative to upper left of input area
cursor_maxy:         .byte 0   ; maximum y position for cursor relative to upper left of input area
cursorpos:           .byte 0   ; cursor position relative to upper left of input area
cursor_scr_row_ptr:  .byte 0,0 ; ptr screen memory at start of row where cursor resides
metadata_end:
METADATA_SIZE = metadata_end-metadata

