.ifndef CONFIG_INC
CONFIG_INC = 1
.LINECONT +

.define CFG_MENU_BAUD_50    0
.define CFG_MENU_BAUD_300   1
.define CFG_MENU_BAUD_600   2
.define CFG_MENU_BAUD_1200  3
.define CFG_MENU_BAUD_2400  4
.define CFG_MENU_BAUD_4800  5
.define CFG_MENU_BAUD_9600  6
.define CFG_MENU_BAUD_19200 7

.define CFG_MENU_DATA_5BIT 0
.define CFG_MENU_DATA_6BIT 1
.define CFG_MENU_DATA_7BIT 2
.define CFG_MENU_DATA_8BIT 3

.define CFG_MENU_STOP_1BIT 0
.define CFG_MENU_STOP_2BIT 1

.define CFG_MENU_TRANS_NONE  0
.define CFG_MENU_TRANS_LIGHT 1
.define CFG_MENU_TRANS_HEAVY 2

.define CFG_MENU_CTS_OFF 0
.define CFG_MENU_CTS_ON  1

.define CFG_MENU_DSR_OFF 0
.define CFG_MENU_DSR_ON  1

.define CFG_MENU_DTR_OFF 0
.define CFG_MENU_DTR_ON  1

.define CFG_MENU_RTS_OFF 0
.define CFG_MENU_RTS_ON  1

.define CFG_MENU_DUPLEX_FULL 0
.define CFG_MENU_DUPLEX_HALF 1

.define CFG_MENU_PARITY_NONE 0
.define CFG_MENU_PARITY_EVEN 1
.define CFG_MENU_PARITY_ODD  2
.define CFG_MENU_PARITY_ONE  3

.define CFG_MENU_MODE_CHARACTER 0
.define CFG_MENU_MODE_LINE      1

.define CFG_MENU_PROTOCOL_TERM 0
.define CFG_MENU_PROTOCOL_APRS 1

.struct Menu
  scr_pos_ptr        .word
  header_ptr         .word
  menu_items_ptr     .word
  num_items          .byte
  border_width       .byte
  config_index       .byte
.endstruct

.struct Config
  protocol    .byte
  mode        .byte
  baud        .byte
  data_bits   .byte
  stop_bits   .byte
  parity      .byte
  duplex      .byte
  cts         .byte
  dsr         .byte
  dtr         .byte
  rets        .byte ; rts is rts, so oops
  translation .byte
.endstruct

.struct Preset
  scr_pos_ptr .word
  label_ptr   .word
  config_ptr  .word
.endstruct

.macro make_menu menu, header, menu_items, c_index, n_items, b_width, scr_pos_offset
  lda #<scr_pos_offset
  clc
  adc SCR_PTR_LO
  sta menu+Menu::scr_pos_ptr
  lda #>scr_pos_offset
  adc SCR_PTR_HI
  sta menu+Menu::scr_pos_ptr+1

  lda #<header
  sta menu+Menu::header_ptr
  lda #>header
  sta menu+Menu::header_ptr+1

  lda #<menu_items
  sta menu+Menu::menu_items_ptr
  lda #>menu_items
  sta menu+Menu::menu_items_ptr+1

  lda #c_index
  sta menu+Menu::config_index
  lda #n_items
  sta menu+Menu::num_items
  lda #b_width
  sta menu+Menu::border_width
.endmacro

.macro draw_menu menu
  lda #<menu
  sta CFG_PTR_LO
  lda #>menu
  sta CFG_PTR_HI
  jsr int_draw_menu
.endmacro

.macro highlight_selected menu
  lda #<menu
  sta CFG_PTR_LO
  lda #>menu
  sta CFG_PTR_HI
  jsr int_highlight_selected_menu_item
.endmacro

.macro make_config  config, _protocol, _mode, _baud, _data_bits, \
                   _stop_bits, _parity, _duplex, _cts,\
                   _dsr, _dtr, _rets, _translation
  lda #_protocol
  sta config+Config::protocol
  lda #_mode
  sta config+Config::mode
  lda #_baud
  sta config+Config::baud
  lda #_data_bits
  sta config+Config::data_bits
  lda #_stop_bits
  sta config+Config::stop_bits
  lda #_parity
  sta config+Config::parity
  lda #_duplex
  sta config+Config::duplex
  lda #_cts
  sta config+Config::cts
  lda #_dsr
  sta config+Config::dsr
  lda #_dtr
  sta config+Config::dtr
  lda #_rets
  sta config+Config::rets
  lda #_translation
  sta config+Config::translation
.endmacro

.macro make_preset preset, config, _label, scr_pos_offset
  lda #<scr_pos_offset
  clc
  adc SCR_PTR_LO
  sta preset+Preset::scr_pos_ptr
  lda #>scr_pos_offset
  adc SCR_PTR_HI
  sta preset+Preset::scr_pos_ptr+1

  lda #<_label
  sta preset+Preset::label_ptr
  lda #>_label
  sta preset+Preset::label_ptr+1

  lda #<config
  sta preset+Preset::config_ptr
  lda #>config
  sta preset+Preset::config_ptr+1
.endmacro

.macro draw_preset preset
  lda #<preset
  sta CFG_PTR_LO
  lda #>preset
  sta CFG_PTR_HI
  jsr int_draw_preset
.endmacro

.macro handle_menu_next _menu, _config
  inc _config
  lda _config
  cmp _menu+Menu::num_items
  bcc @selected
  lda #0
  sta _config
@selected:
  highlight_selected _menu
.endmacro

.endif
