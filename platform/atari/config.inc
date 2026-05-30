.ifndef CONFIG_INC
CONFIG_INC = 1
.LINECONT +

.struct Config
  baud_rate   .byte
  translation .byte
  parity      .byte
  control     .byte
  stop_bits   .byte
.endstruct

.struct Menu
  scr_pos_ptr        .word
  header_ptr         .word
  menu_items_ptr     .word
  num_items          .byte
  border_width       .byte
  selected_item      .byte
.endstruct

.struct Preset
  scr_pos_ptr .word
  label_ptr   .word
  baud        .byte
  data_bits   .byte
  stop_bits   .byte
  parity      .byte
  duplex      .byte
  cts         .byte
  dsr         .byte
  dtr         .byte
  rts         .byte
  translation .byte
.endstruct

.macro make_menu menu, header, menu_items, n_items, b_width, scr_pos_offset
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

.macro make_preset preset, _label, _baud, _data_bits, \
                   _stop_bits, _parity, _duplex, _cts,\
                   _dsr, _dtr, _rts, _translation, scr_pos_offset
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

  lda #_baud
  sta preset+Preset::baud
  lda #_data_bits
  sta preset+Preset::data_bits
  lda #_stop_bits
  sta preset+Preset::stop_bits
  lda #_parity
  sta preset+Preset::parity
  lda #_duplex
  sta preset+Preset::duplex
  lda #_cts
  sta preset+Preset::cts
  lda #_dsr
  sta preset+Preset::dsr
  lda #_dtr
  sta preset+Preset::dtr
  lda #_rts
  sta preset+Preset::rts
  lda #_translation
  sta preset+Preset::translation
.endmacro

.macro draw_preset preset
  lda #<preset
  sta CFG_PTR_LO
  lda #>preset
  sta CFG_PTR_HI
  jsr int_draw_preset
.endmacro

.endif
