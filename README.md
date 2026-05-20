# kiss8b

This will be a KISS TNC ("Keep It Simple, Stupid" Terminal Node Controller) client for Atari 8-bit computers, Apple II, and Commodore 64. The purpose is to have a nice terminal to be used for Packet Radio.

If you're looking at this, you're probably one of only a few people who are into both ham radio and 8-bit computers. So, really I'm just building it for me.

# Status

I'm just getting started on it. I'm intending to create the Atari 800 first, then the Apple II, then the Commodore.

# Atari Helpful stuff

My goal with this is to make it work for both a real Atari 850 and with emulators like fujinet.

## Atari 850 bootstrapping

My implementation was based off of what is described in the Altirra Hardware Reference Manual (pages 251 to 252). It basically works like this:
1. Send poll command ($3f) to Atari 850 ($50)
2. Grab the response and shove it into the DCB. Call SIOV.
3. Call $0506 to load, relocate, and intialize the handler at MEMLO.

But it wasn't working for me. At least, I wasn't seeing the R: handler loaded in HATABS. So I did a dump of both the relocator and the handler, which you can find in the 3rdparty/atari/atari850 directory.

I was getting valid responses to each of the commands. I could see that Step 2 was sending command $21 (load) then $26 (load peripheral handler) then $53 (status) which seemed to map nicely to what was supposed to happen according to the Altirra docs. However, the R: handler was not showing up in HATABS.

I searched the code for any pointers to `$031a` (HATABS). There was a loop in the code that looked for an empty slot in HATABS. Nothing else in the code seemed to be calling that from the loader or the handler. So I just made a call directly to the code at `$0ab3` after the bootstrapping sequence. It worked and the R: device showed up in HATABS. It was surprising, but it seemed to work.

Where it still might fail:
* This was built to work with a rom dump from my actual 850. According to the Altirra manual, there are different ROM revisions. I think mine is the common one. My code should work on all revisions for the most part, with the exception that I hard-coded the call to load HATABS with the R: handler after it was loaded (`jsr $0ab3`). It's calling directly into a routine that exists at a known location in my ROM revision. Yours *might* differ but I have no way of knowing.
* I have two SIO2PCs. One of them seems to have a conflict with the Atari 850 when trying to bootstrap the R: handler. I never figured out why, but maybe one of them was driving the bus weirdly. If you have one of these, try booting up using it. Then unplug it before trying to load the R: handler.

## Debugging

I ported [AtariWozmon](https://github.com/fredlcore/AtariWozMon) to ca65 syntax. To use:
```sh
make clean && make atari-debug
make run-debug # to run in the atari800 emulator (or run it from your actual atari)

# You'll land in wozmon. You can execute the main app by:
4000R

```

## Resources:
* [Altirra Hardware Reference Manual](https://www.virtualdub.org/downloads/Altirra%20Hardware%20Reference%20Manual.pdf) - very helpful regarding the Atari 850 bootstrapping process and serial comms.
* [Assembly Language Programming for the Atari Computers](https://www.atariarchives.org/alp/index.php)

# Use of open source

Special thanks to:
* [fredlcore](https://github.com/fredlcore) for [AtariWozmon](https://github.com/fredlcore/AtariWozMon) and all the people he thanked in his repo.
