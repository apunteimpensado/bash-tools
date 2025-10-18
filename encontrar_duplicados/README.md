Herramienta escrita en Bash para encontrar duplicados dentro de un directorio, o entre dos directorios diferentes.

## Basic usage with new options

./encontrar_duplicados.sh -x '\*.tmp' -m 1024 /path/to/dir

## Multiple exclude patterns and follow symlinks

./encontrar*duplicados.sh -x '*.tmp' -x '\_.log' -m 4096 -L /path/to/dir

## Include specific file types

./encontrar*duplicados.sh -i '*.jpg' /path/to/dir
./encontrar*duplicados.sh -i '*.mp4' -i '\*.mov' /path/dir1 /path/dir2

## Between two directories with exclusions

./encontrar_duplicados.sh -x "\*.jpg" -m 1024 /path/dir1 /path/dir2

## Output to file with all options

./encontrar_duplicados.sh -o results.txt -x "\*.tmp" -m 2048 -L /path/to/dir
