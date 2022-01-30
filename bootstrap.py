#!/usr/bin/env python3

# Copyright 2022 by Chris Osborn <fozztexx@fozztexx.com>
#
# This file is part of cerealbewt.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.

import argparse
import serial
import time
import sys
import select
import termios, tty

BOOTSTRAP_SIZE = 512

def build_argparser():
  parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
  parser.add_argument("serial", default="/dev/ttyUSB0", help="device to use as serial port")
  parser.add_argument("bootstrap", help="512 bytes to send over")
  parser.add_argument("binary", help="file to send over after bootstrap")
  parser.add_argument("--loadpos", default=0, help="load address of binary")
  #parser.add_argument("--startpos", help="start address of binary")
  parser.add_argument("--flag", action="store_true", help="flag to do something")
  return parser

def waitForDSR(ser, state):
  while ser.dsr != state:
    pass
  return

def waitForCTS(ser, state):
  while ser.cts != state:
    pass
  return

def eatGarbage(ser):
  while True:
    garbage = ser.read(1)
    if len(garbage) == 0:
      break
  return

def sendUnsigned(ser, val, count):
  for idx in range(count):
    out = val & 0xff
    ser.write(bytes([out]))
    echo = ser.read(1)
    val >>= 8
  return

def main():
  args = build_argparser().parse_args()

  with open(args.bootstrap, "rb") as file:
    bstrap = file.read()
  # Make sure bstrap is exactly the right size
  bstrap = bstrap[:BOOTSTRAP_SIZE]
  if len(bstrap) < BOOTSTRAP_SIZE:
    bstrap += b"\0" * (BOOTSTRAP_SIZE - len(bstrap))

  # Victor serial boot uses 8 bit bytes + even parity for a total
  # of 9 bits; 11 bits including start and stop bits.
  ser = serial.Serial(args.serial,
                      baudrate=1200, bytesize=serial.EIGHTBITS, parity=serial.PARITY_EVEN,
                      timeout=1, rtscts=False, xonxoff=False, dsrdtr=False)
  ser.dtr = True

  print("Waiting for Victor")
  waitForCTS(ser, True)
  eatGarbage(ser)

  print("Sending", args.bootstrap)
  for idx in range(len(bstrap)):
    ser.write(bstrap[idx:idx+1])
    print("Sent: %3i\r" % (idx+1), end="", flush=True)
    echo = ser.read(1)

    if len(echo) == 0 and idx == 0:
      waitForCTS(ser, False)
      waitForCTS(ser, True)
      eatGarbage(ser)
      ser.write(bstrap[idx:idx+1])
      echo = ser.read(1)

    if idx < 511 and (len(echo) == 0 or echo[0] != bstrap[idx]):
      print("Bootstrap failed", idx, echo, "!=", hex(bstrap[idx]))
      return 1

  print("Bootstrap complete")

  # Wait for READY
  ser.baudrate = 19200
  #ser.parity = serial.PARITY_NONE

  buffer = ""
  ser.write("Z".encode("ASCII"))
  while buffer[-7:] != "READY\r\n":
    echo = ser.read(1)
    if len(echo):
      echo = echo.decode("ASCII")
      print(echo, end="", flush=True)
      buffer += echo

  with open(args.binary, "rb") as file:
    binary = file.read()

  dest = args.loadpos
  if isinstance(dest, str):
    if ':' in dest:
      dso = dest.split(':')
      segment = int(dso[0], 0)
      offset = int(dso[1], 0)
    else:
      dest = int(dest, 0)
      segment = (dest & 0xF0000) >> 4
      offset = dest & 0xFFFF
    dest = (segment << 16) | offset

  blen = len(binary)

  print("Sending %s of length 0x%06x at 0x%06x" % (args.binary, blen, dest))
  sendUnsigned(ser, blen, 3)
  sendUnsigned(ser, dest, 4)

  err = 0
  for idx in range(blen):
    ser.write(binary[idx:idx+1])
    echo = ser.read(1)
    print("Remain: %5i\r" % (blen - idx), end="", flush=True)
    if len(echo) == 0 or echo[0] != binary[idx]:
      print("Send failed", idx, echo, "!=", hex(binary[idx]))
      err += 1
      if err >= 10:
        break

  stdin_fd = sys.stdin.fileno()
  ser.parity = serial.PARITY_NONE
  old_settings = termios.tcgetattr(stdin_fd)

  print("Entering simple terminal mode, push Control-C to exit")
  
  try:
    tty.setraw(stdin_fd)
    read_fds = [sys.stdin, ser]
    while True:
      ready = select.select(read_fds, [], [])
      if sys.stdin in ready[0]:
        c = sys.stdin.read(1)
        if ord(c) == 3:
          break
        ser.write(c.encode("ASCII"))
      if ser in ready[0]:
        echo = ser.read(1)
        echo = echo.decode("ASCII")
        print(echo, end="", flush=True)
  finally:
    termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_settings)

  print()

  return

if __name__ == '__main__':
  exit(main() or 0)
