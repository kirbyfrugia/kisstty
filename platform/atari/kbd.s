; Keycode to ATASCII lookup tables
; Index by keycode (0x00-0x3F) to get ATASCII value
; $00 = no mapping (null/undefined)
; Source: Atari OS User Manual Page 50

.SETCPU "6502"
.SEGMENT "CODE"

.EXPORT kbd_unmodified
.EXPORT kbd_shifted
.EXPORT kbd_ctrld


; $00 means you should ignore this key press

; neither shift nor ctrl pressed
kbd_unmodified:
  .byte $6C ; 00 L
  .byte $6A ; 01 J
  .byte $3B ; 02 ;
  .byte $00 ; 03 --
  .byte $00 ; 04 --
  .byte $6B ; 05 K
  .byte $2B ; 06 +
  .byte $2A ; 07 *
  .byte $6F ; 08 O
  .byte $00 ; 09 --
  .byte $70 ; 0A P
  .byte $75 ; 0B U
  .byte $9B ; 0C RET
  .byte $69 ; 0D I
  .byte $2D ; 0E -
  .byte $3D ; 0F =
  .byte $76 ; 10 V
  .byte $00 ; 11 --
  .byte $63 ; 12 C
  .byte $00 ; 13 --
  .byte $00 ; 14 --
  .byte $62 ; 15 B
  .byte $78 ; 16 X
  .byte $7A ; 17 Z
  .byte $34 ; 18 4
  .byte $00 ; 19 --
  .byte $33 ; 1A 3
  .byte $36 ; 1B 6
  .byte $1B ; 1C ESC
  .byte $35 ; 1D 5
  .byte $32 ; 1E 2
  .byte $31 ; 1F 1
  .byte $2C ; 20 ,
  .byte $20 ; 21 SPACE
  .byte $2E ; 22 .
  .byte $6E ; 23 N
  .byte $00 ; 24 --
  .byte $6D ; 25 M
  .byte $2F ; 26 /
  .byte $00 ; 27 )|(
  .byte $72 ; 28 R
  .byte $00 ; 29 --
  .byte $65 ; 2A E
  .byte $79 ; 2B Y
  .byte $7F ; 2C TAB
  .byte $74 ; 2D T
  .byte $77 ; 2E W
  .byte $71 ; 2F Q
  .byte $39 ; 30 9
  .byte $00 ; 31 --
  .byte $30 ; 32 0
  .byte $37 ; 33 7
  .byte $7E ; 34 BACKSPACE
  .byte $38 ; 35 8
  .byte $3C ; 36 <
  .byte $3E ; 37 >
  .byte $66 ; 38 F
  .byte $68 ; 39 H
  .byte $64 ; 3A D
  .byte $00 ; 3B --
  .byte $00 ; 3C CAPS
  .byte $67 ; 3D G
  .byte $73 ; 3E S
  .byte $61 ; 3F A

; shift pressed
kbd_shifted:
  .byte $4C ; 00 L
  .byte $4A ; 01 J
  .byte $3A ; 02 ;
  .byte $00 ; 03 --
  .byte $00 ; 04 --
  .byte $4B ; 05 K
  .byte $5C ; 06 +
  .byte $5E ; 07 *
  .byte $4F ; 08 O
  .byte $00 ; 09 --
  .byte $50 ; 0A P
  .byte $55 ; 0B U
  .byte $9B ; 0C RET
  .byte $49 ; 0D I
  .byte $5F ; 0E -
  .byte $7C ; 0F =
  .byte $56 ; 10 V
  .byte $00 ; 11 --
  .byte $43 ; 12 C
  .byte $00 ; 13 --
  .byte $00 ; 14 --
  .byte $42 ; 15 B
  .byte $58 ; 16 X
  .byte $5A ; 17 Z
  .byte $24 ; 18 4
  .byte $00 ; 19 --
  .byte $23 ; 1A 3
  .byte $26 ; 1B 6
  .byte $1B ; 1C ESC
  .byte $25 ; 1D 5
  .byte $22 ; 1E 2
  .byte $21 ; 1F 1
  .byte $5B ; 20 ,
  .byte $20 ; 21 SPACE
  .byte $5D ; 22 .
  .byte $4E ; 23 N
  .byte $00 ; 24 --
  .byte $4D ; 25 M
  .byte $3F ; 26 /
  .byte $00 ; 27 )|(
  .byte $52 ; 28 R
  .byte $00 ; 29 --
  .byte $45 ; 2A E
  .byte $59 ; 2B Y
  .byte $9F ; 2C TAB
  .byte $54 ; 2D T
  .byte $57 ; 2E W
  .byte $51 ; 2F Q
  .byte $28 ; 30 9
  .byte $00 ; 31 --
  .byte $29 ; 32 0
  .byte $27 ; 33 7
  .byte $9C ; 34 BACKSPACE
  .byte $40 ; 35 8
  .byte $7D ; 36 <
  .byte $9D ; 37 >
  .byte $46 ; 38 F
  .byte $48 ; 39 H
  .byte $44 ; 3A D
  .byte $00 ; 3B --
  .byte $00 ; 3C CAPS
  .byte $47 ; 3D G
  .byte $53 ; 3E S
  .byte $41 ; 3F A

; ctrl pressed
kbd_ctrld:
  .byte $0C ; 00 L
  .byte $0A ; 01 J
  .byte $7B ; 02 ;
  .byte $00 ; 03 --
  .byte $00 ; 04 --
  .byte $0B ; 05 K
  .byte $1E ; 06 +
  .byte $1F ; 07 *
  .byte $0F ; 08 O
  .byte $00 ; 09 --
  .byte $10 ; 0A P
  .byte $15 ; 0B U
  .byte $9B ; 0C RET
  .byte $09 ; 0D I
  .byte $1C ; 0E -
  .byte $1D ; 0F =
  .byte $16 ; 10 V
  .byte $00 ; 11 --
  .byte $03 ; 12 C
  .byte $00 ; 13 --
  .byte $00 ; 14 --
  .byte $02 ; 15 B
  .byte $18 ; 16 X
  .byte $1A ; 17 Z
  .byte $00 ; 18 4
  .byte $00 ; 19 --
  .byte $9B ; 1A 3 (EOF)
  .byte $00 ; 1B 6
  .byte $1B ; 1C ESC
  .byte $00 ; 1D 5
  .byte $FD ; 1E 2
  .byte $00 ; 1F 1
  .byte $00 ; 20 ,
  .byte $20 ; 21 SPACE
  .byte $60 ; 22 .
  .byte $0E ; 23 N
  .byte $00 ; 24 --
  .byte $0D ; 25 M
  .byte $00 ; 26 /
  .byte $00 ; 27 )|(
  .byte $12 ; 28 R
  .byte $00 ; 29 --
  .byte $05 ; 2A E
  .byte $19 ; 2B Y
  .byte $9E ; 2C TAB
  .byte $14 ; 2D T
  .byte $17 ; 2E W
  .byte $11 ; 2F Q
  .byte $00 ; 30 9
  .byte $00 ; 31 --
  .byte $00 ; 32 0
  .byte $00 ; 33 7
  .byte $FE ; 34 BACKSPACE
  .byte $00 ; 35 8
  .byte $7D ; 36 <
  .byte $FF ; 37 >
  .byte $06 ; 38 F
  .byte $08 ; 39 H
  .byte $04 ; 3A D
  .byte $00 ; 3B --
  .byte $00 ; 3C CAPS
  .byte $07 ; 3D G
  .byte $13 ; 3E S
  .byte $01 ; 3F A
