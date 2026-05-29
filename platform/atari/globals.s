.SETCPU "6502"
.SEGMENT "CODE"

.EXPORT copy_buffer40 
.EXPORT copy_buffer40_size
.EXPORT copy_buffer240 
.EXPORT copy_buffer240_size
.EXPORT discard_buffer240 
.EXPORT discard_buffer240_size

.EXPORT g_kbd_key_pressed
.EXPORT g_kbdcode_raw
.EXPORT g_kbdcode_raw_stripped
.EXPORT g_kbdcode_atascii

copy_buffer40:      .res 40
copy_buffer40_size: .byte 0
copy_buffer240:      .res 40
copy_buffer240_size: .byte 0
discard_buffer240:      .res 40
discard_buffer240_size: .byte 0

; these are currently pressed keys by the user
g_kbd_key_pressed:      .byte 0 ; nonzero if pressed
g_kbdcode_raw:          .byte 0 ; raw keyboard code currently pressed
g_kbdcode_raw_stripped: .byte 0 ; raw minus ctrl bits
g_kbdcode_atascii:      .byte 0 ; keyboard code in atascii
