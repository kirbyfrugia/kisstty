; Resources
;   Best: [Altirra Hardware Reference Manual](https://www.virtualdub.org/downloads/Altirra%20Hardware%20Reference%20Manual.pdf)
;   [Assembly Language Programming for the Atari Computers](https://www.atariarchives.org/alp/index.php)
;   [De Re Atari](https://www.atariarchives.org/dere/)
;   [ChibiAkumas Tutorials](https://www.chibiakumas.com/6502/Atari800Atari5200.php)

.SETCPU "6502"
.INCLUDE "atari.inc"

MAX_INPUT_LEN = 114


.IMPORT wakeup850
.IMPORT check850
.IMPORT boot850_poll
.IMPORT boot850_direct
.IMPORT boot850_poll_device

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
  lda #$50
  sta boot850_poll_device
  print_str str_supported_commands
  print_str str_commands
  print_str str_poll_dev
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
  cmp #'D'
  beq @ui_d
  cmp #'C'
  beq @ui_c
  cmp #'W'
  beq @ui_w
  cmp #'1'
  beq @ui_1
  cmp #'2'
  beq @ui_2
  cmp #'3'
  beq @ui_3
  bne @ui_invalid
@ui_p:
  jsr cmd_load850_poll
  jmp @ui_done
@ui_d:
  jsr cmd_load850_direct
  jmp @ui_done
@ui_c:
  jsr cmd_check850
  jmp @ui_done
@ui_w:
  jsr wakeup850
  jmp @ui_done
@ui_1:
  lda #$00
  sta boot850_poll_device
  ldy #0
  jsr hex_to_str
  jmp @print_hex_str
@ui_2:
  lda #$4f
  sta boot850_poll_device
  ldy #0
  jsr hex_to_str
  jmp @print_hex_str
@ui_3:
  lda #$50
  sta boot850_poll_device
  ldy #0
  jsr hex_to_str
  jmp @print_hex_str
@print_hex_str:
  print_str hex_str
  jmp @ui_done
@ui_invalid:
  print_str str_invalid_command
  print_str str_supported_commands
  print_str str_commands
  print_str str_poll_dev
@ui_done:
  jmp @loop

print_commands:
  print_str str_commands
  rts

cmd_check850:
  jsr check850
  bcs @error
  print_str str_850loaded
  jmp @done
@error:
  print_str str_850error
@done:
  jsr print_dcb
  jsr print_hatabs
  rts


cmd_load850_poll:
  jsr boot850_poll
  bcs @error
  print_str str_850loaded
  jmp @done
@error:
  print_str str_850error
@done:
  jsr print_dcb
  jsr print_hatabs
  rts

cmd_load850_direct:
  jsr boot850_direct
  bcs @error
  print_str str_850loaded
  jmp @done
@error:
  print_str str_850error
@done:
  jsr print_dcb
  jsr print_hatabs
  rts

; writes the hex value in A to hex_str offset by y
; adds a $9b at the end
; Note: Y will be incremented by 2.
hex_to_str:
  sta tmp0
  stx tmp1
  pha
  lsr
  lsr
  lsr
  lsr
  tax
  lda HEX_TABLE,x
  sta hex_str,y
  pla
  and #%00001111
  tax
  iny
  lda HEX_TABLE,x
  sta hex_str,y 
  iny
  lda #$9b
  sta hex_str,y
  ldx tmp1
  lda tmp0
  rts

print_dcb:
  print_str str_dcb
  ldy #0
  ldx #0
@loop:
  lda DDEVIC,x
  jsr hex_to_str
  lda #','
  sta hex_str,y
  iny
  inx
  cpx #12
  bne @loop
  dey
  lda #$9b
  sta hex_str,y
  print_str hex_str
  rts

print_hatabs:
  print_str str_hatabs

  ldy #0
  ldx #0
@loop:
  lda HATABS,x
  sta hatabs_str, y
  inx
  inx
  inx
  iny
  lda #','
  sta hatabs_str, y
  iny
  cpx #24
  bcc @loop

  lda #$9b
  sta hatabs_str, y

  print_str hatabs_str

  rts



str_850error: .byte "850 not found", $9b
str_850loaded: .byte "850 handler loaded", $9b
str_supported_commands: .byte "Supported Commands:", $9b
.ifdef DEBUG
str_commands: .byte "[P] poll [D] direct [W] wake [C] chk [M] mon", $9b
.else
str_commands: .byte "[P] poll [D] direct [W] wake [C] chk", $9b
.endif
str_poll_dev: .byte "Poll device: [1] $00 [2] $4f [3] $50", $9b
str_invalid_command: .byte "Invalid input", $9b
str_get_command:
  .byte "cmd: "
str_get_command_end:

str_dcb: .byte "dcb: ", $9b
str_hatabs: .byte "HATABS: ", $9b

user_input_buf: .res 256
hex_str: .res 80
hatabs_str: .res 80
tmp0: .byte 0
tmp1: .byte 0
tmp2: .byte 0

HEX_TABLE: .byte "0123456789ABCDEF"

.ifdef DEBUG
.SEGMENT "BUG65_CODE"
.incbin "3rdparty/atari/bug65.com", 6
.endif
