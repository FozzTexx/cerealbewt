## About

It has been long rumored that it is possible to boot a Victor 9000 /
Sirius 1 over the RS-232 serial port. I have put together a simple
package called cerealbwet to not only demonstrate that it's possible,
but also provides a first step for doing more sophisticated booting
from serial.

Chris Osborn - [@FozzTexx](https://twitter.com/FozzTexx) - [insentricity.com](https://www.insentricity.com/a.cl/285/booting-a-victor-9000-with-cereal) - fozztexx@fozztexx.com

## Monitor/Debugger

As part of this project I have included a port of [Seattle Computer
Products
MON-86](http://www.bitsavers.org/pdf/seattleComputer/SCP-300_MON-86_V1.5A.pdf). It
is a very basic conversion and **does not** include disk drive support,
screen support, or keyboard support.

## Getting started

In order to convince the Victor ROM to boot from serial, it must have
no other boot devices available. That means that you need to unplug or
remove any floppy drives, hard drives, or network cards. I found it
was not necessary to unplug the 50 pin ribbon cable going to the
floppy drives, unplugging the power cord was enough to disable them.

You will also need to construct a special serial cable or adapter. I
made a simple pass through adapter using male and female DB25
connectors, wired according to the diagram below:

    Host 	       Victor

     2  TX ────►  RX  3
     3  RX ────►  TX  2
     5 CTS ────►  RTS 4
     7 GND ────►  GND 7
    20 DTR ──┬─►  DSR 6
             ├─►  RI 22
             └─►  CD 8
		  Victor ROM source says CD is
		  needed but wasn't required in
		  my testing

The Victor serial boot uses an odd 9-bit parity configuration (8 data
bits and 1 parity bit). This may or may not be supported by the serial
hardware on your host system. Some USB RS232 adapters may not like
it. Without proper 9-bit parity support you will *not* be able to boot
the Victor over serial because it parity checks every byte.

### Requirements

You will need nasm, make, and Python 3 installed.

### Building

Simply type `make` to assemble cboot and vicmon.

## Usage

To boot the Victor over serial you need to connect your host computer
to serial port A on the Victor (the DB25 connector closest to the
video port) using the adapter or cable you made according to the above
diagram. Power on the Victor and wait for it to finish the memory test
and print the available memory on screen. It should not display any
disk or network icons. If it does, turn off the Victor and disconnect
them and try again.

Once the memory size has been displayed, you can send over the stage 2
bootloader followed by the monitor program:

```sh
bootstrap.py bootstrap.py --loadpos 0x1f800 /dev/ttyUSB0 cboot.bin vicmon.bin
```

All Victors have a minimum of 128k of RAM, so vicmon has been
assembled to live at the top of the 128k (0x1f800). This should keep
it mostly out of the way if you want to try to manually send over
other programs.

Once vicmon.bin has been sent over, bootstrap.py will enter a simple
terminal mode so that you can interact with the [Seattle Computer
Products
monitor](http://www.bitsavers.org/pdf/seattleComputer/SCP-300_MON-86_V1.5A.pdf).

## License

cboot.asm and bootstrap.py are distributed under GPL 2. vicmon.asm
remains under the same license that Seattle Computer Products released
MON-86 under ("This software is not copyrighted.").

