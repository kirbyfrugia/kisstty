# kiss8b - Terminal and Packet Radio app for 8-bit computers

This will be a KISS TNC ("Keep It Simple, Stupid" Terminal Node Controller) client for Atari 8-bit computers, Apple II, and Commodore 64. The purpose is to have a nice terminal to be used for Packet Radio.

If you're looking at this, you're probably one of only a few people who are into both ham radio and 8-bit computers. So, really I'm just building it for me.

As I've been working on it, I also ended up implementing a basic terminal, too. So you can use it as a generic terminal as well.

# Status

It's in the early phases. I'm intending to create the Atari 800 first, then the Apple II, then the Commodore.

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
