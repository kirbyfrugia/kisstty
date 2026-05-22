.SETCPU "6502"
.INCLUDE "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.INCLUDE "macros.inc"

MAX_INPUT_LEN = 114
WOZMON        = $9800
RS232_CHANNEL = 32    ; channel 2 (2 * 16)

.IMPORT boot850_check 
.IMPORT boot850_bootstrap 
.IMPORT utils_hex_str
.IMPORT utils_hex_to_str
.IMPORT utils_print_dcb
.IMPORT utils_print_hatabs
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
  ;jsr init
  jsr boot850_check
  bcc @rhandler_loaded
@bootstrap850:
  jsr boot850_bootstrap
  bcc @rhandler_loaded
  print_str str_850error
  jmp @main
@rhandler_loaded:
  print_str str_850loaded
@main:
  print_str str_supported_commands
  print_str str_commands
@loop:
  ;jsr proc_kbd
  ; ask for input
  print_bytes str_get_command, str_get_command_end

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
  print_str str_invalid_command
  print_str str_supported_commands
  print_str str_commands
@ui_done:
  jmp @loop

; TODO: handle the following:
;   SHIFT+CLEAR - erase entire area
;   ESC         - same as above
;   CTRL+CURSOR - arrow keys
;   CTRL+INSERT - insert a space
;   DEL BACK S  - backspace without shifting
;   BACK S      - backspace with shifting following to left
;   SHIFT+DELETE BS - delete line
;   CTRL+DELETE BS - delete character, shift following to left

char_to_scr:
  ldy #0
  lda user_input_char
  print_str output_buf
  rts

proc_kbd:
  lda CH
  cmp #$ff
  beq @nokey

  sta user_input_char

  lda SHFLOK
  and #%00001000
  beq @no_shift

  ldx user_input_char
  lda kbd_shifted,x
  sta user_input_char
  jsr char_to_scr
  jmp @processed

@no_shift:
  lda SHFLOK
  and #%00000100
  beq @no_ctrl

  ldx user_input_char
  lda kbd_ctrld,x
  sta user_input_char
  jsr char_to_scr
  jmp @processed

@no_ctrl:
  ldx user_input_char
  lda kbd_unmodified,x
  sta user_input_char
  jsr char_to_scr
@processed:
  lda #$ff
  sta CH
@nokey:
  rts

init:
  ldx #0
  lda #CLOSE
  sta ICCOM,x
  jsr CIOV

  ; disable cursor
  lda #1
  sta CRSINH


;  lda #0
;  sta ATRACT ; disable ATRACT (screen dimmer)
;  lda #10
;  sta ROWCRS
;  lda #20
;  sta COLCRS
  rts

cmd_boot850:
  jsr boot850_bootstrap
  bcs @error
  jsr boot850_check
  bcs @error
  print_str str_850loaded
  jmp @done
@error:
  print_str str_850error
@done:
  rts

cmd_open:
  ldx #RS232_CHANNEL
  jsr rs232_open
  bcs @error
  print_str str_success
  jmp @done
@error:
  sty command_error
  print_bytes str_error, str_error_end
  ldy #0
  lda command_error
  jsr utils_hex_to_str
  print_str utils_hex_str
@done:
  rts

cmd_close:
  jsr rs232_close
  bcs @error
  print_str str_success
  jmp @done
@error:
  sty command_error
  print_bytes str_error, str_error_end
  ldy #0
  lda command_error
  jsr utils_hex_to_str
  print_str utils_hex_str
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
  print_str output_buf
@echo:
  lda output_buf
  jsr rs232_putchr
  bcs @error_putchr
  jmp @done
@error_status:
  sty command_error
  print_bytes str_error_status, str_error_status_end
  jmp @error
@error_getchr:
  sty command_error
  print_bytes str_error_getchr, str_error_getchr_end
  jmp @error
@error_putchr:
  sty command_error
  print_bytes str_error_putchr, str_error_putchr_end
@error:
  ldy #0
  lda command_error
  jsr utils_hex_to_str
  print_str utils_hex_str
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

user_input_char: .byte 0
user_input_buf: .res 256
output_buf: .byte $9b,$9b
command_error: .byte 0
;display_list: .byte 
