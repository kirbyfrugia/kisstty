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
.segment "ZEROPAGE"

.exportzp ZPB0, ZPB1, ZPB2, ZPB3, ZPB4, ZPB5
.exportzp CMDDATA0, CMDDATA1, CMDDATA2, CMDDATA3, CMDDATA4, CMDDATA5, CMDDATA6, CMDDATA7
.exportzp SCR_PTR_LO, SCR_PTR_HI
.exportzp TA_METADATA_PTR_LO, TA_METADATA_PTR_HI
.exportzp TA_CURSOR_SCR_ROW_PTR_LO, TA_CURSOR_SCR_ROW_PTR_HI
.exportzp TA_FIRST_ROW_DATA_PTR_LO, TA_FIRST_ROW_DATA_PTR_HI
.exportzp TA_LAST_ROW_DATA_PTR_LO, TA_LAST_ROW_DATA_PTR_HI
.exportzp TA_SCR_PTR_LO, TA_SCR_PTR_HI
.exportzp TA_FIRST_ROW_SCR_ROW_PTR_LO, TA_FIRST_ROW_SCR_ROW_PTR_HI
.exportzp TA_LAST_ROW_SCR_ROW_PTR_LO, TA_LAST_ROW_SCR_ROW_PTR_HI
.exportzp CFG_PTR_LO, CFG_PTR_HI
.exportzp CFG_SCR_PTR_LO, CFG_SCR_PTR_HI
.exportzp CFG_DATA_PTR_LO, CFG_DATA_PTR_HI

ZPB0:                        .res 1
ZPB1:                        .res 1
ZPB2:                        .res 1
ZPB3:                        .res 1
ZPB4:                        .res 1
ZPB5:                        .res 1
CMDDATA0:                    .res 1
CMDDATA1:                    .res 1
CMDDATA2:                    .res 1
CMDDATA3:                    .res 1
CMDDATA4:                    .res 1
CMDDATA5:                    .res 1
CMDDATA6:                    .res 1
CMDDATA7:                    .res 1
SCR_PTR_LO:                  .res 1
SCR_PTR_HI:                  .res 1
TA_METADATA_PTR_LO:          .res 1
TA_METADATA_PTR_HI:          .res 1
TA_CURSOR_SCR_ROW_PTR_LO:    .res 1
TA_CURSOR_SCR_ROW_PTR_HI:    .res 1
TA_FIRST_ROW_DATA_PTR_LO:    .res 1
TA_FIRST_ROW_DATA_PTR_HI:    .res 1
TA_LAST_ROW_DATA_PTR_LO:     .res 1
TA_LAST_ROW_DATA_PTR_HI:     .res 1
TA_SCR_PTR_LO:               .res 1
TA_SCR_PTR_HI:               .res 1
TA_FIRST_ROW_SCR_ROW_PTR_LO: .res 1
TA_FIRST_ROW_SCR_ROW_PTR_HI: .res 1
TA_LAST_ROW_SCR_ROW_PTR_LO:  .res 1
TA_LAST_ROW_SCR_ROW_PTR_HI:  .res 1
CFG_PTR_LO:                  .res 1
CFG_PTR_HI:                  .res 1
CFG_SCR_PTR_LO:              .res 1
CFG_SCR_PTR_HI:              .res 1
CFG_DATA_PTR_LO:             .res 1
CFG_DATA_PTR_HI:             .res 1

.SEGMENT "CODE"

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
