# kiss6502 - Atari

## Building kiss8b

```
# to build the release release
make atari

# to build the debug mode with wozmon built in
make atari-debug
```
This will create an xex file and an atr file in `build/atari/<dist>`.

## Running kiss8b

You can run kiss8b on a real Atari or in Altirra.

### On a real Atari

```
# Just boot the atr and it will run automatically. I load it in fujinet.
# Note: turn on your Atari 850 first. You don't have to do that
#       since I added bootstrapping code, but if you don't
#       you'll need to turn it off and back on again and reconnect.
```

### Altirra (under Bottles/Wine)

```sh
# One-time setup:
# 1. Install Bottles, create a bottle named "altirra" (or set ALTIRRA_BOTTLE)
# 2. Install Altirra into the bottle
# 3. Allow the sandbox to read your home dir:
flatpak override --user com.usebottles.bottles --filesystem=home

# 4. Get the 850 firmware and save it two directories up from Altirra64.exe:
#    https://github.com/ascrnet/FW-Altirra/raw/refs/heads/main/Automatic/850.rom
#    -> .altirra-firmware/850.rom
#     (or edit the firmware path in platform/atari/altirra/Altirra.ini if you'd rather put it elsewhere)

# 5. Point at Altirra inside the bottle, e.g.:
export ALTIRRA_EXE="$HOME/Applications/Altirra-4.40/Altirra64.exe"

# Usage:
./run-atari.sh debug      # build/atari/debug/kiss8b.atr
./run-atari.sh release    # build/atari/release/kiss8b.atr
```

#### Talking to the emulated 850 over TCP

Altirra's networked serial port (on the 850) is configured to listen on
port 9000.

```sh
# Altirra's networked serial port must be set to "Listen for an incoming connection" on port 9000
socat -d -d PTY,link=/tmp/altirra-tty,raw,echo=0 TCP:127.0.0.1:9000
minicom -D /tmp/altirra-tty
# (in minicom: Ctrl-A O -> Serial port setup -> turn off hardware flow control)
```

## Debugging

I ported [AtariWozmon](https://github.com/fredlcore/AtariWozMon) to ca65 syntax. To use:
```
# Make a debug release that will run either on your Atari or in an emulator
make clean && make atari-debug

# Running on a real atari
Just load the atr and boot

# Running in Altirra
./tools/run-atari.sh debug

# You'll land in wozmon. You can execute the main app by:
4000R

# To re-enter wozmon on brk, simply add brk to your code, e.g.
lda #42
...
brk     ; re-enters wozmon

```

## Connecting to direwolf

You can connect to direwolf over serial from your Atari, or over TCP
from Altirra (see above).

Make sure these lines are in your direwolf config:
```
KISSPORT 8001
SERIALKISS /dev/COM1 9600
```

To test your connection
```
1. Launch kiss8b and open the connection.

2. Start kissutil

# for a real atari
kissutil -v -p /dev/<your port> -s 9600

# for Altirra
kissutil -v -p 9000

3. Type a message in kissutil, e.g.
W7TTY>DEST:this is a test

4. You should see kiss8b receive that packet.

```

# Interesting Atari notes.

## Atari 850 bootstrapping

I had to figure out how to boot the Atari 850 from my code, which was hard and interesting. So I'm documenting it here.

My implementation was based off of what is described in the Altirra Hardware Reference Manual (pages 251 to 252). It basically works like this:

1. Send poll command ($3f) to Atari 850 ($50)
2. Grab the response and shove it into the DCB. Call SIOV.
3. Call $0506 to load, relocate, and intialize the handler at MEMLO.

But it wasn't working for me. At least, I wasn't seeing the R: handler loaded in HATABS. So I did a dump of both the relocator and the handler, which you can find in the 3rdparty/atari/atari850 directory.

I was getting valid responses to each of the commands. I could see that Step 2 was sending command $21 (load) then $26 (load peripheral handler) then $53 (status) which seemed to map nicely to what was supposed to happen according to the Altirra docs. However, the R: handler was not showing up in HATABS.

I searched the code for any pointers to `$031a` (HATABS). There was a loop in the code that looked for an empty slot in HATABS. Nothing else in the code seemed to be calling that from the loader or the handler. So I just made a call directly to the code at `$0ab3` after the bootstrapping sequence. It worked and the R: device showed up in HATABS!

Where it still might fail:

* This was built to work with a rom dump from my actual 850. According to the Altirra manual, there are different ROM revisions. I think mine is the common one. My code should work on all revisions for the most part, with the exception that I hard-coded the call to load HATABS with the R: handler after it was loaded (`jsr $0ab3`). It's calling directly into a routine that exists at a known location in my ROM revision. Yours *might* differ but I have no way of knowing.
* I have two SIO2PCs. One of them seems to have a conflict with the Atari 850 when trying to bootstrap the R: handler. I never figured out why, but maybe one of them was driving the bus weirdly. If you hit this issue, try booting with your SIO2PC and then unplugging it before trying to load the R: handler. i.e. before opening the terminal.

## Resources:
* [Mapping the Atari](https://www.atariarchives.org/mapping/) - amazing book documenting every memory location in the Atari.
* [Altirra Hardware Reference Manual](https://www.virtualdub.org/downloads/Altirra%20Hardware%20Reference%20Manual.pdf) - very helpful regarding the Atari 850 bootstrapping process and serial comms.
* [Assembly Language Programming for the Atari Computers](https://www.atariarchives.org/alp/index.php)
* [De Re Atari](https://www.atariarchives.org/dere/index.php)
* [Atari Wiki CIOV Tutorial](https://atariwiki.org/wiki/Wiki.jsp?page=CIOV%20Tutorial)

# Use of open source

Special thanks to:
* [fredlcore](https://github.com/fredlcore) for [AtariWozmon](https://github.com/fredlcore/AtariWozMon). Also, all the people he thanked in his repo.
