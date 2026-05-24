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

.EXPORT ti_init
.EXPORT ti_set_metadata
.EXPORT ti_scr_ptr
.EXPORT ti_move_cursor_down
.EXPORT ti_show_cursor



; interface needed:
;   set cursor position
;   move cursor up/down, left/right
;   shift+clear
;     - clear all data, move cursor top left
;   insert line
;     - moves all lines down from current cursor
;   insert char
;     - writes a space under current cursor
;     - moves all characters after cursor to right
;   backspace (atari style)
;     - erases character under cursor
;     - move cursor left
;     - no shifting of data
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
; expects:
;   cursorx, cursory, width to be set
cursor_to_local_pos:
  clc
  lda #0
  tax
@row_loop:
  cpx cursory
  beq @row_loop_done
  adc width
  inx
  jmp @row_loop
@row_loop_done:
  adc cursorx
  sta cursorpos
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
  iny
  cpy margin_top
  beq @margin_row_loop_done

  lda CMDDATA4
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA4
  bcc @nowrap_margin_row
  inc CMDDATA5
@nowrap_margin_row:
  jmp @margin_row_loop
@margin_row_loop_done:

  ; now update all our row pointers
  ldy #0
@row_loop:
  lda CMDDATA4
  sta (CMDDATA0),y
  lda CMDDATA5
  sta (CMDDATA2),y

  iny
  cpy height
  beq @row_done

  lda CMDDATA4
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA4
  bcc @nowrap_row
  inc CMDDATA5
@nowrap_row:
  jmp @row_loop
@row_done:
  jsr update_cursor_scr_row_ptr
  jsr copy_out
  rts

; moves the cursor down a row if possible
ti_move_cursor_down:
  lda cursory
  cmp height
  bcs @ignore

  lda #CURSOR_FLAG_DISABLE
  sta CMDDATA0
  jsr ti_show_cursor

  inc cursory
  jsr update_cursor_scr_row_ptr

  lda #CURSOR_FLAG_ENABLE
  sta CMDDATA0
  jsr ti_show_cursor

  jsr copy_out
@ignore:
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

  lda scr_rows_ptr_loc_hi
  sta CMDDATA4
  lda scr_rows_ptr_loc_hi+1
  sta CMDDATA5
  lda (CMDDATA4),y
  sta cursor_scr_row_ptr+1

  rts

; shows the cursor
; inputs:
;   CMDDATA0   - CURSOR_FLAG
ti_show_cursor:
  lda cursor_scr_row_ptr
  sta CMDDATA2
  lda cursor_scr_row_ptr+1
  sta CMDDATA3

  lda margin_left
  clc
  adc cursorx
  tay

  lda #CURSOR_FLAG_ENABLE
  bit CMDDATA0
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

; moves the cursor up a row
;
; inputs:
;   CMDDATA0/1 - ptr to the text input struct
ti_move_cursor_up:
  rts

ti_move_cursor_left:
  rts

ti_move_cursor_right:
  rts

; shifts all data from the cursor onwards to the right
; inputs:
;   CMDDATA0/1 - ptr to the text input struct
;   CMDDATA2/3 - ptr to the text input data
ti_shift_data_right:
  ldy #INPUTS_CURSORPOS_OFFSET
  lda (CMDDATA0),y
  sta cursorpos
  ldy #INPUTS_SIZE_OFFSET
  lda (CMDDATA0),y
  sta size
  tay
  dey
@loop:
  cpy cursorpos
  bcc @done
  dey
  lda (CMDDATA2),y
  iny
  sta (CMDDATA2),y
  dey
  jmp @loop
@done:
  rts

ti_insert_char:
  rts

; calculates the screen position given a relative x and y position
;
; input args:
;   CMDDATA0/1 - ptr to the textinput struct
;   CMDDATA2   - x position relative to left of text input
;   CMDDATA3   - y position relative to top of text input
; output args:
;   CMDDATA4/5 - absolute ptr to position relative to start of screen
; modifies:
;   a, x, y
ti_scr_ptr:
  lda SCR_PTR_LO
  sta CMDDATA4
  lda SCR_PTR_HI
  sta CMDDATA5
  ldx #0
@row_loop:
  cpx CMDDATA2
  beq @row_done
  lda CMDDATA4
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA4
  bcc @nowrap_row
  inc CMDDATA5
@nowrap_row:
  inx
  bne @row_loop
@row_done:
  ; now add the left margin and the given offset
  ldy #INPUTS_MARGIN_LEFT_OFFSET
  lda (CMDDATA0),y
  sta margin_left
  ldy #INPUTS_CURSORX_OFFSET
  lda (CMDDATA0),y
  sta cursorx

  lda CMDDATA4
  clc
  adc cursorx
  adc margin_left
  sta CMDDATA4
  bcc @nowrap_col
  inc CMDDATA5
@nowrap_col:
  rts

ti_scr_move_cursor_home:
  lda #0
  sta cursorx
  sta cursory
  rts

ti_copy_input_struct:
  rts

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
cursorpos:           .byte 0   ; cursor position relative to upper left of input area
cursor_scr_row_ptr:  .byte 0,0 ; ptr screen memory at start of row where cursor resides
metadata_end:
METADATA_SIZE = metadata_end-metadata

