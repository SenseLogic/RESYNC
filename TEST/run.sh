#!/bin/sh
set -x
../resync --moved --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --create --updated --changed --removed --added --emptied --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --changed --removed --added --emptied --sample 128K 1M 1M --verbose --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --changed --removed --added --emptied --exclude ".git/" --exclude "*/.git/" --exclude "*.tmp" --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --adjusted 1 --allowed 2 --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/

