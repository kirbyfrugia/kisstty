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

  MENU_DATA_OFFSET = TOP_MENU_MARGIN_TOP * SCREEN_WIDTH + 10
  lda #<MENU_DATA_OFFSET
  clc
  adc SCR_PTR_LO
  sta data_menu+Menu::pos_ptr
  lda #>MENU_DATA_OFFSET
  adc SCR_PTR_HI
  sta data_menu+Menu::pos_ptr+1

  lda #<data_menu_and_items
  sta data_menu+Menu::menu_and_items_ptr
  lda #>data_menu_and_items
  sta data_menu+Menu::menu_and_items_ptr+1

  lda #4
  sta data_menu+Menu::num_items
  lda #11
  sta data_menu+Menu::width

  MENU_STOP_OFFSET = (TOP_MENU_MARGIN_TOP+6) * SCREEN_WIDTH + 10
  lda #<MENU_STOP_OFFSET
  clc
  adc SCR_PTR_LO
  sta stop_menu+Menu::pos_ptr
  lda #>MENU_STOP_OFFSET
  adc SCR_PTR_HI
  sta stop_menu+Menu::pos_ptr+1

  lda #<stop_menu_and_items
  sta stop_menu+Menu::menu_and_items_ptr
  lda #>stop_menu_and_items
  sta stop_menu+Menu::menu_and_items_ptr+1

  lda #2
  sta stop_menu+Menu::num_items
  lda #11
  sta stop_menu+Menu::width


  MENU_TRANSLATION_OFFSET = TOP_MENU_MARGIN_TOP * SCREEN_WIDTH + 24
  lda #<MENU_TRANSLATION_OFFSET
  clc
  adc SCR_PTR_LO
  sta trans_menu+Menu::pos_ptr
  lda #>MENU_TRANSLATION_OFFSET
  adc SCR_PTR_HI
  sta trans_menu+Menu::pos_ptr+1

  lda #<trans_menu_and_items
  sta trans_menu+Menu::menu_and_items_ptr
  lda #>trans_menu_and_items
  sta trans_menu+Menu::menu_and_items_ptr+1

  lda #3
  sta trans_menu+Menu::num_items
  lda #7
  sta trans_menu+Menu::width

  MENU_CTRL_OFFSET = (TOP_MENU_MARGIN_TOP+5) * SCREEN_WIDTH + 24
  lda #<MENU_CTRL_OFFSET
  clc
  adc SCR_PTR_LO
  sta ctrl_menu+Menu::pos_ptr
  lda #>MENU_CTRL_OFFSET
  adc SCR_PTR_HI
  sta ctrl_menu+Menu::pos_ptr+1

  lda #<ctrl_menu_and_items
  sta ctrl_menu+Menu::menu_and_items_ptr
  lda #>ctrl_menu_and_items
  sta ctrl_menu+Menu::menu_and_items_ptr+1

  lda #7
  sta ctrl_menu+Menu::num_items
  lda #12
  sta ctrl_menu+Menu::width


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
  draw_menu data_menu
  draw_menu stop_menu
  draw_menu trans_menu
  draw_menu ctrl_menu
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

baud_menu:             .tag Menu
baud_menu_and_items:   .byte "[B]aud"
baud_menu_item_baud0:  .byte " 300  "
baud_menu_item_baud1:  .byte " 600  "
baud_menu_item_baud2:  .byte " 1200 "
baud_menu_item_baud3:  .byte " 1800 "
baud_menu_item_baud4:  .byte " 2400 "
baud_menu_item_baud5:  .byte " 4800 "
baud_menu_item_baud6:  .byte " 9600 "
baud_menu_item_baud7:  .byte " 19200"

data_menu:             .tag Menu
data_menu_and_items:   .byte "[D]ata Size"
data_menu_item_word5:  .byte " 5 bits    "
data_menu_item_word6:  .byte " 6 bits    "
data_menu_item_word7:  .byte " 7 bits    "
data_menu_item_word8:  .byte " 8 bits    "

stop_menu:             .tag Menu
stop_menu_and_items:   .byte "[S]top bits"
stop_menu_item_word1:  .byte " 1 bit     "
stop_menu_item_word2:  .byte " 2 bits    "

trans_menu:            .tag Menu
trans_menu_and_items:  .byte "[T]rans"
trans_menu_item_none:  .byte " None  "
trans_menu_item_light: .byte " Light "
trans_menu_item_heavy: .byte " Heavy "

ctrl_menu:             .tag Menu
ctrl_menu_and_items:   .byte "[C]ontrol   "
ctrl_menu_item0:       .byte " CRX        "
ctrl_menu_item1:       .byte " CTS        "
ctrl_menu_item2:       .byte " CTS+CRX    "
ctrl_menu_item3:       .byte " DSR        "
ctrl_menu_item4:       .byte " DSR+CRX    "
ctrl_menu_item5:       .byte " DSR+CTS    "
ctrl_menu_item6:       .byte " DSR+CTS+CRX"

parity_menu:           .tag Menu
parity_menu_and_items: .byte "[P]arity"
parity_menu_item_none: .byte " None   "
parity_menu_item_even: .byte " Even   "
parity_menu_item_odd:  .byte " Odd    "
parity_menu_item_one:  .byte " One    "

cfg_config_done: .byte 0
