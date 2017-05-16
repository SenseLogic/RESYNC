# Resync

Fast folder resynchronizer.

## Features

* Efficiently resynchronize big file trees on local disks without computing checksums.
* Processes the updated, changed, moved, removed and added files independently.
* Allows to include/exclude files by name, path or folder, using wildcards.

## Limitations

* The target folder must exist.
* Empty directories and symbolic links are not processed.

## Installation

Install the [DMD 2 compiler](https://dlang.org/download.html).

Build the executable with the following command line :

```bash
dmd resync.d
```

## Command line

```bash
resync [options] SOURCE_FOLDER/ TARGET_FOLDER/
```

### Options

```bash
--updated : detect the updated files
--changed : detect the changed files
--moved : detect the moved files
--removed : detect the removed files
--added : detect the added files
--include SUBFOLDER_FILTER/file_filter : include these file paths
--exclude SUBFOLDER_FILTER/file_filter : exclude these file paths
--include SUBFOLDER_FILTER/ : include these folder paths
--exclude SUBFOLDER_FILTER/ : exclude these folder paths
--include file_filter : include these file names
--exclude file_filter : exclude these file names
--print : print the changes
--confirm : ask confirmation before applying the changes
--preview : preview the changes without applying them
--precision 1 : modification time precision in milliseconds
--prefix 128 : moved file prefix sample size in kilobytes
``` 

### Examples

```bash
resync --changed --removed --added --exclude ".git/" --exclude "*/.git/" --exclude "*.tmp" --print --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Detect the changed, removed and added files, excluding the ".git/" subfolders and the "\*.tmp" file names, then print these changes and ask confirmation before applying them to the target folder.

```bash
resync --changed --removed --added --print --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Detect the changed, removed and added files, then print these changes and ask confirmation before applying them to the target folder.

```bash
resync --updated --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/
```

Detect the changed, removed and added files, then preview these changes without applying them to the target folder.

```bash
resync --moved SOURCE_FOLDER/ TARGET_FOLDER/
```

Detect the moved files, and apply these changes to the target folder.

## Version

0.1

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.
