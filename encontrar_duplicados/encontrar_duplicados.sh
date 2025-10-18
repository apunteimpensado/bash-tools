#!/bin/bash

show_help() {
    cat << 'EOF'
Usage: $0 [OPTIONS] <DIR1> [DIR2]

Finds duplicate files.
- With one directory: finds duplicates within that single directory.
- With two directories: finds duplicates between the two directories.
Uses size and SHA256 hash for comparison.

Options:
    -o, --output FILE     Write results to FILE.
    -x, --exclude PATTERN Exclude files matching PATTERN (glob pattern).
    -i, --include PATTERN Include only files matching PATTERN (glob pattern).
    -m, --min-size BYTES  Skip files smaller than BYTES (default: 1).
    -L, --follow-symlinks Follow symbolic links.
    -h, --help            Show this help message.

EOF
}

dir1=""; dir2=""; output_file=""
exclude_patterns=()
include_patterns=()
min_size=1
follow_symlinks=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output) output_file="$2"; shift 2 ;;
        -x|--exclude) exclude_patterns+=("$2"); shift 2 ;;
        -i|--include) include_patterns+=("$2"); shift 2 ;;
        -m|--min-size) min_size="$2"; shift 2 ;;
        -L|--follow-symlinks) follow_symlinks="-L"; shift ;;
        -h|--help) show_help; exit 0 ;;
        -*) echo "Error: Unknown option: $1" >&2; show_help; exit 1 ;;
        *) if [[ -z "$dir1" ]]; then dir1="$1"; elif [[ -z "$dir2" ]]; then dir2="$1"; else echo "Error: Too many arguments." >&2; exit 1; fi; shift ;;
    esac
done

# Validate min_size is a positive integer
if ! [[ "$min_size" =~ ^[0-9]+$ ]] || [[ "$min_size" -lt 1 ]]; then
    echo "Error: Minimum size must be a positive integer." >&2
    exit 1
fi

# Validate that include and exclude are not used together
if [[ ${#include_patterns[@]} -gt 0 && ${#exclude_patterns[@]} -gt 0 ]]; then
    echo "Error: Cannot use both --include and --exclude options together." >&2
    exit 1
fi

[[ -z "$dir1" || ! -d "$dir1" || ( -n "$dir2" && ! -d "$dir2" ) ]] && { echo "Error: Invalid directory(s)." >&2; exit 1; }

# Check for nested directory relationships
check_directories_relationship() {
    local abs_dir1=$(realpath "$1")
    local abs_dir2=$(realpath "$2")
    
    # Check if directories are the same
    if [[ "$abs_dir1" == "$abs_dir2" ]]; then
        echo "Error: The two directories are the same." >&2
        return 1
    fi
    
    # Check if one directory is parent of another
    if [[ "$abs_dir2" == "$abs_dir1"/* || "$abs_dir1" == "$abs_dir2"/* ]]; then
        echo "Warning: One directory is a subdirectory of the other." >&2
        echo "This may lead to confusing results as files will be compared against themselves." >&2
        echo "Do you want to continue? [y/N]"
        read -r response
        [[ "$response" =~ ^[Yy]$ ]] || { echo "Operation cancelled." >&2; return 1; }
    fi
    
    return 0
}

if [[ -n "$dir2" ]]; then
    if ! check_directories_relationship "$dir1" "$dir2"; then
        exit 1
    fi
fi

if [[ -n "$output_file" ]]; then exec > "$output_file"; fi

mode="within"; [[ -n "$dir2" ]] && mode="between"
resolved_dir1=$(realpath "$dir1")
resolved_dir2=$(realpath "$dir2" 2>/dev/null || echo "")

echo "Searching for duplicates $([[ "$mode" == "between" ]] && echo "between '$resolved_dir1' and '$resolved_dir2'" || echo "within '$resolved_dir1'")."
[[ ${#exclude_patterns[@]} -gt 0 ]] && echo "Excluding patterns: ${exclude_patterns[*]}"
[[ ${#include_patterns[@]} -gt 0 ]] && echo "Including patterns: ${include_patterns[*]}"
[[ "$min_size" -gt 1 ]] && echo "Minimum file size: $min_size bytes"
[[ -n "$follow_symlinks" ]] && echo "Following symbolic links"
echo

# Build find command arguments
find_args=("$follow_symlinks")
find_args+=(-type f)

# Add include patterns if any (mutually exclusive with exclude)
if [[ ${#include_patterns[@]} -gt 0 ]]; then
    find_args+=(-name "${include_patterns[0]}")
    for ((i=1; i<${#include_patterns[@]}; i++)); do
        find_args+=(-o -name "${include_patterns[i]}")
    done
# Otherwise use exclude patterns if any
elif [[ ${#exclude_patterns[@]} -gt 0 ]]; then
    for pattern in "${exclude_patterns[@]}"; do
        find_args+=(-not -name "$pattern")
    done
fi

# Add size condition
find_args+=(-size "+${min_size}c")

# Use -printf for efficiency
find_args+=(-printf "%s %p\0")

if [[ "$mode" == "between" ]]; then
    # For between mode: process directories separately
    declare -A files_by_size_dir1
    declare -A files_by_size_dir2
    
    # Process first directory
    while IFS= read -r -d '' line; do
        size="${line%% *}"
        file_path="${line#* }"
        if [[ -n "${files_by_size_dir1[$size]+isset}" ]]; then
            files_by_size_dir1["$size"]+="|$file_path"
        else
            files_by_size_dir1["$size"]="$file_path"
        fi
    done < <(find "$dir1" "${find_args[@]}" 2>/dev/null)
    
    # Process second directory
    while IFS= read -r -d '' line; do
        size="${line%% *}"
        file_path="${line#* }"
        if [[ -n "${files_by_size_dir2[$size]+isset}" ]]; then
            files_by_size_dir2["$size"]+="|$file_path"
        else
            files_by_size_dir2["$size"]="$file_path"
        fi
    done < <(find "$dir2" "${find_args[@]}" 2>/dev/null)
    
    # Check for duplicates between directories
    found_any=false
    for size in "${!files_by_size_dir1[@]}"; do
        if [[ -n "${files_by_size_dir2[$size]+isset}" ]]; then
            IFS='|' read -ra files_dir1 <<< "${files_by_size_dir1[$size]}"
            IFS='|' read -ra files_dir2 <<< "${files_by_size_dir2[$size]}"
            
            declare -A seen_hashes_dir1
            declare -A seen_hashes
            
            # First, hash all files from dir1 of this size
            for file in "${files_dir1[@]}"; do
                hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
                if [[ -n "$hash" ]]; then
                    seen_hashes_dir1["$hash"]="$file"
                fi
            done
            
            # Then check files from dir2 against dir1 hashes
            for file in "${files_dir2[@]}"; do
                hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
                if [[ -n "$hash" && -n "${seen_hashes_dir1[$hash]+isset}" ]]; then
                    if [[ -z "${seen_hashes[$hash]+isset}" ]]; then
                        echo "Duplicate found between directories:"
                        echo "  DIR1: ${seen_hashes_dir1[$hash]}"
                        echo "  DIR2: $file"
                        seen_hashes["$hash"]=1
                        found_any=true
                    else
                        echo "  DIR2: $file (also duplicates with above)"
                    fi
                fi
            done
            unset seen_hashes_dir1 seen_hashes
            [[ "$found_any" == true ]] && echo
        fi
    done
    
else
    # For within mode: original logic
    declare -A files_by_size
    
    # Process single directory
    while IFS= read -r -d '' line; do
        size="${line%% *}"
        file_path="${line#* }"
        if [[ -n "${files_by_size[$size]+isset}" ]]; then
            files_by_size["$size"]+="|$file_path"
        else
            files_by_size["$size"]="$file_path"
        fi
    done < <(find "$dir1" "${find_args[@]}" 2>/dev/null)
    
    # Check for duplicates within the directory
    found_any=false
    for size in "${!files_by_size[@]}"; do
        IFS='|' read -ra files_array <<< "${files_by_size[$size]}"
        if [[ ${#files_array[@]} -gt 1 ]]; then
            declare -A seen_hashes
            for file in "${files_array[@]}"; do
                hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
                if [[ -n "$hash" ]]; then
                    if [[ -n "${seen_hashes[$hash]+isset}" ]]; then
                        if [[ "${seen_hashes[$hash]}" != "PRINTED" ]]; then
                            echo "Duplicate found:"
                            echo "  - ${seen_hashes[$hash]}"
                            echo "  - $file"
                            seen_hashes["$hash"]="PRINTED"
                            found_any=true
                        else
                            echo "  - $file"
                        fi
                    else
                        seen_hashes["$hash"]="$file"
                    fi
                fi
            done
            unset seen_hashes
            [[ "$found_any" == true ]] && echo
        fi
    done
fi

if [[ "$found_any" == false ]]; then
    echo "No duplicates found."
fi

if [[ -n "$output_file" ]]; then
    echo "Results written to '$output_file'." >&2
fi