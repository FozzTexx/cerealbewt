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

def build_argparser():
  parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
  parser.add_argument("serial", default="/dev/ttyUSB0", help="device to use as serial port")
  parser.add_argument("baud", type=int, help="baud rate")
  parser.add_argument("file", help="input file")
  parser.add_argument("--flag", action="store_true", help="flag to do something")
  return parser

def xmit_string(ser, val):
  for c in val:
    # The BASIC program drops characters like mad, keep retrying until it echos
    while True:
      ser.write(c.encode("ASCII"))
      echo = ser.read(1)
      if len(echo):
        echo = echo.decode("ASCII")
        if echo != c:
          print("Transmit failed", echo, c)
          exit(1)
        break
  return

def main():
  args = build_argparser().parse_args()

  with open(args.file, "rb") as file:
    data = file.read()

  ser = serial.Serial(args.serial, baudrate=args.baud,
                      bytesize=serial.SEVENBITS,
                      parity=serial.PARITY_EVEN, timeout=1,
                      rtscts=False, xonxoff=False, dsrdtr=False)

  # Wait for READY
  buffer = ""
  while buffer[-5:] != "READY":
    echo = ser.read(1)
    if len(echo):
      echo = echo.decode("ASCII")
      print(echo, end="", flush=True)
      buffer += echo

  lenstr = str(len(data)) + "\r"
  xmit_string(ser, lenstr)

  for c in data:
    xmit_string(ser, "%02x" % (c))

  return

if __name__ == '__main__':
  exit(main() or 0)
