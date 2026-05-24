.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "textinput.inc"
.SEGMENT "CODE"

.EXPORT ti_init
.EXPORT ti_scr_ptr
.EXPORT ti_set_cursor
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

; copies the given text input to local storage for ease
; assumes that struct sizes match
;
; inputs:
;   CMDDATA0/1 - ptr to the text input struct
copy_local:
  ldy #(LOCALDATA_SIZE-1)
@loop:
  lda (CMDDATA0),y
  sta localdata,y
  dey
  bpl @loop
  rts

; initializes a text input, sets appropriate screen pointers
;
; inputs:
;   CMDDATA0/1 - ptr to the text input struct
;   CMDDATA2/3 - used internally, no need to set, ptr to the text input screen point row lookup, lo bytes
;   CMDDATA4/5 - used internally, no need to set, ptr to the text input screen point row lookup, hi bytes
;   CMDDATA6/7 - used internally, no need to set, temp buffer
; assumes:
;   SCR_PTR_LO already set
ti_init:
  jsr copy_local

  ; get the pointer to where we store the screen row pointers
  ; it's a pointer to pointers
  lda scr_rows_ptr_loc_lo
  sta CMDDATA2
  lda scr_rows_ptr_loc_lo+1
  sta CMDDATA3

  lda scr_rows_ptr_loc_hi
  sta CMDDATA4
  lda scr_rows_ptr_loc_hi+1
  sta CMDDATA5

  lda SCR_PTR_LO
  sta CMDDATA6
  lda SCR_PTR_HI
  sta CMDDATA7

; skip the screen rows that are the margin
  ldy #0
@margin_row_loop:
  iny
  cpy margin_top
  beq @margin_row_loop_done

  lda CMDDATA6
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA6
  bcc @nowrap_margin_row
  inc CMDDATA7
@nowrap_margin_row:
  jmp @margin_row_loop
@margin_row_loop_done:

  ldy #0
@row_loop:
  lda CMDDATA6
  sta (CMDDATA2),y
  lda CMDDATA7
  sta (CMDDATA4),y

  iny
  cpy height
  beq @row_done

  lda CMDDATA6
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA6
  bcc @nowrap_row
  inc CMDDATA7
@nowrap_row:
  jmp @row_loop
@row_done:
  rts

; sets the cursor to the given position
;
; inputs:
;   CMDDATA0/1 - ptr to the text input struct
;   CMDDATA2   - cursor x position
;   CMDDATA3   - cursor y position
ti_set_cursor:
  lda CMDDATA2
  sta cursorx
  lda CMDDATA3
  sta cursory
  ldy #INPUTS_WIDTH_OFFSET
  lda (CMDDATA0),y
  sta width
  jsr cursor_to_local_pos
  lda cursorpos
  ldy #INPUTS_CURSORPOS_OFFSET
  sta (CMDDATA0),y
  rts

; hides the cursor
;
; inputs:
;   CMDDATA0/1 - ptr to the text input struct
ti_hide_cursor:
  rts

; internal only, assumes local_data is populated
; WARN:
;   modifies CMDDATA2/3/4/5
update_scr_coords_current_row:
  ldy cursory

  ; get the pointer to where we store the screen row pointers
  ; it's a pointer to pointers
  lda scr_rows_ptr_loc_lo
  sta CMDDATA2
  lda scr_rows_ptr_loc_lo+1
  sta CMDDATA3
  lda (CMDDATA2),y
  sta scr_coords_current_row

  lda scr_rows_ptr_loc_hi
  sta CMDDATA4
  lda scr_rows_ptr_loc_hi+1
  sta CMDDATA5
  lda (CMDDATA4),y
  sta scr_coords_current_row+1

  rts

; shows the cursor
;
; inputs:
;   CMDDATA0/1 - ptr to the text input struct
;   CMDDATA2/3 - used internally, no need to set, ptr to the text input screen point row lookup, lo bytes
;   CMDDATA4/5 - used internally, no need to set, ptr to the text input screen point row lookup, hi bytes
;   CMDDATA6   - CURSOR_FLAG
ti_show_cursor:
  jsr copy_local
  jsr update_scr_coords_current_row

  lda scr_coords_current_row
  sta CMDDATA2
  lda scr_coords_current_row+1
  sta CMDDATA3

  lda margin_left
  clc
  adc cursory
  tay

  lda #CURSOR_FLAG_ENABLE
  bit CMDDATA6
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

ti_move_cursor_down:
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

ti_scr_hide_cursor:
  rts

ti_scr_move_cursor_home:
  lda #0
  sta cursorx
  sta cursory
  rts

ti_copy_input_struct:
  rts

scr_coords_current_row: .byte 0,0

; internal copy
localdata:
data_ptr:            .byte 0,0
scr_rows_ptr_loc_lo: .byte 0,0
scr_rows_ptr_loc_hi: .byte 0,0
margin_left:         .byte 0
margin_right:        .byte 0
margin_top:          .byte 0
margin_btm:          .byte 0
width:               .byte 0
height:              .byte 0
size:                .byte 0
cursorx:             .byte 0
cursory:             .byte 0
cursorpos:           .byte 0
localdata_end:
LOCALDATA_SIZE = localdata_end-localdata
