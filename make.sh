#!/bin/sh
set -x
dmd -m64 resync.d
rm *.o
