.ifndef COMMON_INC
COMMON_INC = 1
SCREEN_WIDTH  = 40
SCREEN_HEIGHT = 24

.define CURSOR_FLAG_WRAP_SAME_LINE        %10000000
.define CURSOR_FLAG_WRAP_DIFF_LINE        %00000000
.define CURSOR_FLAG_ENABLED               %10000000
.define CURSOR_FLAG_DISABLED              %00000000
.define CURSOR_BEHAVIOR_WRAP_CHANGE_LINES %10000000
.define CURSOR_BEHAVIOR_WRAP_SAME_LINE    %00000000

ZPB0                        = $82
ZPB1                        = $83
ZPB2                        = $84
ZPB3                        = $85
ZPB4                        = $86
ZPB5                        = $87
CMDDATA0                    = $88
CMDDATA1                    = $89
CMDDATA2                    = $8a
CMDDATA3                    = $8b
CMDDATA4                    = $8c
CMDDATA5                    = $8d
CMDDATA6                    = $8e
CMDDATA7                    = $8f
SCR_PTR_LO                  = $90 ; pointer to the mem location of the upper left of the screen
SCR_PTR_HI                  = $91
TA_METADATA_PTR_LO          = $92 ; pointer to the currently loaded metadata in the text area control
TA_METADATA_PTR_HI          = $93
TA_CURSOR_SCR_ROW_PTR_LO    = $94 ; pointer to the mem location of the cursor row in the currently loaded metadata in the text area control
TA_CURSOR_SCR_ROW_PTR_HI    = $95
TA_FIRST_ROW_DATA_PTR_LO    = $96 ; pointer to the data in the currently loaded metadata in the text area control
TA_FIRST_ROW_DATA_PTR_HI    = $97
TA_LAST_ROW_DATA_PTR_LO     = $98
TA_LAST_ROW_DATA_PTR_HI     = $99
TA_SCR_PTR_LO               = $9a ; pointer to the mem location of the upper left screen coords in the currently loaded metadata in the text area control
TA_SCR_PTR_HI               = $9b
TA_FIRST_ROW_SCR_ROW_PTR_LO = $9c ; pointer to the mem location of the start of the last row of the screen
TA_FIRST_ROW_SCR_ROW_PTR_HI = $9d
TA_LAST_ROW_SCR_ROW_PTR_LO  = $9e ; pointer to the mem location of the start of the last row of the screen
TA_LAST_ROW_SCR_ROW_PTR_HI  = $9f
CFG_PTR_LO                  = $a0
CFG_PTR_HI                  = $a1
CFG_SCR_PTR_LO              = $a2
CFG_SCR_PTR_HI              = $a3
CFG_DATA_PTR_LO             = $a4
CFG_DATA_PTR_HI             = $a5

; wozmon uses $CB-FA

.endif
