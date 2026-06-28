# kisstty

*A dead simple terminal and packet radio app for 8-bit computers and modern PCs*

* KISS - Keep it Simple Stupid. A protocol used for APRS/Packet Radio. Also the design intent for this app.
* TTY  - A text-only terminal. Not to be confused with teletype, but there's definitely some overlap here!

This started as a project to build a terminal/aprs/rtty app for 8-bit computers.
Also as a way for me to have conversations with my dad over packet radio because we're
at a weird distance from each other for having voice conversations.

This program is still that, and I almost have that part fully working for the Atari 800.

But what I realized was that what I really wanted was a way have real conversations. With people.
Ok, not voice conversations, but text conversations at least. I think some software exists out there,
but I want this to be as dead simple as possible. No realtime maps, not fancy features. Just a simple
text interface that will work in a broadcast/monitor mode and a QSO mode.

Basically, a purpose-built app to trade messages with people and a community.
Kinda like IRC or discord, but over the air and even simpler.

Target platforms in order:
* Atari 800 (in active development). Can be used already as a standard terminal and with basic KISS message mode (rx).
* Linux and Windows (next). Will be built in rust.
* Apple II
* Commodore 64

## Status

The Atari version is far enough along that you can use it as a standard terminal. KISS/APRS in progress.

## Docs

Each platform-specific version has its own readme that tells you how to build, run, and debug it.

## Use of open source

Special thanks to:
* [fredlcore](https://github.com/fredlcore) for [AtariWozmon](https://github.com/fredlcore/AtariWozMon). Also, all the people he thanked in his repo.
* Andrew Jacobs for the [binary to BCD code](https://6502.org/source/integers/hex2dec-more.htm) 
* Bruce Clark for [mem move](https://6502.org/source/general/memory_move.html)

## Note on AI usage

My intent with this project is to write all the code myself, and that's what I'm doing. I'm writing the code, the UI, the logic. I'm debugging it myself, painful as that is at times.

I also designed it and built all the hardware I used for it (serial cables, TNC cables).

But I am using UI for some of the stuff I don't care to do myself:
* I used AI to do some OCR of images. Specifically, I wrote code that dumped memory to my screen and I took a photo with my phone. I had Claude convert that to text for a file on my PC.
* I copied and pasted the keycode to ATASCII lookup table from the Atari OS User's manual and had Claude turn that into a lookup file for me.
* I used it to tweak some of the instructions in my readme files, though I mostly wrote them. It's just a pain in the butt and I don't care if AI does it.
* I had it write some of the helper scripts like run-atari.sh since I hate writing shell scripts and I wanted to focus on the actual program code.

Also, I'm new to rust, so I'm trying to learn it from scratch by reading books and docs. But I'm also asking claude clarifying questions when I get stuck and don't understand something.

## License

kisstty is licensed under the MIT License — see [LICENSE](LICENSE).

Third-party code incorporated into this project is credited in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
