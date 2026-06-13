; =============================================================================
; Bootstraps the Atari 850 R: handler
; * (mostly) Handles ROM revisions automatically since it uses the info
;   from the 850. See readme for a possible exception.
;
; Source: Altirra Hardware Reference Manual (Avery Lee) pages 251-253
;
; Requirements:
;   $0500-$0658 must be free
; =============================================================================
.ifndef BOOT850_INC
BOOT850_INC = 1

.global boot850_bootstrap ; bootstrap the 850 (only thing you really need to call)
.global boot850_check     ; check if R: handler present in HATABS

.endif
