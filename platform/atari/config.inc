.ifndef CONFIG_INC
CONFIG_INC = 1

.struct Menu
  heading_row_ptr    .word
  menu_and_items_ptr .word
  num_items          .byte
  width              .byte
.endstruct

.macro draw_menu menu
  lda menu+Menu::heading_row_ptr
  sta CMDDATA0
  lda menu+Menu::heading_row_ptr+1
  sta CMDDATA1
  lda menu+Menu::menu_and_items_ptr
  sta CMDDATA2
  lda menu+Menu::menu_and_items_ptr+1
  sta CMDDATA3
  lda menu+Menu::num_items
  sta CMDDATA4
  lda menu+Menu::width
  sta CMDDATA5
  jsr int_draw_single_menu

.endmacro

.endif
