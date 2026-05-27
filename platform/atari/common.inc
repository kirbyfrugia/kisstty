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

CURSOR_FLAG_ENABLED               = %10000000
CURSOR_FLAG_DISABLED              = %00000000

CURSOR_BEHAVIOR_WRAP_CHANGE_LINES = %10000000
CURSOR_BEHAVIOR_WRAP_SAME_LINE    = %00000000

CMDDATA0                    = $cb
CMDDATA1                    = $cc
CMDDATA2                    = $cd
CMDDATA3                    = $ce
CMDDATA4                    = $cf
CMDDATA5                    = $d0
CMDDATA6                    = $d1
CMDDATA7                    = $d2
CMDDATA8                    = $d3
CMDDATA9                    = $d4
CMDDATAA                    = $d5
CMDDATAB                    = $d6
CMDDATAC                    = $d7
CMDDATAD                    = $d8
CMDDATAE                    = $d9
CMDDATAF                    = $da
SCR_PTR_LO                  = $db ; pointer to the mem location of the upper left of the screen
SCR_PTR_HI                  = $dc
TA_METADATA_PTR_LO          = $dd ; pointer to the currently loaded metadata in the text area control
TA_METADATA_PTR_HI          = $de
TA_CURSOR_SCR_ROW_PTR_LO    = $df ; pointer to the mem location of the cursor row in the currently loaded metadata in the text area control
TA_CURSOR_SCR_ROW_PTR_HI    = $e0
TA_FIRST_ROW_DATA_PTR_LO    = $e1 ; pointer to the data in the currently loaded metadata in the text area control
TA_FIRST_ROW_DATA_PTR_HI    = $e2
TA_LAST_ROW_DATA_PTR_LO     = $e3
TA_LAST_ROW_DATA_PTR_HI     = $e4
TA_SCR_PTR_LO               = $e5 ; pointer to the mem location of the upper left screen coords in the currently loaded metadata in the text area control
TA_SCR_PTR_HI               = $e6
TA_FIRST_ROW_SCR_ROW_PTR_LO = $e7 ; pointer to the mem location of the start of the last row of the screen
TA_FIRST_ROW_SCR_ROW_PTR_HI = $e8
TA_LAST_ROW_SCR_ROW_PTR_LO  = $e9 ; pointer to the mem location of the start of the last row of the screen
TA_LAST_ROW_SCR_ROW_PTR_HI  = $ea

; up through $fa are supposedly safe

.endif
