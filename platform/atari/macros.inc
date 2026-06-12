.ifndef MACROS_INC
MACROS_INC = 1

.SEGMENT "CODE"

; compares 16 bit x to y, branches appropriately
.macro cmp16 _x, _y, branch_xlty, branch_xeqy, branch_xgty
  lda _x+1
  cmp _y+1
  bcc branch_xlty
  bne branch_xgty
  lda _x
  cmp _y
  bcc branch_xlty
  bne branch_xgty
  beq branch_xeqy
.endmacro

; stores the min of x and y in out
.macro min8 arg1, arg2, out
  .local done
  lda arg1
  cmp arg2
  bcc done
  lda arg2
done:
  sta out
.endmacro

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
