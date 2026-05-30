.ifndef CONFIG_INC
CONFIG_INC = 1

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
  sta CFG_MENU_PTR_LO
  lda #>menu
  sta CFG_MENU_PTR_HI
  jsr int_draw_menu
.endmacro

.endif
