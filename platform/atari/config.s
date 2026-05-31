.SETCPU "6502"

.INCLUDE "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"
.INCLUDE "rs232.inc"
.INCLUDE "terminal.inc"

.IMPORT g_kbd_key_pressed
.IMPORT g_kbdcode_raw
.IMPORT g_kbdcode_raw_stripped
.IMPORT g_kbdcode_atascii
.IMPORT utils_atascii_to_icode
.EXPORT cfg_init
.EXPORT cfg_activate
.EXPORT cfg_tick
.EXPORT cfg_config_done
.EXPORT cfg_saved_config

.SEGMENT "CODE"
.LINECONT +

MENU_MARGIN_TOP = 1

cfg_init:
  lda #0
  sta cfg_config_done

  OFFSET       .set (MENU_MARGIN_TOP+20) * SCREEN_WIDTH + 1
  make_config preset_fastchar_config, \
                  TERMINAL_PROTOCOL::TERMINAL, \
                  TERMINAL_MODE::CHAR, \
                  RS232_BAUD::B9600, \
                  RS232_WORDSIZE::N8, \
                  RS232_STOPBITS::N1, \
                  RS232_PARITY::NONE, \
                  RS232_DUPLEX::FULL, \
                  RS232_CTS::ON, \
                  RS232_DSR::OFF, \
                  RS232_DTR::ON, \
                  RS232_RTS::ON, \
                  RS232_TRANSLATION::NONE
  make_preset preset_fastchar, preset_fastchar_config, \
              preset_fastchar_label, OFFSET 

  OFFSET       .set (MENU_MARGIN_TOP+21) * SCREEN_WIDTH + 1
  make_config preset_fastline_config, \
                  TERMINAL_PROTOCOL::TERMINAL, \
                  TERMINAL_MODE::LINE, \
                  RS232_BAUD::B9600, \
                  RS232_WORDSIZE::N8, \
                  RS232_STOPBITS::N1, \
                  RS232_PARITY::NONE, \
                  RS232_DUPLEX::FULL, \
                  RS232_CTS::ON, \
                  RS232_DSR::OFF, \
                  RS232_DTR::ON, \
                  RS232_RTS::ON, \
                  RS232_TRANSLATION::NONE
  make_preset preset_fastline, preset_fastline_config, \
              preset_fastline_label, OFFSET 

  OFFSET       .set (MENU_MARGIN_TOP+20) * SCREEN_WIDTH + 13
  make_config preset_vintage_config, \
                  TERMINAL_PROTOCOL::TERMINAL, \
                  TERMINAL_MODE::CHAR, \
                  RS232_BAUD::B1200, \
                  RS232_WORDSIZE::N7, \
                  RS232_STOPBITS::N1, \
                  RS232_PARITY::EVEN, \
                  RS232_DUPLEX::FULL, \
                  RS232_CTS::ON, \
                  RS232_DSR::ON, \
                  RS232_DTR::ON, \
                  RS232_RTS::ON, \
                  RS232_TRANSLATION::NONE
  make_preset preset_vintage, preset_vintage_config, \
              preset_vintage_label, OFFSET 

  OFFSET       .set (MENU_MARGIN_TOP+21) * SCREEN_WIDTH + 13
  make_config preset_APRS_config, \
                  TERMINAL_PROTOCOL::APRS, \
                  TERMINAL_MODE::CHAR, \
                  RS232_BAUD::B9600, \
                  RS232_WORDSIZE::N8, \
                  RS232_STOPBITS::N1, \
                  RS232_PARITY::NONE, \
                  RS232_DUPLEX::FULL, \
                  RS232_CTS::ON, \
                  RS232_DSR::OFF, \
                  RS232_DTR::ON, \
                  RS232_RTS::ON, \
                  RS232_TRANSLATION::NONE
  make_preset preset_APRS, preset_APRS_config, \
              preset_APRS_label, OFFSET 

  ; default config
  copy_struct_abs_to_abs preset_fastchar_config, cfg_draft_config, Config
  copy_struct_abs_to_abs preset_fastchar_config, cfg_saved_config, Config

  OFFSET        .set (MENU_MARGIN_TOP+1) * SCREEN_WIDTH + 2
  NUM_ITEMS     .set 8
  BORDER_WIDTH  .set 8
  make_menu baud_menu, baud_menu_header, \
            baud_menu_item_values, baud_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+11) * SCREEN_WIDTH + 2
  NUM_ITEMS     .set 3
  BORDER_WIDTH  .set 8
  make_menu parity_menu, parity_menu_header, \
            parity_menu_item_values, parity_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+1) * SCREEN_WIDTH + 11
  NUM_ITEMS     .set 4
  BORDER_WIDTH  .set 10
  make_menu data_menu, data_menu_header, \
            data_menu_item_values, data_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+7) * SCREEN_WIDTH + 11
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 10
  make_menu stop_menu, stop_menu_header, \
            stop_menu_item_values, stop_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+11) * SCREEN_WIDTH + 11
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 10
  make_menu duplex_menu, duplex_menu_header, \
            duplex_menu_item_values, duplex_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+10) * SCREEN_WIDTH + 22
  NUM_ITEMS     .set 3
  BORDER_WIDTH  .set 15
  make_menu trans_menu, trans_menu_header, \
            trans_menu_item_values, trans_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+1) * SCREEN_WIDTH + 22
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 7
  make_menu cts_menu, cts_menu_header, \
            cts_menu_item_values, cts_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+1) * SCREEN_WIDTH + 30
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 7
  make_menu dsr_menu, dsr_menu_header, \
            dsr_menu_item_values, dsr_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+5) * SCREEN_WIDTH + 22
  NUM_ITEMS     .set 3
  BORDER_WIDTH  .set 7
  make_menu dtr_menu, dtr_menu_header, \
            dtr_menu_item_values, dtr_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+5) * SCREEN_WIDTH + 30
  NUM_ITEMS     .set 3
  BORDER_WIDTH  .set 7
  make_menu rts_menu, rts_menu_header, \
            rts_menu_item_values, rts_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+15) * SCREEN_WIDTH + 11
  NUM_ITEMS     .set 2
  BORDER_WIDTH  .set 10
  make_menu mode_menu, mode_menu_header, \
            mode_menu_item_values, mode_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  OFFSET        .set (MENU_MARGIN_TOP+15) * SCREEN_WIDTH + 26
  NUM_ITEMS     .set 3
  BORDER_WIDTH  .set 11
  make_menu protocol_menu, protocol_menu_header, \
            protocol_menu_item_values, protocol_menu_item_labels, \
            NUM_ITEMS, BORDER_WIDTH, OFFSET

  rts

; updates and draws a menu
; note: assumes <256 chars worth of menu item data
;
; inputs:
;   CFG_PTR_LO/HI   - pointer to menu struct
;   menu_item_value - initial value
int_refresh_menu:
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
  sta menu_item_num_items

  ldy #Menu::items_values_ptr
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_LO
  iny
  lda (CFG_PTR_LO),y
  sta CFG_DATA_PTR_HI

  jsr int_find_menu_item_index
  lda menu_item_index
  ldy #Menu::selected_index
  sta (CFG_PTR_LO),y

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
  ldy #Menu::items_labels_ptr
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
  cpx menu_item_num_items
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

  jsr int_highlight_selected_menu_item

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

  OFFSET .set (MENU_MARGIN_TOP+19) * SCREEN_WIDTH + 1
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

int_refresh_menus:
  refresh_menu baud_menu,     cfg_draft_config+Config::baud
  refresh_menu parity_menu,   cfg_draft_config+Config::parity
  refresh_menu data_menu,     cfg_draft_config+Config::data_bits
  refresh_menu stop_menu,     cfg_draft_config+Config::stop_bits
  refresh_menu trans_menu,    cfg_draft_config+Config::translation
  refresh_menu cts_menu,      cfg_draft_config+Config::cts
  refresh_menu dsr_menu,      cfg_draft_config+Config::dsr
  refresh_menu dtr_menu,      cfg_draft_config+Config::dtr
  refresh_menu rts_menu,      cfg_draft_config+Config::rets
  refresh_menu duplex_menu,   cfg_draft_config+Config::duplex
  refresh_menu mode_menu,     cfg_draft_config+Config::mode
  refresh_menu protocol_menu, cfg_draft_config+Config::protocol
  rts

cfg_activate:
  lda #0
  sta cfg_config_done

  copy_struct_abs_to_abs cfg_saved_config, cfg_draft_config, Config

  jsr int_refresh_menus

  draw_preset preset_fastchar
  draw_preset preset_vintage
  draw_preset preset_fastline
  draw_preset preset_APRS

  jsr int_draw_banners

  rts

; inputs:
;   CFG_PTR_LO/HI   - pointer to menu struct
;   menu_item_index - index to highlight
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

  ldy #Menu::border_width
  lda (CFG_PTR_LO),y
  sta menu_item_border_width

  ldy #Menu::num_items
  lda (CFG_PTR_LO),y
  sta menu_item_num_items

  ldx #0
@menu_item_rows_loop:
  cpx menu_item_index
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

; Finds the index of the item with this value.
;
; inputs:
;   CFG_DATA_PTR_LO/HI  - pointer to values array
;   menu_item_num_items - number of items in the menu
;   menu_item_value     - value to search for
; outputs:
;   menu_item_index     - index of the value found, zero if not found
int_find_menu_item_index:
  ldy #0
@index_loop:
  lda (CFG_DATA_PTR_LO),y
  cmp menu_item_value
  beq @found
  iny
  cpy menu_item_num_items
  bne @index_loop
  ldy #0
  sty menu_item_index
  beq @done
@found:
  sty menu_item_index
@done:
  rts

; Selects the index after the current index (with wrapping)
; for this menu. And highlights the new item.
;
; inputs:
;   CFG_PTR_LO/HI - pointer to menu
int_select_next_menu_item:
  ldy #Menu::num_items
  lda (CFG_PTR_LO),y
  sta menu_item_num_items

  ldy #Menu::selected_index
  lda (CFG_PTR_LO),y
  clc
  adc #1
  cmp menu_item_num_items
  bcc @nowrap
  lda #0
@nowrap:
  sta menu_item_index
  ldy #Menu::selected_index
  sta (CFG_PTR_LO),y
  jsr int_highlight_selected_menu_item

  rts

int_cmd_cancel:
  lda #1
  sta cfg_config_done
  rts

int_cmd_preset_fastchar:
  copy_struct_abs_to_abs preset_fastchar_config, cfg_draft_config, Config
  jsr int_refresh_menus
  rts

int_cmd_preset_fastline:
  copy_struct_abs_to_abs preset_fastline_config, cfg_draft_config, Config
  jsr int_refresh_menus
  rts

int_cmd_preset_vintage:
  copy_struct_abs_to_abs preset_vintage_config, cfg_draft_config, Config
  jsr int_refresh_menus
  rts

int_cmd_preset_APRS:
  copy_struct_abs_to_abs preset_APRS_config, cfg_draft_config, Config
  jsr int_refresh_menus
  rts

int_cmd_baud:
  handle_menu_next baud_menu
  ldy baud_menu+Menu::selected_index
  lda baud_menu_item_values,y
  sta cfg_draft_config+Config::baud
  rts

int_cmd_parity:
  handle_menu_next parity_menu
  ldy parity_menu+Menu::selected_index
  lda parity_menu_item_values,y
  sta cfg_draft_config+Config::parity
  rts

int_cmd_data:
  handle_menu_next data_menu
  ldy data_menu+Menu::selected_index
  lda data_menu_item_values,y
  sta cfg_draft_config+Config::data_bits
  rts

int_cmd_stop:
  handle_menu_next stop_menu
  ldy stop_menu+Menu::selected_index
  lda stop_menu_item_values,y
  sta cfg_draft_config+Config::stop_bits
  rts

int_cmd_duplex:
  handle_menu_next duplex_menu
  ldy duplex_menu+Menu::selected_index
  lda duplex_menu_item_values,y
  sta cfg_draft_config+Config::duplex
  rts

int_cmd_cts:
  handle_menu_next cts_menu
  ldy cts_menu+Menu::selected_index
  lda cts_menu_item_values,y
  sta cfg_draft_config+Config::cts
  rts

int_cmd_dsr:
  handle_menu_next dsr_menu
  ldy dsr_menu+Menu::selected_index
  lda dsr_menu_item_values,y
  sta cfg_draft_config+Config::dsr
  rts

int_cmd_dtr:
  handle_menu_next dtr_menu
  ldy dtr_menu+Menu::selected_index
  lda dtr_menu_item_values,y
  sta cfg_draft_config+Config::dtr
  rts

int_cmd_rets:
  handle_menu_next rts_menu
  ldy rts_menu+Menu::selected_index
  lda rts_menu_item_values,y
  sta cfg_draft_config+Config::rets
  rts

int_cmd_translation:
  handle_menu_next trans_menu
  ldy trans_menu+Menu::selected_index
  lda trans_menu_item_values,y
  sta cfg_draft_config+Config::translation
  rts

int_cmd_mode:
  handle_menu_next mode_menu
  ldy mode_menu+Menu::selected_index
  lda mode_menu_item_values,y
  sta cfg_draft_config+Config::mode
  rts

int_cmd_protocol:
  handle_menu_next protocol_menu
  ldy protocol_menu+Menu::selected_index
  lda protocol_menu_item_values,y
  sta cfg_draft_config+Config::protocol
  rts

int_cmd_accept:
  lda #1
  sta cfg_config_done
  copy_struct_abs_to_abs cfg_draft_config, cfg_saved_config, Config
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
  cmp #$25
  beq @mode
  cmp #$32
  beq @protocol
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
@mode:
  jsr int_cmd_mode
  jmp @done
@protocol:
  jsr int_cmd_protocol
  jmp @done
@one:
  jsr int_cmd_preset_fastchar
  jmp @done
@two:
  jsr int_cmd_preset_fastline
  jmp @done
@three:
  jsr int_cmd_preset_vintage
  jmp @done
@four:
  jsr int_cmd_preset_APRS
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

baud_menu:                     .tag Menu
baud_menu_header:              .byte 'B'|$80,"aud",$00
baud_menu_item_values:
  .byte RS232_BAUD::B50
  .byte RS232_BAUD::B300
  .byte RS232_BAUD::B600
  .byte RS232_BAUD::B1200
  .byte RS232_BAUD::B2400
  .byte RS232_BAUD::B4800
  .byte RS232_BAUD::B9600
  .byte RS232_BAUD::B19200
baud_menu_item_values_end:
baud_menu_item_labels:
baud_menu_item_label_50:       .byte "50",$00
baud_menu_item_label_300:      .byte "300",$00
baud_menu_item_label_600:      .byte "600",$00
baud_menu_item_label_1200:     .byte "1200",$00
baud_menu_item_label_2400:     .byte "2400",$00
baud_menu_item_label_4800:     .byte "4800",$00
baud_menu_item_label_9600:     .byte "9600",$00
baud_menu_item_label_19200:    .byte "19200",$00

data_menu:                     .tag Menu
data_menu_header:              .byte 'D'|$80,"ata",$00
data_menu_item_values:
  .byte RS232_WORDSIZE::N5
  .byte RS232_WORDSIZE::N6
  .byte RS232_WORDSIZE::N7
  .byte RS232_WORDSIZE::N8
data_menu_item_values_end:
data_menu_item_labels:
data_menu_item_label_word5:    .byte "5 bit",$00
data_menu_item_label_word6:    .byte "6 bit",$00
data_menu_item_label_word7:    .byte "7 bit",$00
data_menu_item_label_word8:    .byte "8 bit",$00

stop_menu:                     .tag Menu
stop_menu_header:              .byte "St",'O'|$80,"p",$00
stop_menu_item_values:
  .byte RS232_STOPBITS::N1
  .byte RS232_STOPBITS::N2
stop_menu_item_values_end:
stop_menu_item_labels:
stop_menu_item_label_word1:    .byte "1 bit",$00
stop_menu_item_label_word2:    .byte "2 bit",$00

trans_menu:                    .tag Menu
trans_menu_header:             .byte "Trans",'L'|$80,"ation",$00
trans_menu_item_values:
  .byte RS232_TRANSLATION::NONE
  .byte RS232_TRANSLATION::LIGHT
  .byte RS232_TRANSLATION::HEAVY
trans_menu_item_values_end:
trans_menu_item_labels:
trans_menu_item_label_none:    .byte "None",$00
trans_menu_item_label_light:   .byte "Light",$00
trans_menu_item_label_heavy:   .byte "Heavy",$00

cts_menu:                      .tag Menu
cts_menu_header:               .byte 'C'|$80,"TS",$00
cts_menu_item_values:
  .byte RS232_CTS::OFF
  .byte RS232_CTS::ON
cts_menu_item_values_end:
cts_menu_item_labels:
cts_menu_item_label_off:       .byte "OFF",$00
cts_menu_item_label_on:        .byte "ON",$00

dsr_menu:                      .tag Menu
dsr_menu_header:               .byte "D",'S'|$80,"R",$00
dsr_menu_item_values:
  .byte RS232_DSR::OFF
  .byte RS232_DSR::ON
dsr_menu_item_values_end:
dsr_menu_item_labels:
dsr_menu_item_label_off:       .byte "OFF",$00
dsr_menu_item_label_on:        .byte "ON",$00

dtr_menu:                      .tag Menu
dtr_menu_header:               .byte "D",'T'|$80,"R",$00
dtr_menu_item_values:
  .byte RS232_DTR::NO_CHANGE
  .byte RS232_DTR::OFF
  .byte RS232_DTR::ON
dtr_menu_item_values_end:
dtr_menu_item_labels:
dtr_menu_item_label_no_chage:  .byte "N/C",$00
dtr_menu_item_label_off:       .byte "OFF",$00
dtr_menu_item_label_on:        .byte "ON",$00

rts_menu:                      .tag Menu
rts_menu_header:               .byte 'R'|$80,"TS",$00
rts_menu_item_values:
  .byte RS232_RTS::NO_CHANGE
  .byte RS232_RTS::OFF
  .byte RS232_RTS::ON
rts_menu_item_values_end:
rts_menu_item_labels:
rts_menu_item_label_no_change: .byte "N/C",$00
rts_menu_item_label_off:       .byte "OFF",$00
rts_menu_item_label_on:        .byte "ON",$00

duplex_menu:                   .tag Menu
duplex_menu_header:            .byte "D",'U'|$80,"plex",$00
duplex_menu_item_values:
  .byte RS232_DUPLEX::FULL
  .byte RS232_DUPLEX::HALF
duplex_menu_item_values_end:
duplex_menu_item_labels:
duplex_menu_item_label_full:   .byte "Full",$00
duplex_menu_item_label_half:   .byte "Half",$00

parity_menu:                   .tag Menu
parity_menu_header:            .byte 'P'|$80,"arity",$00
parity_menu_item_values:
  .byte RS232_PARITY::NONE
  .byte RS232_PARITY::EVEN
  .byte RS232_PARITY::ODD
parity_menu_item_values_end:
parity_menu_item_labels:
parity_menu_item_label0:       .byte "None",$00
parity_menu_item_label1:       .byte "Even",$00
parity_menu_item_label2:       .byte "Odd",$00

mode_menu:                     .tag Menu
mode_menu_header:              .byte 'M'|$80,"ode",$00
mode_menu_item_values:
  .byte TERMINAL_MODE::CHAR
  .byte TERMINAL_MODE::LINE
mode_menu_item_values_end:
mode_menu_item_labels:
mode_menu_item_label_char:     .byte "Char",$00
mode_menu_item_label_line:     .byte "Line",$00

protocol_menu:                 .tag Menu
protocol_menu_header:          .byte '0'|$80,"Protocol",$00
protocol_menu_item_values:
  .byte TERMINAL_PROTOCOL::TERMINAL
  .byte TERMINAL_PROTOCOL::APRS
  .byte TERMINAL_PROTOCOL::RTTY
protocol_menu_item_values_end:
protocol_menu_item_labels:
protocol_menu_item_label_term: .byte "Terminal",$00
protocol_menu_item_label_aprs: .byte "APRS",$00
protocol_menu_item_label_rtty: .byte "RTTY",$00

presets:                .byte "Presets:",$00
preset_fastchar:        .tag Preset
preset_fastchar_config: .tag Config
preset_fastchar_label:  .byte '1'|$80,"Fast Char",$00
preset_fastline:        .tag Preset
preset_fastline_config: .tag Config
preset_fastline_label:  .byte '2'|$80,"Fast Line",$00
preset_vintage:         .tag Preset
preset_vintage_config:  .tag Config
preset_vintage_label:   .byte '3'|$80,"Slow Char",$00
preset_APRS:            .tag Preset
preset_APRS_config:     .tag Config
preset_APRS_label:      .byte '4'|$80,"APRS",$00


top_banner:             .byte 'S'|$80,'E'|$80,'L'|$80,"theme "
                        .byte 'E'|$80,'S'|$80,'C'|$80,"revert "
                        .byte 'R'|$80,'E'|$80,'T'|$80,"terminal"
                        .byte $00
draw_menu_tempy:        .byte 0
draw_menu_border_width: .byte 0
draw_menu_end_column:   .byte 0
draw_menu_data_length:  .byte 0

menu_data_offset:       .byte 0
menu_item_index:        .byte 0
menu_item_value:        .byte 0
menu_item_num_items:    .byte 0
menu_item_border_width: .byte 0

highlight_border_width: .byte 0

cfg_draft_config:       .tag Config
cfg_saved_config:       .tag Config
cfg_config_done:        .byte 0
