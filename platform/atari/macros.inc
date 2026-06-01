.ifndef MACROS_INC
.define MACROS_INC 1

.SEGMENT "CODE"

.macro copy_struct_abs_to_zp src_addr, dest_zp_ptr, struct_type
  .local loop
  ldy #.sizeof(struct_type) - 1
loop:
  lda src_addr,y
  sta (dest_zp_ptr),y
  dey
  bpl loop
.endmacro

.macro copy_struct_zp_to_abs src_zp_ptr, dest_addr, struct_type
  .local loop
  ldy #.sizeof(struct_type) - 1
loop:
  lda (src_zp_ptr),y
  sta dest_addr,y
  dey
  bpl loop
.endmacro

.macro copy_struct_abs_to_abs src_addr, dest_addr, struct_type
  .local loop
  ldy #.sizeof(struct_type) - 1
loop:
  lda src_addr,y
  sta dest_addr,y
  dey
  bpl loop
.endmacro

.macro copy_struct_zp_to_zp src_zp_ptr, dest_zp_ptr, struct_type
  .local loop
  ldy #.sizeof(struct_type) - 1
loop:
  lda (src_zp_ptr),y
  sta (dest_zp_ptr),y
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
