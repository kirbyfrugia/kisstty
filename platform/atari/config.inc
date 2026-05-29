.ifndef CONFIG_INC
CONFIG_INC = 1

.struct Menu
  scr_ptr     .word
  heading_ptr .word
  items_ptr   .word
  num_items   .byte
  width       .byte
.endstruct

.endif
