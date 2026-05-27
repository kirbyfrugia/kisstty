; WozMon for Atari 8-bit, ca65 port for kiss6502
;
; Original: The WOZ Monitor for the Apple 1, Steve Wozniak, 1976
; Atari port: Frederik Holst, 2022/23, ABBUC Software Contest 2023
;   https://github.com/fredlcore/AtariWozMon
; ca65/kiss6502 port: adapted from above, MIT licensed portions only
;
; Segments:
;   WOZMON_SPLASH  -> $0400 (cassette buffer, clobbered later, that's fine)
;   WOZMON_SPLASH2 -> $04B0
;   WOZMON_CODE    -> $9800
;
; Entry point: wozmon_main (exported)
; runad should point to wozmon_main in debug linker config.
;
; Usage:
;
; After start you can simply enter a hexadecimal address and get its value returned:
; e.g.
; 600
; 0600: D8
;
; Several locations can be entered with a space in between:
; 600 604 60B
; 0600: D8
; 0604: 01
; 060B: A9
;
; Entering a dot followed by an address will return all memory addresses in between the last address and the address entered:
; .60F
;  05 9D 42 03
;
; A range can also be entered:
; 600.60F
; 0600: D8 A5 06 F0 01 68 A9 9B
; 0608: 20 DD 06 A9 05 9D 42 03
;
; Memory values can be written using a colon:
; A800:A0
; A800: 00
; Take note that the returned value is the value before writing. You can confirm the written value by reading it again:
; A800
; A800: A0
;
; Several bytes can be written by adding them with a space inbetween:
; A800:A9 03 8D 00 A9
; A800: A0
; Only the first (previous) value is returned. Confirm again by querying the range:
; A800.A807
; A800: A9 03 8D 00 A9 00 00 00
;
; Jump to a memory location and execute from there (no return):
; 179FR
;
; Exit WozMon (jmp to main app at $4000):
; X
.ifdef DEBUG
.SETCPU "6502"
.INCLUDE "atari.inc"
.INCLUDE "macros.inc"

.IMPORT start

; ---------------------------------------------------------------------------
; Zero page — Atari BASIC ZP area $CB-$FA, safe to use outside BASIC
; ---------------------------------------------------------------------------

XAML    = $CB           ; last "opened" location Low
XAMH    = $CC           ; last "opened" location High
STL     = $CD           ; store address Low
STH     = $CE           ; store address High
L       = $CF           ; hex value parsing LSD (Least Significant Digit, low byte)
H       = $D0           ; hex value parsing MSB (Most Significant Digit, high byte)
YSAV    = $D1           ; used to see if hex value is given
MODE    = $D4           ; $00=XAM, $74=STOR, $AE=BLOCK XAM
OUTBUF  = $D5           ; output buffer (1 byte)
WOZIN   = $D6           ; input buffer (until $FA) — renamed from IN to avoid atari.inc collision

CMD_GETREC  = $05
CMD_PUTCHAR = $0B       ; put character command

; ---------------------------------------------------------------------------
; Macro: emit inverse-video ATASCII string (sets bit 7 on each character)
; Equivalent to XASM .sb+128
; ---------------------------------------------------------------------------



; ---------------------------------------------------------------------------
; Splash screen — cassette buffer $0400, clobbered later, that's fine
; This part can be removed; mainly added to satisfy ABBUC software competition rules.
; ---------------------------------------------------------------------------

.SEGMENT "WOZMON_SPLASH"

wozmon_splash:
  pla                           ; if called from BASIC, pull parameter count from stack
  ldy #0                        ; message text counter
@nextchr:
  lda wozmon_msg1,Y             ; get character
  jsr wozmon_echo               ; use CIOV routine to output
  iny                           ; next character
  cpy #(wozmon_msg1_end - wozmon_msg1) ; are we there yet?
  bne @nextchr                  ; no!

  ldy #0                        ; message text counter
@nextchr2:
  lda wozmon_msg2,Y             ; get character
  jsr wozmon_echo               ; use CIOV routine to output
  iny                           ; next character
  cpy #(wozmon_msg2_end - wozmon_msg2) ; are we there yet?
  bne @nextchr2                 ; no!

  jmp wozmon_main               ; run the actual program

wozmon_msg1:
  .byte $9b
  .byte "WOZMON BY STEVE WOZNIAK 1976", $9b
  .byte "ATARI PORT BY FREDERIK HOLST", $9b
  .byte "THIS PORT BY KIRBY FRUGIA", $9b
  .byte "FOR ASC 2023", $9b, $9b
wozmon_msg1_end:

; ---------------------------------------------------------------------------
; Second splash block — $04B0, still in cassette buffer
; ---------------------------------------------------------------------------

.SEGMENT "WOZMON_SPLASH2"

wozmon_msg2:
  .byte "COMMANDS:", $9b
  invstr "A.B"
  .byte " DUMP FROM A TO B", $9b
  invstr "A:B"
  .byte $9b
  .byte " WRITE B TO ADDRESS A", $9b
  invstr "AR"
  .byte " RUN FROM ADDRESS A", $9b
  invstr "X"
  .byte " EXIT", $9b, $9b
  .byte "TO RUN WOZMON AGAIN LATER,", $9b
  .byte "JUMP TO $9800:", $9b
  .byte "DOS: G 9800", $9b, $9b
wozmon_msg2_end:

; ---------------------------------------------------------------------------
; Monitor core — $9800
; ---------------------------------------------------------------------------

.SEGMENT "WOZMON_CODE"

.EXPORT wozmon_main

wozmon_main:
  ; restore the screen editor
  ldx #$00
  lda #$03
  sta ICCOM,X
  lda #<editor_name
  sta ICBAL,X
  lda #>editor_name
  sta ICBAH,X
  lda #$0C
  sta ICAX1,X
  lda #$00
  sta ICAX2,X
  jsr CIOV

  cli                           ; re-enable IRQs so that we can have brk work
  cld                           ; clear decimal arithmetic mode
  lda #'\'
  jsr wozmon_echo

wozmon_getline:
  lda #$9b                      ; output ATASCII newline
  jsr wozmon_echo

; get line from keyboard
  lda #CMD_GETREC               ; 'get record' command
  sta ICCOM,X
  lda #<WOZIN                   ; input buffer WOZIN (low)
  sta ICBAL,X
  lda #>WOZIN                   ; input buffer WOZIN (high)
  sta ICBAH,X
  lda #36                       ; max. 36 characters in "safe" BASIC zero page
  sta ICBLL,X
; ICBLH is still zero from echo subroutine
  jsr CIOV                      ; execute

  ldy #$FF                      ; reset text index
  lda #0                        ; for XAM mode
  tax                           ; 0 -> X

wozmon_setstor:
  asl                           ; converts $BA (colon, i.e. STOR mode) to $74 if setting STOR mode, so bit 7 is clear and can be differentiated from $AE (dot, i.e. BLOCK XAM mode) in the later BIT test
wozmon_setmode:
  sta MODE                      ; $00=XAM (examine single memory location, i.e. no other command was entered) $74=STOR (store value in memory, i.e. colon was entered) $AE=BLOK XAM (examine block of memory, i.e. dot was entered)
wozmon_blkskip:
  iny                           ; advance text index
wozmon_nextitem:
  lda WOZIN,Y                   ; get character
  ora #$80                      ; add bit 7 which is always set on Apple 1 characters, necessary to perform BIT test later on
  cmp #$9b                      ; ATASCII CR?
  beq wozmon_getline            ; yes, line done
  cmp #'.'+$80                  ; dot?
  bcc wozmon_blkskip            ; less than "."? Must be space, so skip this delimiter (actually, all characters less than "." count as a delimiter)
  beq wozmon_setmode            ; it's a dot, so set STOR mode
  cmp #':'+$80                  ; colon?
  beq wozmon_setstor            ; yes, set STOR mode
  cmp #'R'+$80                  ; R?
  beq wozmon_run                ; run user program
  cmp #'X'+$80                  ; X?
  bne wozmon_cont               ; no, then continue
  jmp start

wozmon_cont:
  stx L                         ; 0 -> L
  stx H                         ; and H
  sty YSAV                      ; save Y for later comparison

wozmon_nexthex:
  lda WOZIN,Y                   ; get character for hex test
  eor #'0'                      ; map digits to $00-$09
  cmp #10                       ; less than 10?
  bcc @dig                      ; then it's a digit
  adc #$88                      ; map letters "A"-"F" to $FA-$FF
  cmp #$FA                      ; less than $FA (0x0A)?
  bcc wozmon_nothex             ; then it's not a hex digit
@dig:
  asl                           ; hex digit to high nibble of accumulator
  asl
  asl
  asl
  ldx #4                        ; shift count
@hexshift:
  asl                           ; shift hex digit to the left, highest bit (7) to carry
  rol L                         ; rotate that carry bit into bit 0 of L (low byte)
  rol H                         ; if previous ROL results in a carry bit, then rotate that into bit 0 of H (high byte)
  dex                           ; done four shifts?
  bne @hexshift                 ; no, then loop
  iny                           ; advance text index
  bne wozmon_nexthex            ; always taken, check next character for hex value

wozmon_nothex:
  cpy YSAV                      ; check if L, H empty (no hex digits)
  beq wozmon_getline            ; if yes, then break and read next line
  bit MODE                      ; test MODE byte (bit 6 of MODE into oVerflow flag, bit 7 into Negative flag)
  bvc wozmon_notstor            ; V flag clear (i.e. bit 6 was clear)? Then it's a XAM & BLOCK XAM operation. Otherwise (bit 6 is set) it's a STOR operation.
  lda L                         ; least significant digit of hex data
  sta (STL,X)                   ; store at current 'store index'
  inc STL                       ; increment store index
  bne wozmon_nextitem           ; get next item (if no carry)
  inc STH                       ; otherwise add carry to 'store index' high order

wozmon_tonextitem:
  jmp wozmon_nextitem           ; get next command item

wozmon_run:
  jmp (XAML)                    ; run at current XAML index

wozmon_notstor:
  bmi wozmon_xamnext            ; bit 7 = 0 for XAM, bit 7 = 1 for BLOCK XAM
  ldx #2                        ; byte count
@setadr:
  lda L-1,X                     ; copy hex data
  sta STL-1,X                   ; to 'store index'
  sta XAML-1,X                  ; and to 'XAM index'
  dex                           ; next of two bytes
  bne @setadr                   ; loop unless X = 0

wozmon_nxtprnt:
  bne @prdata                   ; 'not equal', i.e. greater 0, means no address to print
  lda #$9b                      ; ATASCII CR
  jsr wozmon_echo               ; output it
  lda XAMH                      ; 'examine index' high byte
  jsr wozmon_prbyte             ; output it in hex format
  lda XAML                      ; 'examine index' low byte
  jsr wozmon_prbyte             ; output it in hex format
  lda #':'                      ; output colon
  jsr wozmon_echo
@prdata:
  lda #' '                      ; output space
  jsr wozmon_echo
  lda (XAML,X)                  ; get data byte at 'examine index'
  jsr wozmon_prbyte             ; output it in hex format

wozmon_xamnext:
  stx MODE                      ; 0 -> MODE (XAM mode)
  lda XAML                      ; compare 'examine index'
  cmp L                         ; to hex data (low byte)
  lda XAMH
  sbc H
  bcs wozmon_tonextitem         ; not less, so no more data to output
  inc XAML                      ; increment 'examine index' low byte
  bne @mod8chk                  ; test for new line after reaching a modulo 8 byte number
  inc XAMH                      ; increment 'examine index' high byte
@mod8chk:
  lda XAML                      ; check 'examine index' low byte
  and #7                        ; for MOD 8 = 0
  bpl wozmon_nxtprnt            ; always taken

wozmon_prbyte:
  pha                           ; save accumulator for least significant digit
  lsr
  lsr
  lsr
  lsr                           ; most significant digit to least significant digit position
  jsr wozmon_prhex              ; output as hex digit
  pla                           ; restore accumulator

wozmon_prhex:
  and #$0F                      ; mask least significant digit for hex print
  ora #$30                      ; add "0"
  cmp #$3A                      ; is it still a digit?
  bcc wozmon_echo               ; yes, output it
  adc #6                        ; otherwise add offset for letter to generate ATASCII letters A-F

wozmon_echo:
  sta OUTBUF                    ; store accumulator to output buffer byte
  lda #>OUTBUF                  ; High byte of output buffer is zero because of zero page location
  tax                           ; therefore reuse it to set X to zero, then also
  sta ICBAH,X                   ; store it into ICBAH
  sta ICBLH,X                   ; high byte length of message
  lda #<OUTBUF                  ; low byte of message
  sta ICBAL,X                   ; into ICBAL
  lda #1                        ; tell CIO to only store only 1 character when reading
  sta ICBLL,X                   ; low byte length of message
  lda #CMD_PUTCHAR              ; put character command
  sta ICCOM,X                   ; into ICCOM
  tya                           ; we need to preserve Y before entering CIOV
  pha                           ; push to stack
  jsr CIOV                      ; call CIOV
  pla                           ; restore Y from stack
  tay                           ; and transfer to Y register
  rts                           ; return

editor_name:
    .byte "E:", $9B

.endif
