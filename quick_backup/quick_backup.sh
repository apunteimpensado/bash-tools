#!/bin/bash

# Description: Creates a backup of the current working directory (cwd) to a specified location.
#              Includes hidden files. Stops on errors.
# Usage: ./script_backup.sh [backup_destination]

set -e

currentdir=$(pwd)
dir_name=$(basename "$currentdir")
timestamp=$(date +%d-%m-%Y_%H-%M-%S)

# Use provided directory or default to user's home
backup_dest="${1:-$HOME}"
backup_dest="${backup_dest/%\//}"
backup_file="${backup_dest}/${dir_name}_backup_${timestamp}.tar"

# Check if destination exists and is writable
if [ ! -d "$backup_dest" ]; then
    echo "Error: Destination directory does not exist: $backup_dest" >&2
    exit 1
fi

if [ ! -w "$backup_dest" ]; then
    echo "Error: No write permission in destination directory: $backup_dest" >&2
    exit 1
fi

echo "Hi ${USER^}"
echo "Creating backup of: ${currentdir}"
echo "Saving to: ${backup_file}"

tar -cf "$backup_file" -C "$(dirname "$currentdir")" "$dir_name"

echo "Backup created successfully!"
echo "Location: ${backup_file}"
exit 0