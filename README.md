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

Install the [DMD 2 compiler](https://dlang.org/download.html) (choosing the MinGW setup option on Windows).

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
--updated : detect the updated files
--changed : detect the changed files
--moved : detect the moved files
--removed : detect the removed files
--added : detect the added files
--emptied : detect the emptied folders
--include SUBFOLDER_FILTER/file_filter : include these file paths
--exclude SUBFOLDER_FILTER/file_filter : exclude these file paths
--include SUBFOLDER_FILTER/ : include these folder paths
--exclude SUBFOLDER_FILTER/ : exclude these folder paths
--include file_filter : include these file names
--exclude file_filter : exclude these file names
--sample 0 1M all : minimum, medium and maximum sample size (B for bytes, K for kilobytes, M for megabytes, G for gigabytes)
--allowed 2 : maximum allowed modification time offset in milliseconds
--abort : abort on file copy errors
--verbose : show the processing messages
--confirm : print the changes and ask confirmation before applying them
--preview : preview the changes without applying them
```

### Examples

```bash
resync --create --updated --changed --removed --added --emptied --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Creates the target folder if it doesn't exist, detects the updated/changed/removed/added files and the emptied folders, prints these changes and asks confirmation before applying them to the target folder.

```bash
resync --updated --changed --removed --added --moved --emptied --verbose --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Detects the updated/changed/removed/added/moved files and the emptied folders, then prints these changes and asks confirmation before applying them to the target folder.

```bash
resync --updated --changed --removed --added --emptied --exclude ".git/" --exclude "*/.git/" --exclude "*.tmp" --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Detects the updated/changed/removed/added files and the emptied folders, excluding the ".git/" subfolders and "\*.tmp" file names, prints these changes and asks confirmation before applying them to the target folder.

```bash
resync --updated --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/
```

Detects the updated/removed/added files and previews these changes without applying them to the target folder.

```bash
resync --adjusted 1 --allowed 2 --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Detects the files with a slightly different modification time, prints these changes and asks confirmation before fixing the modification times in the target folder.

```bash
resync --moved --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Detects the moved files and applies these changes to the target folder.

## Version

1.0

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.
