.SETCPU "6502"
.INCLUDE "atari.inc"
.INCLUDE "macros.inc"

MAX_INPUT_LEN = 114
WOZMON        = $9800
RS232_CHANNEL = 32 ; channel 2 (2 * 16)

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
  ldx #RS232_CHANNEL
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

;cmd_write:
;  ldx #RS232_CHANNEL
;  jsr rs232_write
;  bcs @error
;  print_str str_success
;  jmp @done
;@error:
;  sty command_error
;  print_bytes str_error, str_error_end
;  ldy #0
;  lda command_error
;  jsr utils_hex_to_str
;  print_str utils_hex_str
;@done:
;  rts

cmd_talk:
  ldx #RS232_CHANNEL
  jsr rs232_status
  lda rs232_input_buffer_size+1
  bne @read
  lda rs232_input_buffer_size
  beq @write
@read:
  jsr rs232_getchr
  bcs @error
  sta output_buf
  print_str output_buf
@write:
  lda output_buf
  jsr rs232_putchr
  bcs @error
  jmp @done
@error:
  sty command_error
  print_bytes str_error, str_error_end
  ldy #0
  lda command_error
  jsr utils_hex_to_str
  print_str utils_hex_str
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

user_input_buf: .res 256
output_buf: .byte $9b,$9b
command_error: .byte 0
