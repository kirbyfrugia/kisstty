.SETCPU "6502"
.SEGMENT "CODE"

.EXPORT copy_buffer40 
.EXPORT copy_buffer40_size
.EXPORT copy_buffer240
.EXPORT copy_buffer240_size

copy_buffer40:          .res  40
copy_buffer40_size:     .byte 0
copy_buffer240:         .res  240
copy_buffer240_size:    .byte 0
discard_buffer240:      .res  240
discard_buffer240_size: .byte 0
