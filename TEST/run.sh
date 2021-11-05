#!/bin/sh
set -x
mkdir -p EMPTY_FOLDER
../resync --create --updated --changed --removed --added --emptied EMPTY_FOLDER/ CHANGE_FOLDER/
../resync --create --updated --changed --removed --added --emptied EMPTY_FOLDER/ BACKUP_FOLDER/
../resync --create --updated --changed --removed --added --emptied --store CHANGE_FOLDER/ TARGET_FOLDER/ BACKUP_FOLDER/
../resync --create --updated --changed --removed --added --emptied --store CHANGE_FOLDER/ SOURCE_FOLDER/ BACKUP_FOLDER/
../resync --create --updated --changed --removed --added --emptied --preview SOURCE_FOLDER/ BACKUP_FOLDER/
read key
../resync --create --updated --changed --removed --added --emptied --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --changed --removed --added --moved --emptied --verbose --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --changed --removed --added --moved --emptied --sample 128k 1m 1m --verbose --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --changed --removed --added --emptied --exclude ".git/" --ignore "*.tmp" --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --changed --removed --added --emptied --select "/A/" --select "/C/" --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --updated --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --adjusted 1 --allowed 2 --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
../resync --moved --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/
