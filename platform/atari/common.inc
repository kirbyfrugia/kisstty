.ifndef COMMON_INC
COMMON_INC = 1
SCREEN_WIDTH  = 40
SCREEN_HEIGHT = 24

ZPB0 = $80
ZPB1 = $81
ZPB2 = $82
ZPB3 = $83
ZPB4 = $84
ZPB5 = $85
ZPB6 = $86

UTILS_TMP1 = $87
UTILS_TMP2 = $88
UTILS_TMP3 = $89
UTILS_TMP4 = $8a
UTILS_TMP5 = $8b

.define CURSOR_FLAG_WRAP_SAME_LINE %10000000
.define CURSOR_FLAG_WRAP_DIFF_LINE %00000000

CURSOR_POSX          = $92 ;         - x position of cursor relative to screen upper left
CURSOR_POSY          = $93 ;         - y position of cursor relative to screen upper left
CURSOR_POS_SCR       = $94 ; and $95 - absolute memory location of cursor position
CURSOR_SOL_PTR       = $96 ; and $97 - pointer to start of line (current cursor line)
INPUT_UPPER_LEFT_PTR = $98 ; and $99 - pointer to uper left char in input area

; BIT 7 - show/hide - 1 if show, 0 if hide
CURSOR_FLAG_ENABLE                = %10000000
CURSOR_FLAG_DISABLE               = %00000000
CURSOR_BEHAVIOR_WRAP_CHANGE_LINES = %10000000
CURSOR_BEHAVIOR_WRAP_SAME_LINE    = %00000000

CMDDATA0             = $9b
CMDDATA1             = $9c
CMDDATA2             = $9d
CMDDATA3             = $9e
CMDDATA4             = $9f
CMDDATA5             = $a0
CMDDATA6             = $a1
CMDDATA7             = $a2
CMDDATA8             = $a3
CMDDATA9             = $a4
CMDDATAA             = $a5
CMDDATAB             = $a6
CMDDATAC             = $a7
CMDDATAD             = $a8
CMDDATAE             = $a9
CMDDATAF             = $aa
SCR_PTR_LO           = $ab ; pointer to the upper left of the screen
SCR_PTR_HI           = $ac
TI_METADATA_PTR_LO   = $ad ; pointer to the currently loaded metadata in the text input control
TI_METADATA_PTR_HI   = $ae
TI_SCR_ROW_PTR_LO    = $af ; pointer to the cursor row in the currently loaded metadata in the text input control
TI_SCR_ROW_PTR_HI    = $b0
TI_DATA_PTR_LO       = $b1 ; pointer to the data in the currently loaded metadata in the text input control
TI_DATA_PTR_HI       = $b2
TI_SCR_PTR_LO        = $b3 ; pointer to the upper left screen coords in the currently loaded metadata in the text input control
TI_SCR_PTR_HI        = $b4

.endif
