.setcpu "6502"
.include "line_input.inc"
.include "globals.inc"
.include "macros.inc"

.segment "ZEROPAGE"

li_metadata:           .tag LineInput
context_ptr_lo:        .res 1
context_ptr_hi:        .res 1

.segment "CODE"

li_init_context:
  lda #0
  sta context_ptr_lo
  sta context_ptr_hi
  rts

; sets the context for the line input to the LineInput
; pointed to by CMDDATA0/1. Make sure that you called
; li_init_context first or you might get some garbage.
;
; inputs:
;   CMDDATA0/1 - pointer to a line input
li_set_context:
  ; exit early if context already matches
  lda CMDDATA0
  cmp context_ptr_lo
  bne do_switch
  lda CMDDATA1
  cmp context_ptr_hi
  beq set_context_done
do_switch:
  lda context_ptr_hi
  bne cache_exists
  lda context_ptr_lo
  beq no_cache
cache_exists:
  ; copy our local cache to the existing source LineInput
  copy_struct_abs_to_zp li_metadata, context_ptr_lo, LineInput
no_cache:
  ; now point to the new line input
  lda CMDDATA0
  sta context_ptr_lo
  lda CMDDATA1
  sta context_ptr_hi

  ; copy data from the new LineInput to the local cache in
  ; the zero page.
  copy_struct_zp_to_abs context_ptr_lo, li_metadata, LineInput
set_context_done:
  rts

li_repaint:
  ldy li_metadata+LineInput::scr_width
  dey
  lda #$00
@loop:
  sta (scr_ptr_lo),y
  dey
  bpl @loop
  rts

li_reset:
  rts

li_hide_cursor:
  ldy li_metadata+LineInput::scr_cursor
  lda (scr_ptr_lo),y
  and #%01111111
  sta (scr_ptr_lo),y
@done:
  rts

li_show_cursor:
  ldy li_metadata+LineInput::scr_cursor
  lda (scr_ptr_lo),y
  ora #%10000000
  sta (scr_ptr_lo),y
@done:
  rts

li_move_cursor_left:
  lda li_metadata+LineInput::data_cursor
  beq @done

  jsr li_hide_cursor

  lda li_metadata+LineInput::scr_cursor
  beq @scroll

  dec li_metadata+LineInput::scr_cursor
  dec li_metadata+LineInput::data_cursor
  jmp @show_cursor
@scroll:
@show_cursor:
  jsr li_show_cursor
@done:
  rts

li_move_cursor_right:
  lda li_metadata+LineInput::data_cursor
  cmp li_metadata+LineInput::data_len
  bcc @move_allowed
  bcs @done
@move_allowed:
  jsr li_hide_cursor

  lda li_metadata+LineInput::scr_cursor
  cmp li_metadata+LineInput::scr_width
  beq @scroll

  inc li_metadata+LineInput::scr_cursor
  inc li_metadata+LineInput::data_cursor
  jmp @show_cursor
@scroll:
@show_cursor:
  jsr li_show_cursor

@done:
  rts

li_char_delete:
  rts

li_char_insert:
  rts

li_type_char:
  rts

li_backspace:
  rts

li_shift_clear:
  jsr li_hide_cursor
  jsr int_cursor_home
  jsr int_clear
  jsr li_repaint
  jsr li_show_cursor

  rts

; clears the data
; modifies:
;   a,y
int_clear:
  lda li_metadata+LineInput::data_len
  dey
  lda #' '
@loop:
  sta (data_ptr_lo),y
  dey
  bne @loop
  sta (data_ptr_lo),y
  rts

int_cursor_home:
  lda #0
  sta li_metadata+LineInput::scr_cursor
  sta li_metadata+LineInput::data_cursor
  rts

