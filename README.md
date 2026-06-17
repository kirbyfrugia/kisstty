# kisstty

*A dead simple terminal and packet radio app for 8-bit computers and modern PCs*

* KISS - Keep it Simple Stupid. A protocol used for APRS/Packet Radio. Also the design intent for this app.
* TTY  - A text-only terminal. Not to be confused with teletype, but there's definitely some overlap here!

This started as a project to build a terminal/aprs/rtty app for 8-bit computers.
This program is still that, and I almost have that part fully working for the Atari 800.

But what I realized is that what I really wanted a way to communicate over text
with people and have real conversations. Ok, not voice conversations, but text
conversations over radio. I think some software exists out there, but I want this
to be as dead simple as possible. No realtime maps, not fancy features. Just a simple
text interface that will work in a broadcast/monitor mode and a QSO mode.

Basically, a purpose-built app to trade messages with people and a community.
Kinda like IRC or discord, but over the air and even simpler.

Target platforms in order:
* Atari 800 (in active development). Can be used already as a standard terminal and with basic KISS message mode (rx).
* Linux and Windows (next). Will be built in rust.
* Apple II
* Commodore 64

# Status

The Atari version is far enough along that you can use it as a standard terminal. KISS/APRS in progress.

# Docs

Each platform-specific version has its own readme that tells you how to build, run, and debug it.

# Use of open source

Special thanks to:
* [fredlcore](https://github.com/fredlcore) for [AtariWozmon](https://github.com/fredlcore/AtariWozMon). Also, all the people he thanked in his repo.
* Andrew Jacobs for the [binary to BCD code](https://6502.org/source/integers/hex2dec-more.htm) 
* Bruce Clark for [mem move](https://6502.org/source/general/memory_move.html)


**Note on AI usage:**

My intent with this project is to write all the assembly code myself.
I'm writing the code, the UI, the logic. Basically, all the assembly.
I'm debugging it myself, painful as that is at times.

I also designed it and built all the hardware I used for it (serial cables, TNC cables).

Here are the ways I used AI (or intend to) to do the stuff I don't care about:
* I used AI to do some OCR of images. Specifically, I wrote code that dumped memory to my screen and I took a photo with my phone. I had Claude convert that to text for a file on my PC.
* I copied and pasted the keycode to ATASCII lookup table from the Atari OS User's manual and had Claude turn that into a lookup file for me.
* I used it to tweak some of the instructions in my readme files, though I mostly wrote them. It's just a pain in the butt and I don't care if AI does it.
* I had it write some of the helper scripts like run-atari.sh. I didn't care enough to write them myself. I wanted to focus on the actual code.
* I'm going to have it generate some test APRS files for me.
