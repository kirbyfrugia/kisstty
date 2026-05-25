.ifndef MACROS_INC
MACROS_INC = 1

.macro copy_struct_abs_to_zp  abs_addr, zp_ptr, struct_type
  ldy #.sizeof(struct_type) - 1
@abs_to_zp_loop:
  lda abs_addr,y
  sta (zp_ptr),y
  dey
  bpl @abs_to_zp_loop
.endmacro

.macro copy_struct_zp_to_abs  zp_ptr, abs_addr, struct_type
  ldy #.sizeof(struct_type) - 1
@zp_to_abs_loop:
  lda (zp_ptr),y
  sta abs_addr,y
  dey
  bpl @zp_to_abs_loop
.endmacro

; inverts a string on screen (bg/fg swap)
.macro invstr str
  .repeat .strlen(str), i
    .byte .strat(str, i) | $80
  .endrepeat
.endmacro

.endif
