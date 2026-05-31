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

  OFFSET       .set (MENU_MARGIN_TOP+19) * SCREEN_WIDTH + 1
  BAUD         .set 1
  DATA_BITS    .set 3
  STOP_BITS    .set 0
  PARITY       .set 0
  DUPLEX       .set 0
  CTS          .set 0
  DSR          .set 0
  DTR          .set 1
  RETS         .set 1
  TRANSLATION  .set 0
  make_config preset1_config, BAUD, DATA_BITS, \
              STOP_BITS, PARITY, DUPLEX, CTS, DSR, DTR, RETS, \
              TRANSLATION
  make_preset preset1, preset1_config, \
              preset1_label, OFFSET 

  OFFSET       .set (MENU_MARGIN_TOP+20) * SCREEN_WIDTH + 1
  BAUD         .set 3
  DATA_BITS    .set 2
  STOP_BITS    .set 0
  PARITY       .set 1
  DUPLEX       .set 0
  CTS          .set 1
  DSR          .set 1
  DTR          .set 1
  RETS         .set 1
  TRANSLATION  .set 0
  make_config preset2_config, BAUD, DATA_BITS, \
              STOP_BITS, PARITY, DUPLEX, CTS, DSR, DTR, RETS, \
              TRANSLATION
  make_preset preset2, preset2_config, \
              preset2_label, OFFSET 

  OFFSET       .set (MENU_MARGIN_TOP+19) * SCREEN_WIDTH + 13
  BAUD         .set 6
  DATA_BITS    .set 3
  STOP_BITS    .set 0
  PARITY       .set 0
  DUPLEX       .set 0
  CTS          .set 0
  DSR          .set 0
  DTR          .set 0
  RETS         .set 0
  TRANSLATION  .set 0
  make_config preset3_config, BAUD, DATA_BITS, \
              STOP_BITS, PARITY, DUPLEX, CTS, DSR, DTR, RETS, \
              TRANSLATION
  make_preset preset3, preset3_config, \
              preset3_label, OFFSET 

  OFFSET       .set (MENU_MARGIN_TOP+20) * SCREEN_WIDTH + 13
  BAUD         .set 7
  DATA_BITS    .set 3
  STOP_BITS    .set 0
  PARITY       .set 0
  DUPLEX       .set 0
  CTS          .set 0
  DSR          .set 0
  DTR          .set 1
  RETS         .set 1
  TRANSLATION  .set 0
  make_config preset4_config, BAUD, DATA_BITS, \
              STOP_BITS, PARITY, DUPLEX, CTS, DSR, DTR, RETS, \
              TRANSLATION
  make_preset preset4, preset4_config, \
              preset4_label, OFFSET 

  ; default config
  copy_struct_abs_to_abs preset2_config, cfg_config, Config

  OFFSET        .set (MENU_MARGIN_TOP+1) * SCREEN_WIDTH + 2
  NUM_ITEMS     .set 8
  BORDER_WIDTH  .set 8
  make_menu baud_menu, baud_menu_header, baud_menu_items, \
            Config::baud, NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+11) * SCREEN_WIDTH + 2
  NUM_ITEMS     .set 4
  BORDER_WIDTH  .set 8
  make_menu parity_menu, parity_menu_header, parity_menu_items, \
            Config::parity, NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+1) * SCREEN_WIDTH + 11
  NUM_ITEMS     .set 4
  BORDER_WIDTH  .set 10
  make_menu data_menu, data_menu_header, data_menu_items, \
            Config::data_bits, NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+7) * SCREEN_WIDTH + 11
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 10
  make_menu stop_menu, stop_menu_header, stop_menu_items, \
            Config::stop_bits, NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+11) * SCREEN_WIDTH + 11
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 10
  make_menu duplex_menu, duplex_menu_header, duplex_menu_items, \
            Config::duplex, NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+9) * SCREEN_WIDTH + 22
  NUM_ITEMS     .set 3
  BORDER_WIDTH  .set 15
  make_menu trans_menu, trans_menu_header, trans_menu_items, \
            Config::translation, NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+1) * SCREEN_WIDTH + 22
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 7
  make_menu cts_menu, cts_menu_header, cts_menu_items, \
            Config::cts, NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+1) * SCREEN_WIDTH + 30
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 7
  make_menu dsr_menu, dsr_menu_header, dsr_menu_items, \
            Config::dsr, NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+5) * SCREEN_WIDTH + 22
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 7
  make_menu dtr_menu, dtr_menu_header, dtr_menu_items, \
            Config::dtr, NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+5) * SCREEN_WIDTH + 30
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 7
  make_menu rts_menu, rts_menu_header, rts_menu_items, \
            Config::rets, NUM_ITEMS, BORDER_WIDTH, OFFSET

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
  stx menu_data_offset
@menu_item_rows_loop:
  ldy #0
  lda #$41 ; vertical left bar
  sta (CFG_SCR_PTR_LO),y
  iny
  iny
@menu_item_loop:
  sty draw_menu_tempy ; offset on current line
  ldy menu_data_offset 
  lda (CFG_DATA_PTR_LO),y
  beq @menu_item_done ; null terminator
  jsr utils_atascii_to_icode
  ldy draw_menu_tempy
  sta (CFG_SCR_PTR_LO),y
  iny
  inc menu_data_offset 
  jmp @menu_item_loop
@menu_item_done:
  ldy draw_menu_border_width
  lda #$44 ; vertical right bar
  sta (CFG_SCR_PTR_LO),y

  inc menu_data_offset 
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

int_draw_banners:
  lda SCR_PTR_LO
  sta CFG_SCR_PTR_LO
  lda SCR_PTR_HI
  sta CFG_SCR_PTR_HI

  ldy #(SCREEN_WIDTH-1)
  ;lda #' '|$80
  lda #' '
  eor #$80
  jsr utils_atascii_to_icode
@top_bar_loop:
  sta (CFG_SCR_PTR_LO),y
  dey
  bpl @top_bar_loop

  lda SCR_PTR_LO
  clc
  adc #1
  sta CFG_SCR_PTR_LO
  lda SCR_PTR_HI
  adc #0
  sta CFG_SCR_PTR_HI

  ldy #0
@top_banner_loop:
  lda top_banner,y
  beq @top_banner_done
  eor #$80
  jsr utils_atascii_to_icode
  sta (CFG_SCR_PTR_LO),y
  iny
  jmp @top_banner_loop
@top_banner_done:

  OFFSET .set (MENU_MARGIN_TOP+18) * SCREEN_WIDTH + 1
  lda SCR_PTR_LO
  clc
  adc #<OFFSET
  sta CFG_SCR_PTR_LO
  lda SCR_PTR_HI
  adc #>OFFSET
  sta CFG_SCR_PTR_HI

  ldy #0
@serial_preset_loop:
  lda presets,y
  beq @serial_preset_done
  jsr utils_atascii_to_icode
  sta (CFG_SCR_PTR_LO),y
  iny
  jmp @serial_preset_loop
@serial_preset_done:

  rts

cfg_activate:
  lda #0
  sta cfg_config_done

  draw_menu baud_menu
  draw_menu parity_menu
  draw_menu data_menu
  draw_menu stop_menu
  draw_menu trans_menu
  draw_menu cts_menu
  draw_menu dsr_menu
  draw_menu dtr_menu
  draw_menu rts_menu
  draw_menu duplex_menu

  jsr int_highlight_all_selected

  draw_preset preset1
  draw_preset preset3
  draw_preset preset2
  draw_preset preset4

  jsr int_draw_banners

  rts

int_highlight_all_selected:
  highlight_selected baud_menu
  highlight_selected parity_menu
  highlight_selected data_menu
  highlight_selected stop_menu
  highlight_selected trans_menu
  highlight_selected cts_menu
  highlight_selected dsr_menu
  highlight_selected dtr_menu
  highlight_selected rts_menu
  highlight_selected duplex_menu
  rts

; inputs:
;   CFG_PTR_LO/HI    - pointer to menu struct
int_highlight_selected_menu_item:
  ldy #Menu::scr_pos_ptr
  lda (CFG_PTR_LO),y
  clc
  adc #SCREEN_WIDTH
  sta CFG_SCR_PTR_LO
  iny
  lda (CFG_PTR_LO),y
  adc #0
  sta CFG_SCR_PTR_HI

  ldy #Menu::menu_items_ptr
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_LO
  iny
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_HI

  ldy #Menu::config_index
  lda (CFG_PTR_LO),y
  tay
  lda cfg_config,y
  sta menu_item_selected

  ldy #Menu::border_width
  lda (CFG_PTR_LO),y
  sta menu_item_border_width

  ldy #Menu::num_items
  lda (CFG_PTR_LO),y
  sta menu_item_num_items

  ldx #0
@menu_item_rows_loop:
  cpx menu_item_selected
  beq @menu_item_match

  ; if here, this is not the row, but let's
  ; make sure we de-highlight it if needed
  ldy #1
  lda (CFG_SCR_PTR_LO),y
  and #%10000000 ; check if msb set on first char
  beq @menu_item_row_done ; was not highlighted
@dehighlight_loop:
  lda (CFG_SCR_PTR_LO),y
  and #%01111111
  sta (CFG_SCR_PTR_LO),y
  iny
  cpy menu_item_border_width
  bne @dehighlight_loop
  beq @menu_item_row_done
@menu_item_match:
  ldy #1
@highlight_loop:
  lda (CFG_SCR_PTR_LO),y
  ora #%10000000
  sta (CFG_SCR_PTR_LO),y
  iny
  cpy menu_item_border_width
  bne @highlight_loop
@menu_item_row_done:
  inx
  cpx menu_item_num_items
  beq @done
  lda CFG_SCR_PTR_LO
  clc
  adc #SCREEN_WIDTH
  sta CFG_SCR_PTR_LO
  lda CFG_SCR_PTR_HI
  adc #0
  sta CFG_SCR_PTR_HI
  jmp @menu_item_rows_loop
@done:
  rts



int_cmd_cancel:
  lda #1
  sta cfg_config_done
  rts

int_cmd_preset1:
  copy_struct_abs_to_abs preset1_config, cfg_config, Config
  jsr int_highlight_all_selected
  rts

int_cmd_preset2:
  copy_struct_abs_to_abs preset2_config, cfg_config, Config
  jsr int_highlight_all_selected
  rts

int_cmd_preset3:
  copy_struct_abs_to_abs preset3_config, cfg_config, Config
  jsr int_highlight_all_selected
  rts

int_cmd_preset4:
  copy_struct_abs_to_abs preset4_config, cfg_config, Config
  jsr int_highlight_all_selected
  rts

int_cmd_baud:
  handle_menu_next baud_menu, cfg_config+Config::baud
  rts

int_cmd_parity:
  handle_menu_next parity_menu, cfg_config+Config::parity
  rts

int_cmd_data:
  handle_menu_next data_menu, cfg_config+Config::data_bits
  rts

int_cmd_stop:
  handle_menu_next stop_menu, cfg_config+Config::stop_bits
  rts

int_cmd_duplex:
  handle_menu_next duplex_menu, cfg_config+Config::duplex
  rts

int_cmd_cts:
  handle_menu_next cts_menu, cfg_config+Config::cts
  rts

int_cmd_dsr:
  handle_menu_next dsr_menu, cfg_config+Config::dsr
  rts

int_cmd_dtr:
  handle_menu_next dtr_menu, cfg_config+Config::dtr
  rts

int_cmd_rets:
  handle_menu_next rts_menu, cfg_config+Config::rets
  rts

int_cmd_translation:
  handle_menu_next trans_menu, cfg_config+Config::translation
  rts

int_cmd_accept:
  lda #1
  sta cfg_config_done
  rts

int_handle_kbd:
  lda g_kbd_key_pressed
  bne @valid_key
  jmp @done
@valid_key:
  lda g_kbdcode_raw
  cmp #$15
  beq @baud
  cmp #$0a
  beq @parity
  cmp #$3a
  beq @data
  cmp #$08
  beq @stop
  cmp #$0b
  beq @duplex
  cmp #$12
  beq @cts
  cmp #$3e
  beq @dsr
  cmp #$2d
  beq @dtr
  cmp #$28
  beq @rets
  cmp #$00
  beq @translation
  cmp #$1f
  beq @one
  cmp #$1e
  beq @two
  cmp #$1a
  beq @three
  cmp #$18
  beq @four
  cmp #$1c
  beq @escape
  cmp #$0c
  beq @return
  bne @done
@baud:
  jsr int_cmd_baud
  jmp @done
@parity:
  jsr int_cmd_parity
  jmp @done
@data:
  jsr int_cmd_data
  jmp @done
@stop:
  jsr int_cmd_stop
  jmp @done
@duplex:
  jsr int_cmd_duplex
  jmp @done
@cts:
  jsr int_cmd_cts
  jmp @done
@dsr:
  jsr int_cmd_dsr
  jmp @done
@dtr:
  jsr int_cmd_dtr
  jmp @done
@rets:
  jsr int_cmd_rets
  jmp @done
@translation:
  jsr int_cmd_translation
  jmp @done
@one:
  jsr int_cmd_preset1
  jmp @done
@two:
  jsr int_cmd_preset2
  jmp @done
@three:
  jsr int_cmd_preset3
  jmp @done
@four:
  jsr int_cmd_preset4
  jmp @done
@escape:
  jsr int_cmd_cancel
  jmp @done
@return:
  jsr int_cmd_accept
@done:
  rts

cfg_tick:
  jsr int_handle_kbd
  rts

baud_menu:                .tag Menu
baud_menu_header:         .byte 'B'|$80,"aud",$00
baud_menu_items:
baud_menu_item_baud50:    .byte "50",$00
baud_menu_item_baud300:   .byte "300",$00
baud_menu_item_baud600:   .byte "600",$00
baud_menu_item_baud1200:  .byte "1200",$00
baud_menu_item_baud2400:  .byte "2400",$00
baud_menu_item_baud4800:  .byte "4800",$00
baud_menu_item_baud9600:  .byte "9600",$00
baud_menu_item_baud19200: .byte "19200",$00

data_menu:                .tag Menu
data_menu_header:         .byte 'D'|$80,"ata",$00
data_menu_items:
data_menu_item_word5:     .byte "5 bit",$00
data_menu_item_word6:     .byte "6 bit",$00
data_menu_item_word7:     .byte "7 bit",$00
data_menu_item_word8:     .byte "8 bit",$00

stop_menu:                .tag Menu
stop_menu_header:         .byte "St",'O'|$80,"p",$00
stop_menu_items:
stop_menu_item_word1:     .byte "1 bit",$00
stop_menu_item_word2:     .byte "2 bit",$00

trans_menu:               .tag Menu
trans_menu_header:        .byte "Trans",'L'|$80,"ation",$00
trans_menu_items:
trans_menu_item_none:     .byte "None",$00
trans_menu_item_light:    .byte "Light",$00
trans_menu_item_heavy:    .byte "Heavy",$00

cts_menu:                 .tag Menu
cts_menu_header:          .byte 'C'|$80,"TS",$00
cts_menu_items:
cts_menu_item_off:        .byte "OFF",$00
cts_menu_item_on:         .byte "ON",$00

dsr_menu:                 .tag Menu
dsr_menu_header:          .byte "D",'S'|$80,"R",$00
dsr_menu_items:
dsr_menu_item_off:        .byte "OFF",$00
dsr_menu_item_on:         .byte "ON",$00

dtr_menu:                 .tag Menu
dtr_menu_header:          .byte "D",'T'|$80,"R",$00
dtr_menu_items:
dtr_menu_item_off:        .byte "OFF",$00
dtr_menu_item_on:         .byte "ON",$00

rts_menu:                 .tag Menu
rts_menu_header:          .byte 'R'|$80,"TS",$00
rts_menu_items:
rts_menu_item_off:        .byte "OFF",$00
rts_menu_item_on:         .byte "ON",$00

duplex_menu:              .tag Menu
duplex_menu_header:       .byte "D",'U'|$80,"plex",$00
duplex_menu_items:
duplex_menu_item_full:    .byte "Full",$00
duplex_menu_item_half:    .byte "Half",$00

parity_menu:              .tag Menu
parity_menu_header:       .byte 'P'|$80,"arity",$00
parity_menu_items:
parity_menu_item_none:    .byte "None",$00
parity_menu_item_even:    .byte "Even",$00
parity_menu_item_odd:     .byte "Odd",$00
parity_menu_item_one:     .byte "One",$00

presets:        .byte "Serial presets:",$00
preset1:        .tag Preset
preset1_config: .tag Config
preset1_label:  .byte '1'|$80,"8-N-1 300",$00
preset2:        .tag Preset
preset2_config: .tag Config
preset2_label:  .byte '2'|$80,"7-E-1 1200",$00
preset3:        .tag Preset
preset3_config: .tag Config
preset3_label:  .byte '3'|$80,"8-N-1 9600",$00
preset4:        .tag Preset
preset4_config: .tag Config
preset4_label:  .byte '4'|$80,"8-N-1 19200",$00


top_banner:             .byte 'S'|$80,'E'|$80,'L'|$80,"theme "
                        .byte 'E'|$80,'S'|$80,'C'|$80,"revert "
                        .byte 'R'|$80,'E'|$80,'T'|$80,"terminal"
                        .byte $00
draw_menu_tempy:        .byte 0
draw_menu_border_width: .byte 0
draw_menu_num_items:    .byte 0
draw_menu_end_column:   .byte 0
draw_menu_data_length:  .byte 0

menu_data_offset:       .byte 0
menu_item_selected:     .byte 0
menu_item_num_items:    .byte 0
menu_item_border_width: .byte 0

highlight_border_width: .byte 0

cfg_old_config:         .tag Config
cfg_config:             .tag Config
cfg_config_done:        .byte 0
