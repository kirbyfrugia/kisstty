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
  pos_ptr            .word
  menu_and_items_ptr .word
  num_items          .byte
  width              .byte
  selected_item      .byte
.endstruct

.macro draw_menu menu
  lda menu+Menu::pos_ptr
  sta CMDDATA0
  lda menu+Menu::pos_ptr+1
  sta CMDDATA1
  lda menu+Menu::menu_and_items_ptr
  sta CMDDATA2
  lda menu+Menu::menu_and_items_ptr+1
  sta CMDDATA3
  lda menu+Menu::num_items
  clc
  adc #2 ; header + border rows
  sta CMDDATA4
  lda menu+Menu::width
  sta CMDDATA5
  lda menu+Menu::width
  clc
  adc #2
  sta CMDDATA6
  jsr int_draw_menu_border

  ; menu items
  lda menu+Menu::pos_ptr
  clc
  adc #(SCREEN_WIDTH)
  adc #1
  sta CMDDATA0
  lda menu+Menu::pos_ptr+1
  adc #0
  sta CMDDATA1
  lda menu+Menu::menu_and_items_ptr
  clc
  adc menu+Menu::width
  sta CMDDATA2
  lda menu+Menu::menu_and_items_ptr+1
  adc #0
  sta CMDDATA3
  lda menu+Menu::num_items
  sta CMDDATA4
  lda menu+Menu::width
  sta CMDDATA5
  jsr int_draw_menu_items

.endmacro

.endif
