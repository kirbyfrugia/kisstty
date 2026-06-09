.SETCPU "6502"

.EXPORT copy_buffer40 
.EXPORT copy_buffer40_size
.EXPORT str_to_copy_buffer40_with_fill

.EXPORT g_rx_buf, g_disp_buf
.EXPORT g_kbd_key_pressed
.EXPORT g_kbdcode_raw
.EXPORT g_kbdcode_raw_stripped
.EXPORT g_kbdcode_atascii

.EXPORTZP ZPB0, ZPB1, ZPB2, ZPB3, ZPB4, ZPB5
.EXPORTZP CMDDATA0, CMDDATA1, CMDDATA2, CMDDATA3, CMDDATA4, CMDDATA5, CMDDATA6, CMDDATA7
.EXPORTZP SCR_PTR_LO, SCR_PTR_HI
.EXPORTZP g_rx_buf_num_chars, g_disp_buf_num_chars

.SEGMENT "ZEROPAGE"
ZPB0:                        .res 1
ZPB1:                        .res 1
ZPB2:                        .res 1
ZPB3:                        .res 1
ZPB4:                        .res 1
ZPB5:                        .res 1
CMDDATA0:                    .res 1
CMDDATA1:                    .res 1
CMDDATA2:                    .res 1
CMDDATA3:                    .res 1
CMDDATA4:                    .res 1
CMDDATA5:                    .res 1
CMDDATA6:                    .res 1
CMDDATA7:                    .res 1
SCR_PTR_LO:                  .res 1
SCR_PTR_HI:                  .res 1
g_rx_buf_num_chars:          .res 1
g_disp_buf_num_chars:        .res 1

.SEGMENT "CODE"

; copies the null terminated string to the copy buffer
; and fills the rest with a space
; inputs:
;   CMDDATA0/1 - ptr to string
;   CMDDATA2   - max width to copy
;   CMDDATA3   - the char to fill
str_to_copy_buffer40_with_fill:
  ldy #0
@str_loop:
  lda (CMDDATA0),y
  beq @fill
  sta copy_buffer40,y
  iny
  cpy CMDDATA2
  bne @str_loop
  beq @done
@fill:
  lda CMDDATA3
@fill_loop:
  sta copy_buffer40,y
  iny 
  cpy CMDDATA2
  bne @fill_loop
@done:
  sty copy_buffer40_size
  rts

copy_buffer40:          .res 40
copy_buffer40_size:     .res 1
g_rx_buf:               .res 256
g_disp_buf:             .res 256
g_kbd_key_pressed:      .res 1 ; nonzero if pressed
g_kbdcode_raw:          .res 1 ; raw keyboard code currently pressed
g_kbdcode_raw_stripped: .res 1 ; raw minus ctrl bits
g_kbdcode_atascii:      .res 1 ; keyboard code in atascii
