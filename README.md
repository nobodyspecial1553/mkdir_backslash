# mkdir backslash

The origin of this program was to convert the file names of an
erroneously zipped program. It used backslashes instead of
forward slashes, so they unzipped as files only,
no directories. You can use this program to take those files
and fix the output into the correct result.

### Usage:  
`mkdir_backslash [flags] <input directory>`  

### Flags:
`--no-delete:` If the input and output location are the same, the input will be deleted, passing this flag prevents that.  
`-r, --recursive`: Recursively descends subdirectories  
`-d <string>, --output-dir <string>, --output-directory <string>`: Sets output location  
`-h, --help:` Prints help message and exists  

### Build:
```
odin build . -no-assert -o:speed
```
