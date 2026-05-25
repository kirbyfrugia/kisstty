.SETCPU "6502"
.INCLUDE "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.INCLUDE "macros.inc"
.INCLUDE "common.inc"

MAX_INPUT_LEN = 114
WOZMON        = $9800
RS232_CHANNEL = 32    ; channel 2 (2 * 16)

CTRL_SHIFT_FLAG_CTRL  = %10000000
CTRL_SHIFT_FLAG_SHIFT = %01000000
CTRL_SHIFT_FLAG_LOWER = %00000000

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
.IMPORT mti_main_input_metadata
.IMPORT mti_tmp_dump_data
.IMPORT ta_initsys
.IMPORT ta_scr_ptr
.IMPORT ta_show_cursor
.IMPORT ta_move_cursor_up
.IMPORT ta_move_cursor_down
.IMPORT ta_move_cursor_left
.IMPORT ta_move_cursor_right
.IMPORT ta_typechar
.IMPORT ta_backspace
.IMPORT ta_shift_clear
.IMPORT ta_line_insert
.IMPORT ta_char_insert
.IMPORT ta_line_delete
.IMPORT ta_char_delete

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
  lda #CTRL_SHIFT_FLAG_LOWER 
  sta ctrl_shift_lock_flag

  ; disable the OS screen editor
  ldx #0
  lda #CLOSE
  sta ICCOM,x
  jsr CIOV

  ; disable cursor
  lda #1
  sta CRSINH

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

  jsr ta_initsys
  jsr mti_init
  jsr ta_show_cursor
  rts

; Keyboard behavior described in the Atari OS User Manual Page 47
inkbd:
  lda CH
  cmp #$ff
  beq @no_key_pressed
  sta user_input_kbdcode_raw  ; with ctrl/shift bits
  lda #$ff
  sta CH
  jmp @key_pressed

@no_key_pressed:
  jmp @done

@key_pressed:
  ; first let's handle ctrl-lock and shift-lock
  ; presses
  lda user_input_kbdcode_raw
  cmp #$3c
  beq @lock_lower
  cmp #$bc
  beq @lock_ctrl
  cmp #$7c
  beq @lock_shift
  bne @not_a_lock_key
@lock_lower:
  lda #CTRL_SHIFT_FLAG_LOWER 
  sta ctrl_shift_lock_flag
  jmp @done
@lock_ctrl:
  lda #CTRL_SHIFT_FLAG_CTRL  
  sta ctrl_shift_lock_flag
  jmp @done
@lock_shift:
  lda #CTRL_SHIFT_FLAG_SHIFT 
  sta ctrl_shift_lock_flag
  jmp @done

@not_a_lock_key:
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

  lda user_input_kbdcode_raw
  and #%01000000
  bne @shift_pressed

@lower_case:
  ; if here, lower case, but we need to check
  ; ctrl lock or shift lock are on
  ldx user_input_kbdcode_char
  lda kbd_unmodified,x
  sta user_input_atascii

  ; ignore for non-alphas according to spec (OS User's manual)
  cmp #$61 ;#'A'
  bcc @processed

  cmp #$7b ;#'['
  bcs @processed

  ; now check to see if CTRL lock
  lda ctrl_shift_lock_flag
  and #CTRL_SHIFT_FLAG_CTRL
  bne @control_locked

  lda ctrl_shift_lock_flag
  and #CTRL_SHIFT_FLAG_SHIFT
  bne @shift_locked
  jmp @processed

@shift_locked:
  ldx user_input_kbdcode_char
  ;lda user_input_kbdcode_char
  ;ora #CTRL_SHIFT_FLAG_SHIFT ; add the shift bit
  ;sta user_input_kbdcode_char
  ;tax
  lda kbd_shifted,x
  sta user_input_atascii
  jmp @processed
@control_locked:
  ldx user_input_kbdcode_char
  ;lda user_input_kbdcode_char
  ;ora #CTRL_SHIFT_FLAG_CTRL; add the ctrl bit
  ;sta user_input_kbdcode_char
  ;tax
  lda kbd_ctrld,x
  sta user_input_atascii
  jmp @processed
@shift_pressed:
  ; if here, shift pressed
  ldx user_input_kbdcode_char
  lda kbd_shifted,x
  sta user_input_atascii
  jmp @processed
@control_pressed:
  ldx user_input_kbdcode_char
  lda kbd_ctrld,x
  sta user_input_atascii
@processed:
  jsr proc_kbd
@done:
  rts

cmd_move_cursor_up:
  jsr ta_move_cursor_up
  rts

cmd_move_cursor_down:
  jsr ta_move_cursor_down
  rts

cmd_move_cursor_left:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr ta_move_cursor_left
  rts

cmd_move_cursor_right:
  lda #CURSOR_BEHAVIOR_WRAP_SAME_LINE
  sta CMDDATA0
  jsr ta_move_cursor_right
  rts

cmd_typechar:
  lda user_input_atascii
  beq @done
  jsr ta_typechar
@done:
  rts

cmd_backspace:
  jsr ta_backspace
  rts

cmd_shift_clear:
  jsr ta_shift_clear
  rts

cmd_line_insert:
  jsr ta_line_insert
  rts

cmd_char_insert:
  jsr ta_char_insert
  rts

cmd_line_delete:
  jsr ta_line_delete
  rts

cmd_char_delete:
  jsr ta_char_delete
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
  ldy #3
  lda ctrl_shift_lock_flag
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
  cmp #$76 ; shift+clear ($b4 on atari 800 emulator)
  beq @shift_clear
  cmp #$b6 ; ctrl+clear
  beq @shift_clear
  cmp #$77 ; shift+insert on atari ($7c on atari800 emulator)
  beq @line_insert
  cmp #$b7 ; ctrl+insert
  beq @char_insert
  cmp #$74 ; shift+delete bs
  beq @line_delete
  cmp #$b4 ; ctrl+delete bs
  beq @char_delete
@output:
  jsr cmd_typechar
  jmp @done
@up_arrow:
  jmp cmd_move_cursor_up
  jmp @done
@down_arrow:
  jmp cmd_move_cursor_down
  jmp @done
@left_arrow:
  jmp cmd_move_cursor_left
  jmp @done
@right_arrow:
  jmp cmd_move_cursor_right
  jmp @done
@backspace:
  jsr cmd_backspace
  jmp @done
@shift_clear:
  jsr cmd_shift_clear
  jmp @done
@line_insert:
  jsr cmd_line_insert
  jmp @done
@char_insert:
  jsr cmd_char_insert
  jmp @done
@line_delete:
  jsr cmd_line_delete
  jmp @done
@char_delete:
  jsr cmd_char_delete
  jmp @done
@return:
@done:
  rts

cls:
  lda SCR_PTR_LO
  sta ZPB0
  lda SCR_PTR_LO+1
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

ctrl_shift_lock_flag: .byte 0

loop_count: .byte 0
