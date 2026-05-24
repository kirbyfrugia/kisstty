.SETCPU "6502"
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.SEGMENT "CODE"

.IMPORT utils_dump_mem_row
.IMPORT ti_init
.IMPORT ti_set_metadata
.EXPORT mti_init
.EXPORT mti_main_input_metadata
.EXPORT mti_tmp_dump_data

MARGIN_LEFT   = 2
MARGIN_TOP    = 21
WIDTH         = 38
HEIGHT        = 3
SIZE          = WIDTH * HEIGHT
;SIZE          = NUM_ROWS * SCREEN_WIDTH

; get rid of this, only here for debug
; inputs: a -
mti_tmp_dump_data:
  sta tmp_dump
  lda SCR_PTR_LO
  sta CMDDATA0
  lda SCR_PTR_HI
  sta CMDDATA1

  lda CMDDATA0
  clc
  adc tmp_dump
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  lda #<mti_main_input_metadata
  sta CMDDATA2
  lda #>mti_main_input_metadata
  sta CMDDATA3
  ldy #0
  jsr utils_dump_mem_row

  lda CMDDATA0
  clc
  adc #40
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  lda #<(mti_main_input_metadata+8)
  sta CMDDATA2
  lda #>(mti_main_input_metadata+8)
  sta CMDDATA3
  ldy #0
  jsr utils_dump_mem_row

  lda CMDDATA0
  clc
  adc #40
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  lda #<input_scr_rows_lo
  sta CMDDATA2
  lda #>input_scr_rows_lo
  sta CMDDATA3
  ldy #0
  jsr utils_dump_mem_row

  lda CMDDATA0
  clc
  adc #40
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  lda #<input_scr_rows_hi
  sta CMDDATA2
  lda #>input_scr_rows_hi
  sta CMDDATA3
  ldy #0
  jsr utils_dump_mem_row

  lda tmp_dump
  rts

; initializes the text input area
;
; inputs:
;   CMDDATA0/1 - pointer to the upper left of the real screen
mti_init:
  lda #0
  sta cursorx
  sta cursory
  sta cursorpos

  lda #<mti_main_input_data
  sta data_ptr
  lda #>mti_main_input_data
  sta data_ptr+1
  lda #MARGIN_LEFT
  sta margin_left
  lda #MARGIN_TOP
  sta margin_top
  lda #WIDTH
  sta width
  lda #HEIGHT
  sta height
  lda #SIZE
  sta size
  lda #(WIDTH-1)
  sta cursor_maxx
  lda #(HEIGHT-1)
  sta cursor_maxy

  ; set pointers to table where screen row data is stored
  lda #<input_scr_rows_lo
  sta scr_rows_ptr_loc_lo
  lda #>input_scr_rows_lo
  sta scr_rows_ptr_loc_lo+1

  lda #<input_scr_rows_hi
  sta scr_rows_ptr_loc_hi
  lda #>input_scr_rows_hi
  sta scr_rows_ptr_loc_hi+1

  lda #<mti_main_input_metadata
  sta CMDDATA0
  lda #>mti_main_input_metadata
  sta CMDDATA1
  jsr ti_set_metadata
  jsr ti_init
  ;lda #0
  ;sta CMDDATA2
  ;sta CMDDATA3
  ;jsr ti_scr_ptr
  ;lda CMDDATA4
  ;sta scr_ptr
  ;lda CMDDATA5
  ;sta scr_ptr+1

  rts


; see textinput.s for documentation
; WARN: be very careful if you modify any of this.
;       it needs to match the struct in textinput.s exactly.
mti_main_input_metadata:
data_ptr:            .byte 0,0
scr_rows_ptr_loc_lo: .byte 0,0
scr_rows_ptr_loc_hi: .byte 0,0
margin_left:         .byte 0
margin_top:          .byte 0
width:               .byte 0
height:              .byte 0
size:                .byte 0
cursorx:             .byte 0
cursory:             .byte 0
cursor_maxx:         .byte 0
cursor_maxy:         .byte 0
cursorpos:           .byte 0
cursor_scr_row_ptr:  .byte 0,0

input_scr_rows_lo:  .res HEIGHT
input_scr_rows_hi:  .res HEIGHT

mti_main_input_data: .res SIZE

tmp_dump: .byte 0
