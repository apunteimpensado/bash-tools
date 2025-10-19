#!/bin/bash

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [DIRECTORY]

Counts file extensions in a directory. By default, searches only top-level directory.

Options:
    -e, --extension EXT    Count only files with specific extension (case-insensitive).
                           Can be specified multiple times for multiple extensions.
    -x, --exclude EXT      Exclude files with specific extension (case-insensitive).
                           Can be specified multiple times for multiple extensions.
    -r, --recursive        Search recursively through subdirectories.
    -d, --depth N          Maximum depth for recursive search (implies -r). Default: unlimited.
    -c, --case-sensitive   Use case-sensitive extension matching (default: case-insensitive).
    -s, --subdirs-only     Search only in subdirectories, exclude the root/top level.
    -o, --output FILE      Write results to FILE instead of standard output.
    -h, --help            Show this help message.

Note: -e and -x options are mutually exclusive.

Examples:
    $0                    # Show all extensions in current directory (top-level only).
    $0 -e zip             # Count only .zip files in current directory (top-level only).
    $0 -e zip -e tar      # Count only .zip and .tar files.
    $0 -x log             # Count all files except .log files.
    $0 -x log -x tmp      # Count all files except .log and .tmp files.
    $0 -r /path/to/dir    # Show all extensions recursively in specified directory.
    $0 -d 2 /path/to/dir  # Search up to 2 levels deep.
    $0 -e tar -r -s /path/to/dir # Count only .tar files in subdirectories (exclude root).
    $0 -x tmp -x temp -r /path/to/dir # Exclude .tmp and .temp files recursively.
    $0 -s /path/to/dir    # Show extensions only in subdirectories of specified directory.
    $0 -r /path/to/dir -o results.txt # Write recursive results to results.txt.
EOF
}

# Default values
directory="."
target_extensions=()
exclude_extensions=()
recursive=false
max_depth=""
case_sensitive=false
subdirs_only=false
output_file=""

validate_extension() {
    local ext="$1"
    local option="$2"
    
    if [[ -z "$ext" ]]; then
        printf "Error: Extension cannot be empty for option %s.\n" "$option" >&2
        exit 1
    fi
    
    if ! [[ "$ext" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        printf "Error: Invalid extension '%s' for option %s. Only alphanumeric, underscore and hyphen characters allowed.\n" "$ext" "$option" >&2
        exit 1
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--extension)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    printf "Error: Option %s requires an argument.\n" "$1" >&2
                    show_help
                    exit 1
                fi
                validate_extension "$2" "$1"
                target_extensions+=("$2")
                shift 2
                ;;
            -x|--exclude)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    printf "Error: Option %s requires an argument.\n" "$1" >&2
                    show_help
                    exit 1
                fi
                validate_extension "$2" "$1"
                exclude_extensions+=("$2")
                shift 2
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -d|--depth)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    printf "Error: Option %s requires a numeric argument.\n" "$1" >&2
                    show_help
                    exit 1
                fi
                if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 1 ]]; then
                    printf "Error: Depth must be a positive integer.\n" >&2
                    exit 1
                fi
                max_depth="$2"
                recursive=true
                shift 2
                ;;
            -c|--case-sensitive)
                case_sensitive=true
                shift
                ;;
            -s|--subdirs-only)
                subdirs_only=true
                recursive=true
                shift
                ;;
            -o|--output)
                if [[ -z "$2" || "$2" =~ ^- ]]; then
                    printf "Error: Option %s requires a filename argument.\n" "$1" >&2
                    show_help
                    exit 1
                fi
                output_file="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                printf "Error: Unknown option: %s\n" "$1" >&2
                show_help
                exit 1
                ;;
            *)
                if [[ "$directory" == "." ]]; then
                    directory="$1"
                else
                    printf "Error: Too many arguments: '%s'\n" "$1" >&2
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

validate_arguments() {
    if [[ ${#target_extensions[@]} -gt 0 && ${#exclude_extensions[@]} -gt 0 ]]; then
        printf "Error: Cannot use both -e/--extension and -x/--exclude options together.\n" >&2
        show_help
        exit 1
    fi

    if [[ ! -d "$directory" ]]; then
        printf "Error: Directory '%s' does not exist.\n" "$directory" >&2
        exit 1
    fi

    if [[ -n "$output_file" ]]; then
        if ! touch "$output_file" 2>/dev/null; then
            printf "Error: Cannot write to output file '%s'\n" "$output_file" >&2
            exit 1
        fi
        > "$output_file"
    fi
}

output() {
    if [[ -n "$output_file" ]]; then
        printf "%s\n" "$1" >> "$output_file"
    else
        printf "%s\n" "$1"
    fi
}

build_find_command() {
    local -a cmd=("$directory" -type f)
    if [[ "$subdirs_only" == true ]]; then
        cmd+=(-mindepth 2)
    elif [[ "$recursive" == false ]]; then
        cmd+=(-maxdepth 1)
    fi
    if [[ -n "$max_depth" ]]; then
        cmd+=(-maxdepth "$max_depth")
    fi
    printf '%s\0' "${cmd[@]}"
}

build_extension_pattern() {
    local mode="$1"; shift
    local extensions=("$@")
    local -a name_flag
    if [[ "$case_sensitive" == true ]]; then
        name_flag=(-name)
    else
        name_flag=(-iname)
    fi

    local -a pattern=( \( )
    for ((i = 0; i < ${#extensions[@]}; i++)); do
        if ((i > 0)); then
            pattern+=(-o)
        fi
        pattern+=("${name_flag[@]}" "*\.${extensions[i]}")
    done
    pattern+=( \) )

    if [[ "$mode" == "exclude" ]]; then
        pattern=(-not "${pattern[@]}")
    fi

    printf '%s\0' "${pattern[@]}"
}

extract_extension() {
    local filename="$1"
    if [[ "$filename" =~ \.([^./]+)$ ]]; then
        printf "%s" "${BASH_REMATCH[1]}"
    else
        printf "no_extension"
    fi
}

process_single_directory() {
    local -n cmd_ref=$1
    declare -A ext_counts
    local total_files=0

    while IFS= read -r -d '' file; do
        local filename=$(basename -- "$file")
        local ext=$(extract_extension "$filename")
        [[ "$case_sensitive" == false ]] && ext=$(tr '[:upper:]' '[:lower:]' <<< "$ext")
        ((ext_counts["$ext"]++))
        ((total_files++))
    done < <(find "${cmd_ref[@]}" -print0 2>/dev/null)

    if ((total_files == 0)); then
        output "No files found."
        return 1
    fi

    local sorted_exts=($(printf "%s\n" "${!ext_counts[@]}" | sort))
    for ext in "${sorted_exts[@]}"; do
        if [[ "$ext" == "no_extension" ]]; then
            output "$(printf "%-20s: %d" "(no extension)" "${ext_counts[$ext]}")"
        else
            output "$(printf "%-20s: %d" "$ext" "${ext_counts[$ext]}")"
        fi
    done
    output "$(printf "%-20s: %d" "TOTAL" "$total_files")"
}

process_recursive_directories() {
    local -n cmd_ref=$1

    while IFS= read -r -d '' file; do
        local dir=$(dirname -- "$file")
        local filename=$(basename -- "$file")
        local ext=$(extract_extension "$filename")
        [[ "$case_sensitive" == false ]] && ext=$(tr '[:upper:]' '[:lower:]' <<< "$ext")
        printf "%s|%s\n" "$dir" "$ext"
    done < <(find "${cmd_ref[@]}" -print0 2>/dev/null) | \
    awk -F'|' '
    {
        dir = $1
        ext = $2
        count[dir][ext]++
        total[dir]++
        seen_dirs[dir] = 1
    }
    END {
        n = asorti(seen_dirs, sorted_dirs)
        for (i = 1; i <= n; i++) {
            d = sorted_dirs[i]
            print "Directory: " d
            m = asorti(count[d], sorted_exts)
            for (j = 1; j <= m; j++) {
                e = sorted_exts[j]
                label = (e == "no_extension") ? "(no extension)" : e
                printf "  %-20s: %d\n", label, count[d][e]
            }
            printf "  %-20s: %d\n\n", "TOTAL", total[d]
        }
    }' | while IFS= read -r line; do
        output "$line"
    done
}

show_search_info() {
    if [[ -n "$output_file" ]]; then
        return
    fi

    local resolved_directory=$(realpath "$directory")

    if [[ "$subdirs_only" == true ]]; then
        printf "Searching in subdirectories only (excluding root level) of: %s\n\n" "$resolved_directory"
    elif [[ "$recursive" == true ]]; then
        if [[ -n "$max_depth" ]]; then
            printf "Searching recursively (max depth %d) in: %s\n\n" "$max_depth" "$resolved_directory"
        else
            printf "Searching recursively in: %s\n\n" "$resolved_directory"
        fi
    else
        printf "Searching top-level in: %s\n\n" "$resolved_directory"
    fi

    if [[ ${#target_extensions[@]} -gt 0 ]]; then
        printf "Filter: including only %s files\n\n" "$(printf ".%s " "${target_extensions[@]}")"
    elif [[ ${#exclude_extensions[@]} -gt 0 ]]; then
        printf "Filter: excluding %s files\n\n" "$(printf ".%s " "${exclude_extensions[@]}")"
    fi
}

main() {
    parse_arguments "$@"
    validate_arguments
    show_search_info

    # Build base find command
    readarray -d '' find_cmd < <(build_find_command)

    # Add filters if needed
    if [[ ${#target_extensions[@]} -gt 0 ]]; then
        readarray -d '' filter_cmd < <(build_extension_pattern "include" "${target_extensions[@]}")
        find_cmd+=("${filter_cmd[@]}")
    elif [[ ${#exclude_extensions[@]} -gt 0 ]]; then
        readarray -d '' filter_cmd < <(build_extension_pattern "exclude" "${exclude_extensions[@]}")
        find_cmd+=("${filter_cmd[@]}")
    fi

    if [[ "$recursive" == true ]]; then
        process_recursive_directories find_cmd
    else
        process_single_directory find_cmd
    fi

    if [[ -n "$output_file" ]]; then
        printf "Results written to: %s\n" "$output_file" >&2
    fi
}

main "$@"