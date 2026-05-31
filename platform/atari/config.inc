.ifndef CONFIG_INC
CONFIG_INC = 1
.LINECONT +

.struct Menu
  scr_pos_ptr          .word
  header_ptr           .word
  items_values_ptr     .word
  items_labels_ptr     .word
  num_items            .byte
  border_width         .byte
  selected_index       .byte
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
  rets        .byte
  translation .byte
.endstruct

.struct Preset
  scr_pos_ptr .word
  label_ptr   .word
  config_ptr  .word
.endstruct

.macro make_menu menu, header, _items_values, _items_labels, n_items, b_width, scr_pos_offset
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

  lda #n_items
  sta menu+Menu::num_items
  lda #b_width
  sta menu+Menu::border_width

  lda #<_items_values
  sta menu+Menu::items_values_ptr
  lda #>_items_values
  sta menu+Menu::items_values_ptr+1

  lda #<_items_labels
  sta menu+Menu::items_labels_ptr
  lda #>_items_labels
  sta menu+Menu::items_labels_ptr+1

.endmacro

.macro refresh_menu menu, _init_value
  lda #<menu
  sta CFG_PTR_LO
  lda #>menu
  sta CFG_PTR_HI
  lda _init_value
  sta menu_item_value
  jsr int_refresh_menu
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

.macro handle_menu_next _menu
  lda #<_menu
  sta CFG_PTR_LO
  lda #>_menu
  sta CFG_PTR_HI
  jsr int_select_next_menu_item
.endmacro

.endif
