#!/bin/sh
set -x
../resync --updated --changed --removed --added --emptied --print --confirm --create --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --changed --removed --added --emptied --sample 128K 1M 1M --verbose --print --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --changed --removed --added --emptied --exclude ".git/" --exclude "*/.git/" --exclude "*.tmp" --print --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --adjusted 1 --allowed 2 --print --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --moved --preview SOURCE_FOLDER/ TARGET_FOLDER/

