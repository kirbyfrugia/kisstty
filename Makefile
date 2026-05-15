# =============================================================================
# kiss6502 - cross-platform 6502 KISS TNC client
# Targets: atari, c64, apple2, run-atari, run-c64, run-apple2
# Tools:   ca65 + ld65 from cc65 package
#
# Pre-req on CachyOS/Arch:   paru -S cc65-git atari800 vice applecommander
# =============================================================================

CA65        = ca65
LD65        = ld65
AC          = applecommander-ac
ACX         = applecommander-acx
SRCDIR      = platform
BLDDIR      = build
CC65_SHARE ?= /usr/share/cc65
CA65INC     = $(CC65_SHARE)/asminc
CA65FLAGS   = --listing

ATARI_DIR  = $(SRCDIR)/atari
ATARI_XEX  = $(BLDDIR)/atari/kiss6502.xex
ATARI_CFG  = $(CC65_SHARE)/cfg/atari-asm-xex.cfg
ATARI_OBJS = $(BLDDIR)/atari/atari-main.o \
             $(BLDDIR)/atari/boot850.o

# =============================================================================
# ATARI
# =============================================================================
atari: $(ATARI_XEX)
$(BLDDIR)/atari: ; mkdir -p $@

$(BLDDIR)/atari/atari-main.o: $(ATARI_DIR)/atari-main.s | $(BLDDIR)/atari
	$(CA65) --target atari -I $(CA65INC) $(CA65FLAGS) $(BLDDIR)/atari/atari-main.lst -o $@ $<

$(BLDDIR)/atari/boot850.o: $(ATARI_DIR)/boot850.s | $(BLDDIR)/atari
	$(CA65) --target atari -I $(CA65INC) $(CA65FLAGS) $(BLDDIR)/atari/boot850.lst -o $@ $<

$(ATARI_XEX): $(ATARI_OBJS)
	$(LD65) -C $(ATARI_CFG) -o $@ $^

# =============================================================================
# C64
# =============================================================================
C64_DIR  = $(SRCDIR)/c64
C64_PRG  = $(BLDDIR)/c64/kiss6502.prg
C64_CFG  = $(CC65_SHARE)/cfg/c64-asm.cfg
C64_OBJS = $(BLDDIR)/c64/c64-main.o

c64: $(C64_PRG)
$(BLDDIR)/c64: ; mkdir -p $@

$(BLDDIR)/c64/c64-main.o: $(C64_DIR)/c64-main.s | $(BLDDIR)/c64
	$(CA65) --target c64 -I $(CA65INC) $(CA65FLAGS) $(BLDDIR)/c64/c64-main.lst -o $@ $<

$(C64_PRG): $(C64_OBJS)
	$(LD65) -C $(C64_CFG) -o $@ $^

# =============================================================================
# Apple II
# =============================================================================
APPLE2_DIR         = $(SRCDIR)/apple2
APPLE2_BIN         = $(BLDDIR)/apple2/kiss6502.bin
APPLE2_DSK         = $(BLDDIR)/apple2/kiss6502.dsk
APPLE2_CFG         = $(CC65_SHARE)/cfg/apple2-asm.cfg
APPLE2_MASTER_DSK  = /usr/local/share/linapple/Master.dsk
APPLE2_OBJS        = $(BLDDIR)/apple2/apple2-main.o

apple2: $(APPLE2_BIN) $(APPLE2_DSK)
$(BLDDIR)/apple2: ; mkdir -p $@

$(BLDDIR)/apple2/apple2-main.o: $(APPLE2_DIR)/apple2-main.s | $(BLDDIR)/apple2
	$(CA65) --target apple2 -I $(CA65INC) $(CA65FLAGS) $(BLDDIR)/apple2/apple2-main.lst -o $@ $<

$(APPLE2_BIN): $(APPLE2_OBJS)
	$(LD65) -C $(APPLE2_CFG) -o $@ $^

$(APPLE2_DSK): $(APPLE2_BIN)
	cp $(APPLE2_MASTER_DSK) $(APPLE2_DSK)
	chmod 644 $(APPLE2_DSK)
	$(AC) -d $(APPLE2_DSK) HELLO
	$(AC) -p $(APPLE2_DSK) KISS6502 B 0x0803 < $(APPLE2_BIN)
	printf '10 PRINT CHR$$(4);"BRUN KISS6502"\r' | $(ACX) import --basic --stdin --name=HELLO -d $(APPLE2_DSK)

# =============================================================================
all: atari c64 apple2
clean: ; rm -rf $(BLDDIR)

run-atari: $(ATARI_XEX)
	atari800 -nobasic -rdevice -run $(ATARI_XEX)

run-c64: $(C64_PRG)
	x64sc -autostartprgmode 1 -autostart $(C64_PRG)

run-apple2: $(APPLE2_DSK)
	linapple --d1 $(APPLE2_DSK) --autoboot

.PHONY: all atari c64 apple2 clean run-atari run-c64 run-apple2
