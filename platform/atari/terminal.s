.SETCPU "6502"

.INCLUDE "atari.inc" ; /usr/share/cc65/asminc/atari.inc
.INCLUDE "common.inc"
.INCLUDE "config.inc"
.INCLUDE "macros.inc"

.IMPORT g_kbd_key_pressed
.IMPORT g_kbdcode_raw
.IMPORT g_kbdcode_raw_stripped
.IMPORT g_kbdcode_atascii
.IMPORT utils_atascii_to_icode
.EXPORT tm_init
.EXPORT tm_activate
.EXPORT tm_tick

.SEGMENT "CODE"

tm_init:
  rts

tm_activate:
  rts

int_handle_kbd:
  rts

tm_tick:
  jsr int_handle_kbd
  rts
