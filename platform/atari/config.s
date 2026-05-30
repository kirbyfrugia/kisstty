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
.LINECONT +

MENU_MARGIN_TOP = 1

cfg_init:
  lda #0
  sta cfg_config_done

  OFFSET       .set (MENU_MARGIN_TOP+0) * SCREEN_WIDTH + 2
  NUM_ITEMS    .set 10
  BORDER_WIDTH .set 8
  make_menu baud_menu, baud_menu_header, baud_menu_items, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET       .set (MENU_MARGIN_TOP+0) * SCREEN_WIDTH + 11
  NUM_ITEMS    .set 4
  BORDER_WIDTH .set 10
  make_menu data_menu, data_menu_header, data_menu_items, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET       .set (MENU_MARGIN_TOP+6) * SCREEN_WIDTH + 11
  NUM_ITEMS    .set 2
  BORDER_WIDTH .set 10
  make_menu stop_menu, stop_menu_header, stop_menu_items, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET       .set (MENU_MARGIN_TOP+10) * SCREEN_WIDTH + 11
  NUM_ITEMS    .set 2
  BORDER_WIDTH .set 10
  make_menu duplex_menu, duplex_menu_header, duplex_menu_items, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET       .set (MENU_MARGIN_TOP+8) * SCREEN_WIDTH + 22
  NUM_ITEMS    .set 3
  BORDER_WIDTH .set 15
  make_menu trans_menu, trans_menu_header, trans_menu_items, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET       .set (MENU_MARGIN_TOP+0) * SCREEN_WIDTH + 22
  NUM_ITEMS    .set 2
  BORDER_WIDTH .set 7
  make_menu cts_menu, cts_menu_header, cts_menu_items, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET       .set (MENU_MARGIN_TOP+0) * SCREEN_WIDTH + 30
  NUM_ITEMS    .set 2
  BORDER_WIDTH .set 7
  make_menu dsr_menu, dsr_menu_header, dsr_menu_items, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET       .set (MENU_MARGIN_TOP+4) * SCREEN_WIDTH + 22
  NUM_ITEMS    .set 2
  BORDER_WIDTH .set 7
  make_menu dtr_menu, dtr_menu_header, dtr_menu_items, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET       .set (MENU_MARGIN_TOP+4) * SCREEN_WIDTH + 30
  NUM_ITEMS    .set 2
  BORDER_WIDTH .set 7
  make_menu rts_menu, rts_menu_header, rts_menu_items, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET       .set (MENU_MARGIN_TOP+16) * SCREEN_WIDTH + 1
  BAUD         .set 8
  DATA_BITS    .set 3
  STOP_BITS    .set 0
  PARITY       .set 0
  DUPLEX       .set 0
  CTS          .set 0
  DSR          .set 0
  DTR          .set 0
  RETS         .set 0
  TRANSLATION  .set 0
  make_preset preset1, preset1_label, BAUD, DATA_BITS, \
              STOP_BITS, PARITY, DUPLEX, CTS, DSR, DTR, RETS, \
              TRANSLATION, OFFSET 

  OFFSET       .set (MENU_MARGIN_TOP+17) * SCREEN_WIDTH + 1
  BAUD         .set 8
  DATA_BITS    .set 3
  STOP_BITS    .set 0
  PARITY       .set 0
  DUPLEX       .set 0
  CTS          .set 0
  DSR          .set 0
  DTR          .set 0
  RETS         .set 0
  TRANSLATION  .set 0
  make_preset preset2, preset2_label, BAUD, DATA_BITS, \
              STOP_BITS, PARITY, DUPLEX, CTS, DSR, DTR, RETS, \
              TRANSLATION, OFFSET 
  
  OFFSET       .set (MENU_MARGIN_TOP+18) * SCREEN_WIDTH + 1
  BAUD         .set 8
  DATA_BITS    .set 3
  STOP_BITS    .set 0
  PARITY       .set 0
  DUPLEX       .set 0
  CTS          .set 0
  DSR          .set 0
  DTR          .set 0
  RETS         .set 0
  TRANSLATION  .set 0
  make_preset preset3, preset3_label, BAUD, DATA_BITS, \
              STOP_BITS, PARITY, DUPLEX, CTS, DSR, DTR, RETS, \
              TRANSLATION, OFFSET 

  OFFSET       .set (MENU_MARGIN_TOP+19) * SCREEN_WIDTH + 1
  BAUD         .set 8
  DATA_BITS    .set 3
  STOP_BITS    .set 0
  PARITY       .set 0
  DUPLEX       .set 0
  CTS          .set 0
  DSR          .set 0
  DTR          .set 0
  RETS         .set 0
  TRANSLATION  .set 0
  make_preset preset4, preset4_label, BAUD, DATA_BITS, \
              STOP_BITS, PARITY, DUPLEX, CTS, DSR, DTR, RETS, \
              TRANSLATION, OFFSET 

  rts

int_dehighlight_menu_item:
  rts

int_highlight_menu_item:
  rts


; draws a menu
; note: assumes <256 chars worth of menu item data
;
; inputs:
;   CFG_PTR_LO/HI - pointer to menu struct
;
int_draw_menu:
  ldy #Menu::scr_pos_ptr
  lda (CFG_PTR_LO),y
  sta CFG_SCR_PTR_LO
  iny
  lda (CFG_PTR_LO),y
  sta CFG_SCR_PTR_HI

  ldy #Menu::border_width
  lda (CFG_PTR_LO),y
  sta draw_menu_border_width

  ldy #Menu::num_items
  lda (CFG_PTR_LO),y
  sta draw_menu_num_items

@top_border:
  ldy #0
  lda #$51 ; upper left corner
  sta (CFG_SCR_PTR_LO),y
  lda #$52 ; horizontal bar
@top_loop:
  iny
  sta (CFG_SCR_PTR_LO),y
  cpy draw_menu_border_width
  bne @top_loop
  lda #$45 ; upper right corner
  sta (CFG_SCR_PTR_LO),y

@header:
  ; header data -> CFG_DATA_PTR_LO
  ldy #Menu::header_ptr
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_LO
  iny
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_HI

  ldy #0
@header_loop:
  lda (CFG_DATA_PTR_LO),y
  beq @header_loop_done
  jsr utils_atascii_to_icode
  iny
  sta (CFG_SCR_PTR_LO),y
  jmp @header_loop
@header_loop_done:
  ; move to next row for menu items
  lda CFG_SCR_PTR_LO
  clc
  adc #SCREEN_WIDTH
  sta CFG_SCR_PTR_LO
  lda CFG_SCR_PTR_HI
  adc #0
  sta CFG_SCR_PTR_HI
  
  ; menu item data -> CFG_DATA_PTR_LO
  ldy #Menu::menu_items_ptr
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_LO
  iny
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_HI

  ldx #0
  stx draw_menu_data_offset
@menu_item_rows_loop:
  ldy #0
  lda #$41 ; vertical left bar
  sta (CFG_SCR_PTR_LO),y
  iny
  iny
@menu_item_loop:
  sty draw_menu_tempy ; offset on current line
  ldy draw_menu_data_offset 
  lda (CFG_DATA_PTR_LO),y
  beq @menu_item_done ; null terminator
  jsr utils_atascii_to_icode
  ldy draw_menu_tempy
  sta (CFG_SCR_PTR_LO),y
  iny
  inc draw_menu_data_offset 
  jmp @menu_item_loop
@menu_item_done:
  ldy draw_menu_border_width
  lda #$44 ; vertical right bar
  sta (CFG_SCR_PTR_LO),y

  inc draw_menu_data_offset 
  lda CFG_SCR_PTR_LO
  clc
  adc #SCREEN_WIDTH
  sta CFG_SCR_PTR_LO
  lda CFG_SCR_PTR_HI
  adc #0
  sta CFG_SCR_PTR_HI

  inx
  cpx draw_menu_num_items
  beq @menu_item_rows_loop_done
  bne @menu_item_rows_loop
@menu_item_rows_loop_done:

  ldy #0
  lda #$5a ; lower left corner
  sta (CFG_SCR_PTR_LO),y
  lda #$52 ; horizontal bar
@btm_loop:
  iny
  sta (CFG_SCR_PTR_LO),y
  cpy draw_menu_border_width
  bne @btm_loop
  lda #$43 ; lower right corner
  sta (CFG_SCR_PTR_LO),y

  rts

int_draw_preset:
  ldy #Preset::scr_pos_ptr
  lda (CFG_PTR_LO),y
  sta CFG_SCR_PTR_LO
  iny
  lda (CFG_PTR_LO),y
  sta CFG_SCR_PTR_HI

  ldy #Preset::label_ptr
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_LO
  iny
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_HI

  ldy #0
@loop:
  lda (CFG_DATA_PTR_LO),y
  beq @loop_done ; null char
  jsr utils_atascii_to_icode
  sta (CFG_SCR_PTR_LO),y
  iny
  bne @loop
@loop_done:
 
  rts

cfg_activate:
  lda #0
  sta cfg_config_done

  draw_menu baud_menu
  draw_menu data_menu
  draw_menu stop_menu
  draw_menu trans_menu
  draw_menu cts_menu
  draw_menu dsr_menu
  draw_menu dtr_menu
  draw_menu rts_menu
  draw_menu duplex_menu

  draw_preset preset1
  draw_preset preset2
  draw_preset preset3
  draw_preset preset4

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

baud_menu:                .tag Menu
baud_menu_header:         .byte "[B]aud",$00
baud_menu_items:
baud_menu_item_baud50:    .byte "50",$00
baud_menu_item_baud110:   .byte "110",$00
baud_menu_item_baud300:   .byte "300",$00
baud_menu_item_baud600:   .byte "600",$00
baud_menu_item_baud1200:  .byte "1200",$00
baud_menu_item_baud1800:  .byte "1800",$00
baud_menu_item_baud2400:  .byte "2400",$00
baud_menu_item_baud4800:  .byte "4800",$00
baud_menu_item_baud9600:  .byte "9600",$00
baud_menu_item_baud19200: .byte "19200",$00

data_menu:                .tag Menu
data_menu_header:         .byte "[D]ata",$00
data_menu_items:
data_menu_item_word5:     .byte "5 bit",$00
data_menu_item_word6:     .byte "6 bit",$00
data_menu_item_word7:     .byte "7 bit",$00
data_menu_item_word8:     .byte "8 bit",$00

stop_menu:                .tag Menu
stop_menu_header:         .byte "Sto[P]",$00
stop_menu_items:
stop_menu_item_word1:     .byte "1 bit",$00
stop_menu_item_word2:     .byte "2 bit",$00

trans_menu:               .tag Menu
trans_menu_header:        .byte "Trans[L]ation",$00
trans_menu_items:
trans_menu_item_none:     .byte "None",$00
trans_menu_item_light:    .byte "Light",$00
trans_menu_item_heavy:    .byte "Heavy",$00

cts_menu:                 .tag Menu
cts_menu_header:          .byte "[C]TS",$00
cts_menu_items:
cts_menu_item_on:         .byte "ON",$00
cts_menu_item_off:        .byte "OFF",$00

dsr_menu:                 .tag Menu
dsr_menu_header:          .byte "D[S]R",$00
dsr_menu_items:
dsr_menu_item_on:         .byte "ON",$00
dsr_menu_item_off:        .byte "OFF",$00

dtr_menu:                 .tag Menu
dtr_menu_header:          .byte "D[T]R",$00
dtr_menu_items:
dtr_menu_item_on:         .byte "ON",$00
dtr_menu_item_off:        .byte "OFF",$00

rts_menu:                 .tag Menu
rts_menu_header:          .byte "[R]TS",$00
rts_menu_items:
rts_menu_item_on:         .byte "ON",$00
rts_menu_item_off:        .byte "OFF",$00

duplex_menu:              .tag Menu
duplex_menu_header:       .byte "D[U]plex",$00
duplex_menu_items:
duplex_menu_item_full:    .byte "Full",$00
duplex_menu_item_half:    .byte "Half",$00

parity_menu:              .tag Menu
parity_menu_header:       .byte "[P]arity",$00
parity_menu_items:
parity_menu_item_none:    .byte "None",$00
parity_menu_item_even:    .byte "Even",$00
parity_menu_item_odd:     .byte "Odd",$00
parity_menu_item_one:     .byte "One",$00

presets:       .byte "Presets:",$00
preset1:       .tag Preset
preset1_label: .byte "[1]Packet:    9600 8-N-1",$00
preset2:       .tag Preset
preset2_label: .byte "[2]Terminal:  9600 8-N-1F",$00
preset3:       .tag Preset
preset3_label: .byte "[3]Vintage:   1200 7-E-1S",$00
preset4:       .tag Preset
preset4_label: .byte "[4]Fast:     19200 8-N-1",$00

draw_menu_data_offset:  .byte 0
draw_menu_tempy:        .byte 0
draw_menu_border_width: .byte 0
draw_menu_num_items:    .byte 0
draw_menu_end_column:   .byte 0
draw_menu_data_length:  .byte 0

cfg_config_done: .byte 0
