#!/bin/sh
set -x
../resync --changed --moved --removed --added --print --confirm --preview --exclude I/ --include *.txt NEW/ OLD/
../resync --updated --preview NEW/ OLD/
../resync --updated --preview OLD/ NEW/
