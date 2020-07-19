![](https://github.com/senselogic/RESYNC/blob/master/LOGO/resync.png)

# Resync

Local folder synchronizer.

## Features

* Efficiently synchronize big file trees between local disks without computing checksums.
* Processes the updated, changed, moved, removed and added files independently.
* Allows to include/exclude files by folder, name or path using wildcards.

## Limitations

* Symbolic links are not processed.

## Installation

Install the [DMD 2 compiler](https://dlang.org/download.html) (using the MinGW setup option on Windows).

Build the executable with the following command line :

```bash
dmd -m64 resync.d
```

## Command line

```bash
resync [options] SOURCE_FOLDER/ TARGET_FOLDER/
```

### Options

```
--create : create the target folder if it doesn't exist
--adjusted 0 : minimum adjusted modification time offset in milliseconds
--updated : find the updated files
--changed : find the changed files
--moved : find the moved files
--removed : find the removed files
--added : find the added files
--emptied : find the emptied folders
--exclude FOLDER_FILTER/ : exclude matching folders
--include FOLDER/ : include this folder
--ignore file_filter : ignore matching files
--keep file_filter : keep matching files
--select file_filter : select only matching files
--sample 0 1m all : minimum, medium and maximum sample size (`b` for bytes, `k` for kilobytes, `m` for megabytes, `g` for gigabytes)
--allowed 2 : maximum allowed modification time offset in milliseconds
--abort : abort on errors
--verbose : show the processing messages
--confirm : print the changes and ask confirmation before applying them
--preview : preview the changes without applying them
```

### Examples

```bash
resync --create --updated --changed --removed --added --emptied --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Creates the target folder if it doesn't exist, finds the updated/changed/removed/added files and the emptied folders, prints these changes and asks confirmation before applying them to the target folder.

```bash
resync --updated --changed --removed --added --moved --emptied --verbose --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Finds the updated/changed/removed/added/moved files and the emptied folders, then prints these changes and asks confirmation before applying them to the target folder.

```bash
resync --updated --changed --removed --added --moved --emptied --sample 128k 1m 1m --verbose --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Finds the updated/changed/removed/added/moved files and the emptied folders, sampling at least 128 kilobytes and up to 1 megabyte, then prints these changes and asks confirmation before applying them to the target folder.

```bash
resync --updated --changed --removed --added --emptied --exclude ".git/" --ignore "*.tmp" --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Finds the updated/changed/removed/added files and the emptied folders, excluding ".git/" subfolders and ignoring "\*.tmp" files, prints these changes and asks confirmation before applying them to the target folder.

```bash
resync --updated --changed --removed --added --emptied --select "/A/" --select "/C/" --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Finds the updated/changed/removed/added files and the emptied folders, selecting only the "/A/" and "/C/" folders, prints these changes and asks confirmation before applying them to the target folder.

```bash
resync --updated --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/
```

Finds the updated/removed/added files and previews these changes without applying them to the target folder.

```bash
resync --adjusted 1 --allowed 2 --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Finds the files with a slightly different modification time, prints these changes and asks confirmation before fixing the modification times in the target folder.

```bash
resync --moved --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Finds the moved files and applies these changes to the target folder.

## Version

2.0

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.
