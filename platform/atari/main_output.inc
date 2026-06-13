; A screen is made up of multiple output text areas and a single input
; text area. In some cases, we have a single line input (e.g. char mode)
; and in others we have a multi-line input.
;
; The screen uses multiple output text areas to keep their size below 256
; bytes Each text area has its own cursor, but it isn't visible in output
; text areas. The cursor is used to know where to insert text, even
; if it is not visible.
;
; main_output is responsible for managing flow between the text areas.
; For example, if we receive text over serial, that text goes to the
; upper left of the upper text area. It keeps getting added to that text
; area until it overflows. At that point, new text goes to the next
; output text area downwards.
;
; Once text reaches the bottom right of the bottom text area, all output
; text areas scroll upwards and a new line is added at the bottom. The
; cursor moves to the start of that line and we continue.
;
; Users only interact with the input text area. The input area can
; be in one of two modes. In line mode, users interact with it until
; they are done. They then hit return to accept their input.
;
; If it's line mode, there are 4 lines of text at the bottom and
; only have three output text areas active. If it's char mode,
; there is only one line of text at the bottom and we have the
; "EXTRA" text area in use.
;

.ifndef MAIN_OUTPUT_INC
MAIN_OUTPUT_INC = 1

.global mo_init
.global mo_append_char
.global mo_append_chars
.global mo_println
.global mo_repaint
.global mo_reset

.endif
