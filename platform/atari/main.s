.SETCPU "6502"
.INCLUDE "atari.inc"
.INCLUDE "macros.inc"

MAX_INPUT_LEN = 114
WOZMON = $9800

.IMPORT boot850_check 
.IMPORT boot850_bootstrap 
.IMPORT utils_hex_str
.IMPORT utils_hex_to_str
.IMPORT utils_print_dcb
.IMPORT utils_print_hatabs

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
  cmp #'P'
  beq @ui_p
  cmp #'C'
  beq @ui_c
  cmp #'M'
  beq @ui_m
  bne @ui_invalid
@ui_p:
  jsr cmd_boot850
  jmp @ui_done
@ui_c:
  jsr cmd_check850
  jmp @ui_done
@ui_m:
  jmp WOZMON
@ui_invalid:
  print_str str_invalid_command
  print_str str_supported_commands
  print_str str_commands
@ui_done:
  jmp @loop

cmd_check850:
  jsr boot850_check 
  bcs @error
  print_str str_850loaded
  jmp @done
@error:
  print_str str_850error
@done:
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

str_850error: .byte "850 not found", $9b
str_850loaded: .byte "850 handler loaded", $9b
str_supported_commands: .byte "Supported Commands:", $9b
.ifdef DEBUG
str_commands: .byte "[P] poll [C] chk [M] mon", $9b
.else
str_commands: .byte "[P] poll [C] chk", $9b
.endif
str_invalid_command: .byte "Invalid input", $9b
str_get_command:
  .byte "cmd: "
str_get_command_end:

user_input_buf: .res 256

