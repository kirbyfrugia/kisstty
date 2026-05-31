.ifndef CONFIG_INC
CONFIG_INC = 1
.LINECONT +

.struct Menu
  scr_pos_ptr        .word
  header_ptr         .word
  menu_items_ptr     .word
  num_items          .byte
  border_width       .byte
  config_index       .byte
.endstruct

.struct Config
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

.macro make_config  config, _baud, _data_bits, \
                   _stop_bits, _parity, _duplex, _cts,\
                   _dsr, _dtr, _rets, _translation
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
