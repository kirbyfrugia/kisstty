.SETCPU "6502"
.SEGMENT "CODE"

.EXPORT copy_buffer40 
.EXPORT copy_buffer40_size
.EXPORT copy_buffer240 
.EXPORT copy_buffer240_size
.EXPORT discard_buffer240 
.EXPORT discard_buffer240_size

copy_buffer40:      .res 40
copy_buffer40_size: .byte 0
copy_buffer240:      .res 40
copy_buffer240_size: .byte 0
discard_buffer240:      .res 40
discard_buffer240_size: .byte 0
