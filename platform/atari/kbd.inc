; Keycode to ATASCII lookup tables
; Index by keycode (0x00-0x3F) to get ATASCII value
; $00 = no mapping (null/undefined)
; Source: Atari OS User Manual Page 50

.ifndef KBD_INC
KBD_INC = 1

.global kbd_unmodified
.global kbd_shifted
.global kbd_ctrld

.endif
