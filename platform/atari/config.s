.SETCPU "6502"

.INCLUDE "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"

.IMPORT utils_atascii_to_icode
.EXPORT mu_init
.EXPORT mu_draw_menu

.SEGMENT "CODE"

TOP_MENU_MARGIN_TOP  = 2

mu_init:
  MENU_BAUD_OFFSET = TOP_MENU_MARGIN_TOP * SCREEN_WIDTH + 2
  lda #<MENU_BAUD_OFFSET
  clc
  adc SCR_PTR_LO
  sta baud_menu+Menu::heading_row_ptr
  lda #>MENU_BAUD_OFFSET
  adc SCR_PTR_HI
  sta baud_menu+Menu::heading_row_ptr+1

  lda #<baud_menu_and_items
  sta baud_menu+Menu::menu_and_items_ptr
  lda #>baud_menu_and_items
  sta baud_menu+Menu::menu_and_items_ptr+1

  lda #8
  sta baud_menu+Menu::num_items
  lda #6
  sta baud_menu+Menu::width
  rts

; inputs:
;   CMDDATA0/1 - pointer to screen location
;   CMDDATA2/3 - pointer to menu heading and item strings
;   CMDDATA4   - num menu items
;   CMDDATA5   - width of each item
int_draw_single_menu:
  ; TODO: add a border
  ldx #0
  ; hack, but this is just a row counter and we need 
  ; to account for the heading, too
  dex
@row_loop:
  ldy #0
@col_loop:
  lda (CMDDATA2),y
  beq @col_done ; null character
  jsr utils_atascii_to_icode
  sta (CMDDATA0),y
  iny
  cpy CMDDATA5
  bne @col_loop
@col_done:
  inx
  cpx CMDDATA4
  beq @row_done
  lda CMDDATA0
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1
  lda CMDDATA2
  clc
  adc CMDDATA5
  sta CMDDATA2
  lda CMDDATA3
  adc #0
  sta CMDDATA3
  ldy #0
  beq @row_loop
@row_done:
  rts

mu_draw_menu:
  draw_menu baud_menu
  rts

baud_menu:            .tag Menu
baud_menu_and_items:  .byte "[B]aud"
baud_menu_item_baud0: .byte "   300"
baud_menu_item_baud1: .byte "   600"
baud_menu_item_baud2: .byte "  1200"
baud_menu_item_baud3: .byte "  1800"
baud_menu_item_baud4: .byte "  2400"
baud_menu_item_baud5: .byte "  4800"
baud_menu_item_baud6: .byte "  9600"
baud_menu_item_baud7: .byte " 19200"

menu_cursor: .byte $00
