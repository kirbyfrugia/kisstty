
# kiss6502 - Atari

## Pre-requisites

If you want to run it in an emulator and connect to direwolf, you need to build atari800 with R: device support.

Here's how I did that on CachyOS:
```
paru -G atari800
cd atari800
# this next line will probably work, but if it doesn't match just find the comment and uncomment it.
sed -i 's/#--enable-riodevice/--enable-riodevice/' PKGBUILD
makepkg -fi
```

## Building kiss8b

```
# to build the release release
make atari

# to build the debug mode with wozmon built in
make atari-debug
```
This will create an xex file and an atr file in `build/atari/<dist>`.

## Running kiss8b

```
# To run it on the real atari, just boot the atr and it will run
# automatically. I load it in fujinet.
# Note: turn on your Atari 850 first. You don't have to do that
#       since I added bootstrapping code, but if you don't
#       you'll need to turn it off and back on again and reconnect.

# If you want to run it in the atari800 emulator:
make run-atari 
```

## Debugging

I ported [AtariWozmon](https://github.com/fredlcore/AtariWozMon) to ca65 syntax. To use:
```
# Make a debug release that will run either on your Atari or in an emulator
make clean && make atari-debug

# Running on a real atari
Just load the atr and boot

# Running in atari800 emulator
make debug-atari

# You'll land in wozmon. You can execute the main app by:
4000R

# To re-enter wozmon on brk, simply add brk to your code, e.g.
lda #42
...
brk     ; re-enters wozmon

```

## Connecting to direwolf

You can connect to direwolf over serial from your Atari or over TCP
from the atari800 emulator. If you're using the emulator, just note
that atari800 won't open a port until kiss8b does a status message.
It might also close the port if you aren't doing frequent reads.

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

# for emulator
kissutil -v -p 9000

# If you get a connection error or a read timeout, make sure you built atari800
# with the r device enabled (see above). But you might still get an error
# because it seems like that code is a bit buggy or has a race condition.

# For some reason, wrapping it in strace made it work. I suspect there
# is some kind of timing issue. So if you encounter that situation,
# run the emulator like this instead:
strace -f -e trace=network -o /dev/null atari800 -atari -nobasic -rdevice build/atari/release/kiss8b.atr
# ... or for debug ...
strace -f -e trace=network -o /dev/null atari800 -atari -nobasic -rdevice build/atari/debug/kiss8b.atr

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


## Known issues

Some of the special screen editing functions don't work right on the atari800 emulator, at least in CachyOS.

* shift+clear (\$76 on the atari) and ctrl+clear (\$b7 on the atari). On the emulator, I tried shift+backspace and shift+delete, but they both mapped to keycode $b4.
* shift+insert (\$77 on the atari). Tried shift+insert, which mapped to \$7c on the emulator.
* I can easily type faster than the atari800 emulator can handle and some keys are missed. This also happens when I just run straight basic on the emulator, so I don't think it's an issue with this code.
* When running in the emulator over a TCP port, I had issues receiving $FF bytes. This occurrs when an APRS source has a station id of 15. In that case, it parses the wrong station ID. If $ff appears in the data elsewhere, it might cause weird problems.

## Resources:
* [Mapping the Atari](https://www.atariarchives.org/mapping/) - amazing book documenting every memory location in the Atari.
* [Altirra Hardware Reference Manual](https://www.virtualdub.org/downloads/Altirra%20Hardware%20Reference%20Manual.pdf) - very helpful regarding the Atari 850 bootstrapping process and serial comms.
* [Assembly Language Programming for the Atari Computers](https://www.atariarchives.org/alp/index.php)
* [De Re Atari](https://www.atariarchives.org/dere/index.php)
* [Atari Wiki CIOV Tutorial](https://atariwiki.org/wiki/Wiki.jsp?page=CIOV%20Tutorial)

# Use of open source

Special thanks to:
* [fredlcore](https://github.com/fredlcore) for [AtariWozmon](https://github.com/fredlcore/AtariWozMon). Also, all the people he thanked in his repo.
