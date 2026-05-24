.SETCPU "6502"
.INCLUDE "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.INCLUDE "macros.inc"
.INCLUDE "common.inc"

MAX_INPUT_LEN = 114
WOZMON        = $9800
RS232_CHANNEL = 32    ; channel 2 (2 * 16)

; Note: there is some code here that assumes that
;  the full input area is <256 bytes long. So keep
CURSOR_MINX   = 2
CURSOR_MAXX   = 38
CURSOR_MINY   = 21
CURSOR_MAXY   = 23

; size of whole buffer, including margins
SCR_INPUT_BUFFER_SIZE = (CURSOR_MAXY-CURSOR_MINY+1)*40

.IMPORT boot850_check 
.IMPORT boot850_bootstrap 
.IMPORT utils_atascii_to_icode
.IMPORT utils_byte_to_scr_hex
.IMPORT utils_dump_mem_row
.IMPORT rs232_open
.IMPORT rs232_close
.IMPORT rs232_status
.IMPORT rs232_getchr
.IMPORT rs232_putchr
.IMPORT rs232_last_status
.IMPORT rs232_input_buffer_size
.IMPORT rs232_output_buffer_size
.IMPORT kbd_unmodified
.IMPORT kbd_shifted
.IMPORT kbd_ctrld
.IMPORT mti_init
.IMPORT mti_main_input_struct
.IMPORT mti_tmp_dump_data
.IMPORT ti_scr_ptr
.IMPORT ti_set_cursor
.IMPORT ti_hide_cursor
.IMPORT ti_show_cursor

.ifdef DEBUG
.IMPORT wozmon_main
.endif

.SEGMENT "CODE"

.EXPORT start
start:
.ifdef DEBUG
  lda #<wozmon_main
  sta $0206
  lda #>wozmon_main
  sta $0207
  cli ; for brk to work
.endif
  jsr init
  ; TODO: remove this once screen editor working
  jmp @loop
  jsr boot850_check
  bcc @rhandler_loaded
@bootstrap850:
  jsr boot850_bootstrap
  bcc @rhandler_loaded
  ;print_str str_850error
  jmp @main
@rhandler_loaded:
  ;print_str str_850loaded
@main:
  ;print_str str_supported_commands
  ;print_str str_commands
@loop:
  jsr inkbd
  jmp @loop
  ; ask for input
  ;print_bytes str_get_command, str_get_command_end

  ; read user input
  ldx #0
  lda #<user_input_buf
  sta ICBAL,x
  lda #>user_input_buf
  sta ICBAH,x

  lda #<MAX_INPUT_LEN
  sta ICBLL,x
  lda #>MAX_INPUT_LEN
  sta ICBLH,x

  lda #GETREC
  sta ICCOM,x
  jsr CIOV

  ; echo back user command
  ldx #0
  lda #PUTREC
  sta ICCOM,x
  jsr CIOV

  lda user_input_buf 
  cmp #'B'
  beq @ui_b
  cmp #'O'
  beq @ui_o
  cmp #'C'
  beq @ui_c
  cmp #'T'
  beq @ui_t
.ifdef DEBUG
  cmp #'M'
  beq @ui_m
.endif
  bne @ui_invalid
@ui_b:
  jsr cmd_boot850
  jmp @ui_done
@ui_o:
  jsr cmd_open
  jmp @ui_done
@ui_c:
  jsr cmd_close
  jmp @ui_done
@ui_t:
  jsr cmd_talk
  jmp @ui_done
.ifdef DEBUG
@ui_m:
  jmp WOZMON
.endif
@ui_invalid:
  ;print_str str_invalid_command
  ;print_str str_supported_commands
  ;print_str str_commands
@ui_done:
  jmp @loop

init:
  ; disable the OS screen editor
  ldx #0
  lda #CLOSE
  sta ICCOM,x
  jsr CIOV

  ; disable cursor
  lda #1
  sta CRSINH

;  lda SAVMSC
;  clc
;  adc #<(CURSOR_MINY*40+CURSOR_MINX)
;  sta INPUT_UPPER_LEFT_PTR
;  lda SAVMSC+1
;  adc #>(CURSOR_MINY*40+CURSOR_MINX)
;  sta INPUT_UPPER_LEFT_PTR+1

;  lda INPUT_UPPER_LEFT_PTR
;  sta ZPB0
;  lda INPUT_UPPER_LEFT_PTR+1
;  sta ZPB1
;
;  ldx #0
;@init_screen_ptrs:
;  lda ZPB0
;  sta screen_rows_lo,x
;  lda ZPB1
;  sta screen_rows_hi,x
;  inx
;  cpx #(CURSOR_MAXY-CURSOR_MINY+1)
;  bcs @init_screen_ptrsd
;  lda ZPB0
;  clc
;  adc #40
;  sta ZPB0
;  lda ZPB1
;  adc #0
;  sta ZPB1
;  bne @init_screen_ptrs
;@init_screen_ptrsd:

  lda SAVMSC
  sta SCR_PTR_LO
  lda SAVMSC+1
  sta SCR_PTR_HI

  ; init and clear the screen
  ldx #6
  lda #0
  sta ICCOM,x
  jsr CIOV

  jsr cls

  jsr mti_init

;  lda #<mti_main_input_struct
;  sta CMDDATA0
;  lda #>mti_main_input_struct
;  sta CMDDATA1
;  lda #0
;  sta CMDDATA2
;  sta CMDDATA3
;  jsr ti_set_cursor

  lda #0
  jsr mti_tmp_dump_data
  
  lda #<mti_main_input_struct
  sta CMDDATA0
  lda #>mti_main_input_struct
  sta CMDDATA1
  lda #CURSOR_FLAG_ENABLE
  sta CMDDATA6
  jsr ti_show_cursor
  ;jsr move_cursor_home
  rts



; TODO: handle the following:
;   See "Mapping the Atari" 702/2BE. Deal with ctrl-lock
;   SHIFT+CLEAR - erase entire area
;   ESC         - same as above
;   CTRL+CURSOR - arrow keys
;   CTRL+INSERT - insert a space
;   DEL BACK S  - backspace without shifting
;   BACK S      - backspace with shifting following to left
;   SHIFT+DELETE BS - delete line
;   CTRL+DELETE BS - delete character, shift following to left


; Keyboard behavior described in the Atari OS User Manual Page 47
inkbd:
  lda CH
  cmp #$ff
  beq @done
  sta user_input_kbdcode_raw  ; with ctrl/shift bits
  lda #$ff
  sta CH
  lda user_input_kbdcode_raw
  and #%00111111
  sta user_input_kbdcode_char ; stripped of ctrl/shift bits

  lda user_input_kbdcode_raw
  ; Bit 7 is 1 if ctrl key pressed
  ; Bit 6 is 1 if shift key pressed
  and #%11000000
  beq @lower_case
  cmp #%11000000
  beq @done ; ignore if ctrl+shift

  and #%10000000
  bne @control_pressed

  ; if here, shift pressed
  ldx user_input_kbdcode_char
  lda kbd_shifted,x
  sta user_input_atascii
  jmp @processed
@control_pressed:
  ldx user_input_kbdcode_char
  lda kbd_ctrld,x
  sta user_input_atascii
  jmp @processed
@lower_case:
  ldx user_input_kbdcode_char
  lda kbd_unmodified,x
  sta user_input_atascii
  jmp @processed
@processed:
  jsr proc_kbd
  ;jsr show_cursor
@done:
  rts

;hide_cursor:
;  pha
;  tya
;  pha
;  ldy #0
;  lda (CURSOR_POS_SCR),y
;  and #%01111111
;  sta (CURSOR_POS_SCR),y
;  pla
;  tay
;  pla
;  rts
;
;; make sure the cursor is visible at its expected location
;show_cursor:
;  pha
;  tya
;  pha
;  ldy #0
;  lda (CURSOR_POS_SCR),y
;  ora #%10000000
;  sta (CURSOR_POS_SCR),y
;  pla
;  tay
;  pla
;  rts
;
;; moves the cursor. assumes that it is correct to do so
;;   e.g. don't call if cursor doesn't actually move
;; inputs:
;;   ZPB2/3 - delta in cursor move (e.g. $00/$00 for none, $01/$00 for right one, $ff/$ff for left one)
;; assumptions:
;;   CURSOR_POSY already reflect the new cursor position
;move_cursor:
;  pha
;  jsr hide_cursor ; uninvert at pre-move position
;
;  ; update ptr to absolute cursor position
;  lda CURSOR_POS_SCR
;  clc
;  adc ZPB2
;  sta CURSOR_POS_SCR
;  lda CURSOR_POS_SCR+1
;  adc ZPB3
;  sta CURSOR_POS_SCR+1
;
;  ; update ptr to start of current row
;  lda CURSOR_POS_SCR
;  sec
;  sbc CURSOR_POSY
;  sta CURSOR_SOL_PTR
;  lda CURSOR_POS_SCR+1
;  sbc #0
;  sta CURSOR_SOL_PTR+1
;
;  pla
;  rts
;
;try_move_cursor_up:
;  lda CURSOR_POSY
;  cmp #CURSOR_MINY
;  beq @wrap
;
;  dec CURSOR_POSY
;
;  lda #0
;  sec
;  sbc #40
;  sta ZPB2
;  lda #$ff
;  sta ZPB3
;  jsr move_cursor
;  jmp @done
;@wrap:
;  lda #<((CURSOR_MAXY-CURSOR_MINY)*40)
;  sta ZPB2
;  lda #>((CURSOR_MAXY-CURSOR_MINY)*40)
;  sta ZPB3
;
;  ldy #CURSOR_MAXY
;  sty CURSOR_POSY
;
;  jsr move_cursor
;  jmp @done
;@done:
;  rts
;
;; inputs
;;   CURSOR_FLAG
;;     - bit 7 - CURSOR_FLAG_WRAP_SAME_LINE if you want cursor to move up a line on wrap
;try_move_cursor_left:
;  lda CURSOR_POSX
;  cmp #CURSOR_MINX
;  beq @wrap
;
;  ; if here, simply move the cursor left
;  dec CURSOR_POSX
;
;  lda #$ff
;  sta ZPB2
;  sta ZPB3
;  jsr move_cursor
;  jmp @done
;@wrap:
;  lda #CURSOR_FLAG_WRAP_SAME_LINE 
;  bit CURSOR_FLAGS
;  bmi @wrap_same_line
;@wrap_next_line:
;  ; wrapped to the left in next line mode, e.g. text
;  ; move up one row and to the end of the row.
;  lda CURSOR_POSY
;  cmp #CURSOR_MINY
;  beq @done ; already at top left
;
;  lda #CURSOR_MAXX
;  sta CURSOR_POSX
;  dec CURSOR_POSY
;
;  lda #0
;  sec
;  sbc #((CURSOR_MINX+1)+(39-CURSOR_MAXX))
;  sta ZPB2
;  lda #$ff
;  sta ZPB3
;  jsr move_cursor
;  jmp @done
;@wrap_same_line:
;  ; wrapped, but same line, e.g. arrow movement
;  ; wrap on the same row
;  lda #CURSOR_MAXX
;  sta CURSOR_POSX
;
;  lda #(CURSOR_MAXX-CURSOR_MINX)
;  sta ZPB2
;  lda #0
;  sta ZPB3
;  jsr move_cursor
;@done:
;  rts
;
;
;try_move_cursor_right:
;  lda CURSOR_POSX
;  cmp #(CURSOR_MAXX)
;  beq @wrap
;
;  inc CURSOR_POSX
;
;  lda #$01
;  sta ZPB2
;  lda #$00
;  sta ZPB3
;  jsr move_cursor
;  jmp @done
;@wrap:
;  lda #CURSOR_FLAG_WRAP_SAME_LINE 
;  bit CURSOR_FLAGS
;  bmi @wrap_same_line
;@wrap_next_line:
;  lda CURSOR_POSY
;  cmp #CURSOR_MAXY
;  beq @done ; at bottom right
;
;  inc CURSOR_POSY
;  lda #CURSOR_MINX
;  sta CURSOR_POSX
;
;  lda #((39-CURSOR_MAXX)+(CURSOR_MINX)+1)
;  sta ZPB2
;  lda #0
;  sta ZPB3
;  jsr move_cursor
;  jmp @done
;@wrap_same_line:
;  lda #CURSOR_MINX
;  sta CURSOR_POSX
;
;  lda #0
;  sec
;  sbc #(CURSOR_MAXX-CURSOR_MINX)
;  sta ZPB2
;  lda #$ff
;  sta ZPB3
;  jsr move_cursor
;@done:
;  rts
;
;try_move_cursor_down:
;  lda CURSOR_POSY
;  cmp #(CURSOR_MAXY)
;  beq @wrap
;
;  inc CURSOR_POSY
;
;  lda #40
;  sta ZPB2
;  lda #0
;  sta ZPB3
;  jsr move_cursor
;  jmp @done
;@wrap:
;  lda #CURSOR_MINY
;  sta CURSOR_POSY
;
;  lda #0
;  sec
;  sbc #<((CURSOR_MAXY-CURSOR_MINY)*40)
;  sta ZPB2
;  lda #$ff
;  sta ZPB3
;  jsr move_cursor
;@done:
;  rts
;
;try_backspace:
;  lda CURSOR_POSY
;  cmp #CURSOR_MINY
;  bne @not_at_beginning ; not on first row
;  lda CURSOR_POSX
;  cmp #CURSOR_MINX
;  bne @not_at_beginning ; not at first char of row
;  jmp @done ; ignore since at beginning
;@not_at_beginning:
;  lda #CURSOR_FLAG_WRAP_DIFF_LINE
;  sta CURSOR_FLAGS
;  jsr try_move_cursor_left
;
;  lda #' '
;  jsr utils_atascii_to_icode
;  sta (CURSOR_POS_SCR),y
;@done:
;  rts
;
;move_cursor_home:
;  lda #CURSOR_MINY
;  sta CURSOR_POSY
;  lda #CURSOR_MINX
;  sta CURSOR_POSX
;
;  jsr hide_cursor
;
;  lda INPUT_UPPER_LEFT_PTR
;  sta CURSOR_POS_SCR
;  sta CURSOR_SOL_PTR
;  lda INPUT_UPPER_LEFT_PTR+1
;  sta CURSOR_POS_SCR+1
;  sta CURSOR_SOL_PTR+1
;
;  jsr show_cursor
;
;  rts
;
;shift_clear:
;  jsr move_cursor_home
;
;  ; blank the input area
;  lda #' '
;  jsr utils_atascii_to_icode
;  ldy #(SCR_INPUT_BUFFER_SIZE-1)
;@loop:
;  sta (CURSOR_POS_SCR),y
;  dey
;  bne @loop
;  sta (CURSOR_POS_SCR),y ; first character
;  rts
;
;; inputs:
;;   - ZPB0/1 ptr to start of row
;clear_row:
;  pha
;  tya
;  pha
;
;  ldy #39
;@loop:
;  lda #' '
;  jsr utils_atascii_to_icode
;  sta (ZPB0),y
;  dey
;  bpl @loop
;
;  pla
;  tay
;  pla
;  rts
;
;
;TODO: clean up all this shit. Too much use of ZPB0/ZPB1 and there
;are issues all over the place.
;
;Switch to the caller needing to worry about things getting corrupted
;so that only the caller will put things on the stack if they care.
;
;TODO ALSO: keep track of relative cursor positions on top of absolutes.
;
;We have 3:
;* Relative to top left of input
;* Relative to top left of screen
;* Absolute position in memory.
;
;Rethink it. What if we just had a function where you could pass
;the desired relative position.
;
;And what if we used the cursor for modifications, too? Do an action,
;move the cursor, do another. Treat it like all edits happen via the cursor
;to simplify.
;
;could add "move to" "delete to" etc.
;
;; inputs
;;   ZPB0/1 - ptr to start of row
;move_cursor_to_start_of_row:
;  pha
;  lda ZPB0
;  pha
;  lda ZPB1
;  pha
;
;  jsr hide_cursor
;
;  lda #CURSOR_MINX
;  sec
;  sbc CURSOR_POSX
;  sta ZPB2
;  lda
;  lda #$ff
;  sta ZPB3
;
;  lda #CURSOR_MINX
;  sta CURSOR_POSX
;
;  jsr move_cursor
;  jsr show_cursor
;
;  pla
;  sta ZPB3
;  pla
;  sta ZPB2
;  pla
;  rts
;
;; moves current line and subsequent ones down one row
;; clears current line
;; moves cursor to start of current line
;line_insert:
;  ;dbg_print_zpb SAVMSC, SAVMSC+1, 40, $0092
;
;  lda CURSOR_POSY
;  cmp #CURSOR_MAXY
;  beq @done
;  sec
;  sbc CURSOR_MINY
;  sta ZPB5  ; we stop when we get here
;
;  jsr hide_cursor
;
;  ldx #(CURSOR_MAXY-CURSOR_MINY)
;@row_loop:
;  ; row to copy to
;  lda screen_rows_lo,x
;  sta ZPB2
;  lda screen_rows_hi,x
;  sta ZPB3
;
;  ; row to copy from
;  dex 
;  lda screen_rows_lo,x
;  sta ZPB0
;  lda screen_rows_hi,x
;  sta ZPB1
;
;  ldy #39
;@col_loop:
;  lda (ZPB0),y
;  sta (ZPB2),y
;  dey
;  bpl @col_loop
;
;  cpx ZPB5
;  beq @copy_done
;  jmp @row_loop
;@copy_done:
;  ; now we'll clear the current row
;  jsr clear_row
;  jsr move_cursor_to_start_of_row
;
;@done:
;  dbg_print_zpb SAVMSC, SAVMSC+1, 40, $0080
;  dbg_print_zpb SAVMSC, SAVMSC+1, 80, $0092
;  rts
;
cmd_move_cursor_up:
  rts
cmd_move_cursor_down:
  rts
cmd_move_cursor_left:
  rts
cmd_move_cursor_right:
  rts



proc_kbd:
  ; TODO remove when no longer debugging
  lda SAVMSC
  sta CMDDATA0
  lda SAVMSC+1
  sta CMDDATA1
  ldy #0
  lda user_input_kbdcode_raw 
  jsr utils_byte_to_scr_hex

  lda user_input_kbdcode_raw 
  cmp #$8e
  beq @up_arrow
  cmp #$8f
  beq @down_arrow
  cmp #$86
  beq @left_arrow
  cmp #$87
  beq @right_arrow
  cmp #$0c
  beq @return
  cmp #$34
  beq @backspace
  cmp #$76 ; shift+clear
  beq @shift_clear
  cmp #$b7 ; ctrl+clear
  beq @shift_clear
  cmp #$77 ; shift+insert on atari
  ; TODO: figure out how to do this on emulator
  ; $77 is correct on atari, $7c for shift+insert on emulator
  cmp #$7c ; shift+insert on emulator
  beq @line_insert
@output:
;  lda user_input_atascii
;  beq @done
;  ; output their keypress
;  jsr utils_atascii_to_icode
;  ldy #0
;  sta (CURSOR_POS_SCR),y
;  lda #CURSOR_FLAG_WRAP_DIFF_LINE
;  sta CURSOR_FLAGS
;  jsr try_move_cursor_right
  jmp @done
@up_arrow:
  jmp cmd_move_cursor_up
  jmp @done
@down_arrow:
  jmp cmd_move_cursor_down
  jmp @done
@left_arrow:
  jmp cmd_move_cursor_left
;  lda #CURSOR_FLAG_WRAP_SAME_LINE
;  sta CURSOR_FLAGS
;  jsr try_move_cursor_left
  jmp @done
@right_arrow:
  jmp cmd_move_cursor_right
;  lda #CURSOR_FLAG_WRAP_SAME_LINE
;  jsr try_move_cursor_right
  jmp @done
@backspace:
;  jsr try_backspace
  jmp @done
@shift_clear:
;  jsr shift_clear
  jmp @done
@line_insert:
;  jsr line_insert
  jmp @done
@return:
@done:
;  jsr show_cursor ; make sure cursor shown
  rts

cls:
  lda SAVMSC
  sta ZPB0
  lda SAVMSC+1
  sta ZPB1

  ldx #23
@row_loop:
  ldy #39
  lda #' '
  jsr utils_atascii_to_icode
@col_loop:
  sta (ZPB0),y
  dey
  bpl @col_loop
  dex
  bmi @done
  lda ZPB0
  clc
  adc #40
  sta ZPB0
  bcc @nowrap
  inc ZPB1
@nowrap:
  jmp @row_loop
@done:
  rts

cmd_boot850:
  jsr boot850_bootstrap
  bcs @error
  jsr boot850_check
  bcs @error
  ;print_str str_850loaded
  jmp @done
@error:
  ;print_str str_850error
@done:
  rts

cmd_open:
  ldx #RS232_CHANNEL
  jsr rs232_open
  bcs @error
  ;print_str str_success
  jmp @done
@error:
  sty command_error
  ;print_bytes str_error, str_error_end
  ldy #0
  lda command_error
  ;jsr utils_hex_to_str
  ;;print_str utils_hex_str
@done:
  rts

cmd_close:
  jsr rs232_close
  bcs @error
  ;print_str str_success
  jmp @done
@error:
  sty command_error
  ;print_bytes str_error, str_error_end
  ldy #0
  lda command_error
  ;jsr utils_hex_to_str
  ;print_str utils_hex_str
@done:
  rts

; TODO: move some macros to jsr to save bytes
cmd_talk:
  jsr rs232_status
  bcs @error_status
  lda rs232_input_buffer_size+1
  bne @read
  lda rs232_input_buffer_size
  bne @read
  jmp @done
@read:
  jsr rs232_getchr
  bcc @read_success
  jmp @error_getchr
@read_success:
  sta output_buf
  ldy #0
  ;print_str output_buf
@echo:
  lda output_buf
  jsr rs232_putchr
  bcs @error_putchr
  jmp @done
@error_status:
  sty command_error
  ;print_bytes str_error_status, str_error_status_end
  jmp @error
@error_getchr:
  sty command_error
  ;print_bytes str_error_getchr, str_error_getchr_end
  jmp @error
@error_putchr:
  sty command_error
  ;print_bytes str_error_putchr, str_error_putchr_end
@error:
  ldy #0
  lda command_error
  ;jsr utils_hex_to_str
  ;print_str utils_hex_str
  rts
@done:
  jmp cmd_talk




str_850error: .byte "850 not found", $9b
str_850loaded: .byte "850 handler loaded", $9b
str_supported_commands: .byte "Supported Commands:", $9b
.ifdef DEBUG
str_commands: .byte "[B] boot [O] open [C] close [T] talk [M] mon", $9b
.else
str_commands: .byte "[B] boot [O] open [C] close [T] talk", $9b
.endif
str_invalid_command: .byte "Invalid input", $9b
str_get_command:
  .byte "cmd: "
str_get_command_end:
str_success: .byte "Success", $9b
str_error:
  .byte "Error: "
str_error_end:
str_error_status:
  .byte "Error on status: "
str_error_status_end:
str_error_getchr:
  .byte "Error on getchr: "
str_error_getchr_end:
str_error_putchr:
  .byte "Error on putchr: "
str_error_putchr_end:

user_input_kbdcode_raw: .byte 0
user_input_kbdcode_char: .byte 0
user_input_atascii: .byte 0
user_input_buf: .res 256
output_buf: .byte $9b,$9b
command_error: .byte 0

loop_count: .byte 0
screen_rows_lo:
  .res (CURSOR_MAXY-CURSOR_MINY)+1

screen_rows_hi:
  .res (CURSOR_MAXY-CURSOR_MINY)+1
