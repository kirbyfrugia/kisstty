.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "textarea.inc"
.SEGMENT "CODE"

.IMPORT utils_dump_mem_row
.IMPORT ta_init_textarea
.IMPORT ta_set_metadata_ptr
.EXPORT mti_init
.EXPORT mti_tmp_dump_data

MARGIN_LEFT   = 1
MARGIN_TOP    = 20
WIDTH         = 38
HEIGHT        = 4
SIZE          = WIDTH * HEIGHT

; initializes the text input area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mti_init:
  ta_init metadata, MARGIN_TOP, MARGIN_LEFT, WIDTH, HEIGHT, #CURSOR_FLAG_ENABLED

  ; fill the data
  lda #' '
  ldy #0
@loop:
  sta input_data,y
  iny
  cpy #SIZE
  bne @loop

  lda #<metadata
  sta CMDDATA0
  lda #>metadata
  sta CMDDATA1
  jsr ta_set_metadata_ptr

  rts

input_metadata: .tag TextArea
input_data:     .res SIZE
