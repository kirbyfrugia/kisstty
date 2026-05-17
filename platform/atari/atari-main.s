; Resources
;   Best: [Altirra Hardware Reference Manual](https://www.virtualdub.org/downloads/Altirra%20Hardware%20Reference%20Manual.pdf)
;   [Assembly Language Programming for the Atari Computers](https://www.atariarchives.org/alp/index.php)
;   [De Re Atari](https://www.atariarchives.org/dere/)
;   [ChibiAkumas Tutorials](https://www.chibiakumas.com/6502/Atari800Atari5200.php)

.SETCPU "6502"
.INCLUDE "atari.inc"

MAX_INPUT_LEN = 114


.IMPORT wakeup850
.IMPORT boot850

.SEGMENT "CODE"

.macro print_str str_data
  ldx #0
  lda #<str_data
  sta ICBAL,x
  lda #>str_data
  sta ICBAH,x

  lda #$ff
  sta ICBLL,x
  lda #0
  sta ICBLH,x

  lda #PUTREC
  sta ICCOM,x
  jsr CIOV
.endmacro

.macro print_bytes str_data, str_data_end
  ldx #0
  lda #<str_data
  sta ICBAL,x
  lda #>str_data
  sta ICBAH,x

  lda #<(str_data_end-str_data)
  sta ICBLL,x
  lda #>(str_data_end-str_data)
  sta ICBLH,x

  lda #11
  sta ICCOM,x
  jsr CIOV
.endmacro

.EXPORT start
start:
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
  cmp #'W'
  beq @ui_w
  bne @ui_invalid
@ui_b:
  jsr cmd_load850
  jmp @ui_done
@ui_w:
  jsr wakeup850
  jmp @ui_done
@ui_invalid:
  print_str str_invalid_command
  print_str str_supported_commands
  print_str str_commands
@ui_done:
  jmp @loop

print_commands:
  print_str str_commands
  rts

cmd_load850:
  jsr boot850
  bcs @no850

  print_str str_850loaded
  jmp @cmd_load850d
@no850:
  print_str str_850error
@cmd_load850d:
  rts

str_850error: .byte "850 not found", $9b
str_850loaded: .byte "850 handler loaded", $9b
str_supported_commands: .byte "Supported Commands:", $9b
str_commands: .byte " [B] Load 850 [W] Wakeup 850", $9b
str_invalid_command: .byte "Invalid input", $9b
str_get_command:
  .byte "cmd: "
str_get_command_end:

user_input_buf: .res 256

.ifdef DEBUG
.SEGMENT "BUG65_CODE"
.incbin "3rdparty/atari/bug65.com", 6
.endif
