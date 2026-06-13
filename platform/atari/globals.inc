.ifndef COMMON_INC
COMMON_INC = 1

.globalzp ZPB0, ZPB1, ZPB2, ZPB3, ZPB4, ZPB5
.globalzp CMDDATA0, CMDDATA1, CMDDATA2, CMDDATA3, CMDDATA4, CMDDATA5, CMDDATA6, CMDDATA7
.globalzp SCR_PTR_LO, SCR_PTR_HI

.global g_copy_buffer40 
.global g_copy_buffer40_size

.global g_rx_buf, g_disp_buf
.global g_kbd_key_pressed
.global g_kbdcode_raw
.global g_kbdcode_raw_stripped
.global g_kbdcode_atascii

.globalzp g_rx_buf_num_chars, g_disp_buf_num_chars

SCREEN_WIDTH  = 40
SCREEN_HEIGHT = 24

.endif
