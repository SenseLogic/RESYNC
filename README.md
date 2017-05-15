# Resync

Versatile local folder synchronizer.

## Features

* Processes the updated, changed, moved, removed and added files independently.

## Limitations

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
--include SUBFOLDER/ : include this subfolder
--exclude SUBFOLDER/ : exclude this subfolder
--include *.ext : include these file names
--exclude *.ext : exclude these file names
--print : print the changes
--confirm : ask confirmation before applying the changes
--preview : preview the changes without applying them
--precision 1 : modification time precision in milliseconds
--prefix 128 : moved file prefix sample size in kilobytes
``` 

### Examples

```bash
resync --changed --removed --added --exclude .git/ --print --confirm SOURCE_FOLDER/ TARGET_FOLDER/
```

Detect the changed, removed and added files, excluding the ".git/" folder, print these changes, and ask confirmation before applying them.

```bash
resync --changed --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/
```

Detect the changed, removed and added files, and preview these changes without applying them.

```bash
resync --changed --removed --added SOURCE_FOLDER/ TARGET_FOLDER/
```

Detect the changed, removed and added files, and apply these changes.

```bash
resync --updated SOURCE_FOLDER/ TARGET_FOLDER/
```

Detect the updated files, and apply these changes.

```bash
resync --moved SOURCE_FOLDER/ TARGET_FOLDER/
```

Detect the moved files, and apply these changes.

## Version

0.1

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.
