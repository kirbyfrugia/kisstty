.SETCPU "6502"

.EXPORT copy_buffer40 
.EXPORT copy_buffer40_size

.EXPORT g_kbd_key_pressed
.EXPORT g_kbdcode_raw
.EXPORT g_kbdcode_raw_stripped
.EXPORT g_kbdcode_atascii

.exportzp ZPB0, ZPB1, ZPB2, ZPB3, ZPB4, ZPB5
.exportzp CMDDATA0, CMDDATA1, CMDDATA2, CMDDATA3, CMDDATA4, CMDDATA5, CMDDATA6, CMDDATA7
.exportzp SCR_PTR_LO, SCR_PTR_HI

.SEGMENT "ZEROPAGE"
ZPB0:                        .byte $00
ZPB1:                        .byte $00
ZPB2:                        .byte $00
ZPB3:                        .byte $00
ZPB4:                        .byte $00
ZPB5:                        .byte $00
CMDDATA0:                    .byte $00
CMDDATA1:                    .byte $00
CMDDATA2:                    .byte $00
CMDDATA3:                    .byte $00
CMDDATA4:                    .byte $00
CMDDATA5:                    .byte $00
CMDDATA6:                    .byte $00
CMDDATA7:                    .byte $00
SCR_PTR_LO:                  .byte $00
SCR_PTR_HI:                  .byte $00

.SEGMENT "CODE"
copy_buffer40:          .res 40
copy_buffer40_size:     .res 1
g_kbd_key_pressed:      .res 1 ; nonzero if pressed
g_kbdcode_raw:          .res 1 ; raw keyboard code currently pressed
g_kbdcode_raw_stripped: .res 1 ; raw minus ctrl bits
g_kbdcode_atascii:      .res 1 ; keyboard code in atascii
