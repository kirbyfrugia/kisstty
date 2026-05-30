.SETCPU "6502"

.INCLUDE "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"

.IMPORT g_kbd_key_pressed
.IMPORT g_kbdcode_raw
.IMPORT g_kbdcode_raw_stripped
.IMPORT g_kbdcode_atascii
.IMPORT utils_atascii_to_icode
.EXPORT cfg_init
.EXPORT cfg_activate
.EXPORT cfg_tick
.EXPORT cfg_config_done

.SEGMENT "CODE"

TOP_MENU_MARGIN_TOP = 1

cfg_init:
  lda #0
  sta cfg_config_done

  MENU_BAUD_OFFSET = TOP_MENU_MARGIN_TOP * SCREEN_WIDTH + 1
  lda #<MENU_BAUD_OFFSET
  clc
  adc SCR_PTR_LO
  sta baud_menu+Menu::pos_ptr
  lda #>MENU_BAUD_OFFSET
  adc SCR_PTR_HI
  sta baud_menu+Menu::pos_ptr+1

  lda #<baud_menu_and_items
  sta baud_menu+Menu::menu_and_items_ptr
  lda #>baud_menu_and_items
  sta baud_menu+Menu::menu_and_items_ptr+1

  lda #8
  sta baud_menu+Menu::num_items
  lda #6
  sta baud_menu+Menu::width
  rts

int_dehighlight_menu_item:
  rts

int_highlight_menu_item:
  rts


; inputs:
;   CMDDATA0/1 - pointer to screen location for upper border
;   CMDDATA2/3 - pointer to menu heading
;   CMDDATA4   - height of border
;   CMDDATA5   - width of header
;   CMDDATA6   - end column of border
int_draw_menu_border:
  ldy #0
  lda #$51 ; upper left corner
  sta (CMDDATA0),y
@header_loop:
  lda (CMDDATA2),y
  jsr utils_atascii_to_icode
  iny
  sta (CMDDATA0),y
  cpy CMDDATA5
  bne @header_loop
  iny
  lda #$52 ; horizontal bar
@header_loop_remainder:
  sta (CMDDATA0),y
  iny
  cpy CMDDATA6
  bne @header_loop_remainder

  lda #$45 ; upper right corner
  sta (CMDDATA0),y

  lda CMDDATA0
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1

  ldx #1
@middle_loop:
  lda #$41 ; vertical left bar
  ldy #0
  sta (CMDDATA0),y
  tya
  clc
  adc CMDDATA6
  tay
  lda #$44 ; vertical right bar
  sta (CMDDATA0),y
  inx
  cpx CMDDATA4
  beq @middle_loop_done

  lda CMDDATA0
  clc
  adc #SCREEN_WIDTH
  sta CMDDATA0
  lda CMDDATA1
  adc #0
  sta CMDDATA1
  jmp @middle_loop
@middle_loop_done:
  ldy #0
  lda #$5a ; lower left corner
  sta (CMDDATA0),y
  iny
  lda #$52 ; horizontal bar
@bottom_loop:
  sta (CMDDATA0),y
  iny
  cpy CMDDATA6
  bne @bottom_loop
  lda #$43 ; lower right corner
  sta (CMDDATA0),y

  rts

; inputs:
;   CMDDATA0/1 - pointer to screen location for upper left char
;   CMDDATA2/3 - pointer to item strings
;   CMDDATA4   - num menu items
;   CMDDATA5   - width of each item
int_draw_menu_items:
  ldx #0
@row_loop:
  lda #$00
  ldy #0
  sta (CMDDATA0),y
@col_loop:
  lda (CMDDATA2),y
  jsr utils_atascii_to_icode
  sta (CMDDATA0),y
  iny
  cpy CMDDATA5
  bne @col_loop
@col_done:
  inx
  cpx CMDDATA4
  beq @done

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
  jmp @row_loop
@done:
  rts

cfg_activate:
  lda #0
  sta cfg_config_done

  draw_menu baud_menu
  rts

int_cmd_return:
  lda #1
  sta cfg_config_done
  rts

int_handle_kbd:
  lda g_kbd_key_pressed
  beq @done
  lda g_kbdcode_raw
  cmp #$0c
  beq @return
  bne @done
@return:
  jsr int_cmd_return
@done:
  rts

cfg_tick:
  jsr int_handle_kbd
  rts

baud_menu:            .tag Menu
baud_menu_and_items:  .byte "[B]aud"
baud_menu_item_baud0: .byte " 300  "
baud_menu_item_baud1: .byte " 600  "
baud_menu_item_baud2: .byte " 1200 "
baud_menu_item_baud3: .byte " 1800 "
baud_menu_item_baud4: .byte " 2400 "
baud_menu_item_baud5: .byte " 4800 "
baud_menu_item_baud6: .byte " 9600 "
baud_menu_item_baud7: .byte " 19200"

draw_menu_border_end: .byte $00

menu_cursor: .byte $00

cfg_config_done: .byte 0
