#!/bin/sh
set -x
dmd -O -inline -m64 resync.d
rm *.o
