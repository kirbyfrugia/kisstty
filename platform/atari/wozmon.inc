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

.ifndef WOZMON_INC
WOZMON_INC = 1

.global wozmon_main

.endif
