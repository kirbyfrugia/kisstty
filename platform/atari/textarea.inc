; This implements a text area component with a cursor. 
; You can create your own text areas and can have more than one
; on the screen at a time, each with its own cursor.
;
; It supports readonly and editable.
;
; The ta_* routines do all operations on a TextArea struct
; in the zero page. To do operations on your TextArea, you set
; the context. The context is simply a pointer to a text area.
;
; When setting the context, the following happens:
; 1. It copies the zero page TextArea to existing context ptr
;    location. The full TextArea struct.
; 2. It then copies the new TextArea to the ZP TextArea.
; 3. It then updates its pointer to the location of the new
;    TextArea so that it can do Step (1) if the context
;    is changed again.
;
; Note: the source only gets updated when a new context is set.
;       However, the source cursor data updates any time the cursor
;       changes.
;

.ifndef TEXT_AREA_INC
TEXT_AREA_INC = 1

.globalzp ta_metadata
.globalzp temp_line_scr_ptr_lo
.globalzp temp_line_scr_ptr_hi
.globalzp temp_line_data_ptr_lo
.globalzp temp_line_data_ptr_hi
.global   ta_init_context
.global   ta_set_context
.global   ta_push_context
.global   ta_pop_context
.global   ta_hide_cursor
.global   ta_move_cursor_to_start_of_last_line
.global   ta_show_cursor
.global   ta_shift_clear
.global   ta_repaint
.global   ta_clear_and_repaint
.global   ta_bytes_remaining
.global   ta_find_last_line

.global   ta_edit_move_cursor_up
.global   ta_edit_move_cursor_down
.global   ta_edit_move_cursor_left
.global   ta_edit_move_cursor_right
.global   ta_edit_type_char
.global   ta_edit_backspace
.global   ta_edit_line_insert
.global   ta_edit_char_insert
.global   ta_edit_line_delete
.global   ta_edit_char_delete
.global   ta_out_append_char
.global   ta_out_append_lines
.global   ta_out_next_line
.global   ta_out_println

first_line_data_ptr_lo    = ta_metadata+TextArea::first_line_data_ptr
first_line_data_ptr_hi    = ta_metadata+TextArea::first_line_data_ptr+1
first_line_scr_ptr_lo     = ta_metadata+TextArea::first_line_scr_ptr
first_line_scr_ptr_hi     = ta_metadata+TextArea::first_line_scr_ptr+1
cursor_line_scr_ptr_lo    = ta_metadata+TextArea::cursor_line_scr_ptr
cursor_line_scr_ptr_hi    = ta_metadata+TextArea::cursor_line_scr_ptr+1
cursor_line_data_ptr_lo   = ta_metadata+TextArea::cursor_line_data_ptr
cursor_line_data_ptr_hi   = ta_metadata+TextArea::cursor_line_data_ptr+1

TA_EOL                            = $0d
TA_TYPE_INPUT                     = %10000000
TA_TYPE_OUTPUT                    = %01000000
TA_SCROLL_BACKFILL_ENABLED        = %10000000 ; when scrolling, backfill
TA_SCROLL_SAVE_DISCARDED_ENABLED  = %01000000 ; when scrolling, save discarded
TA_SCROLL_JUST_SCROLL             = %00000000
CURSOR_FLAG_WRAP_SAME_LINE        = %10000000
CURSOR_FLAG_WRAP_DIFF_LINE        = %00000000
CURSOR_FLAG_ENABLED               = %10000000
CURSOR_FLAG_DISABLED              = %00000000
CURSOR_BEHAVIOR_WRAP_CHANGE_LINES = %10000000
CURSOR_BEHAVIOR_WRAP_SAME_LINE    = %00000000

.struct TextArea
  first_line_scr_ptr   .word
  first_line_data_ptr  .word
  cursor_line_scr_ptr  .word
  cursor_line_data_ptr .word
  size                 .word
  width                .byte
  height               .byte
  cursorx              .byte
  cursory              .byte
  cursor_maxx          .byte
  cursor_maxy          .byte
  type                 .byte
  pending_newline      .byte
.endstruct

.endif
