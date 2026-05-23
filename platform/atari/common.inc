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
CURSOR_FLAGS         = $9a
