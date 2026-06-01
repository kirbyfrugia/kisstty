.ifndef MACROS_INC
MACROS_INC = 1
.SEGMENT "CODE"

.macro copy_struct_abs_to_zp  abs_addr, zp_ptr, struct_type
  .local loop
  ldy #.sizeof(struct_type) - 1
loop:
  lda abs_addr,y
  sta (zp_ptr),y
  dey
  bpl loop
.endmacro

.macro copy_struct_zp_to_abs  zp_ptr, abs_addr, struct_type
  .local loop
  ldy #.sizeof(struct_type) - 1
loop:
  lda (zp_ptr),y
  sta abs_addr,y
  dey
  bpl loop
.endmacro

.macro copy_struct_abs_to_abs  src_addr, dst_addr, struct_type
  .local loop
  ldy #.sizeof(struct_type) - 1
loop:
  lda src_addr,y
  sta dst_addr,y
  dey
  bpl loop
.endmacro

; inverts a string on screen (bg/fg swap)
.macro invstr str
  .repeat .strlen(str), i
    .byte .strat(str, i) | $80
  .endrepeat
.endmacro

.endif
