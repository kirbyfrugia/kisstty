.SETCPU "6502"
.SEGMENT "CODE"

.EXPORT copy_buffer40 
.EXPORT copy_buffer40_size

copy_buffer40:      .res 40
copy_buffer40_size: .byte 0
