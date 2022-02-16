#!/bin/sh
set -x
dmd -debug -g -gf -gs -m64 resync.d
rm *.o
