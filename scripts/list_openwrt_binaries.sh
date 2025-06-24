#!/bin/bash

if [[ -z "$1" ]]; then
    echo "Usage: $0 <path-to-squashfs-root>"
    exit 1
fi

ROOT="$1"
LIST_DIR="$ROOT/usr/lib/opkg/info"

if [[ ! -d "$LIST_DIR" ]]; then
    echo "Error: '$LIST_DIR' not found. Are you sure this is an OpenWRT rootfs?"
    exit 1
fi

declare -A pkg_binaries
declare -A seen_hashes

declare -A single_binary
declare -A multi_binary

declare -A excluded_by_type_kernel_module
declare -A excluded_by_type_shared_library
declare -A excluded_by_type_script
declare -A excluded_by_type_other

# Classify file type
classify_component_type() {
    local path="$1"
    local info
    info=$(file "$path")

    if [[ "$path" == *.ko || "$info" == *"kernel module"* ]]; then
        echo "kernel_module"
    elif [[ "$info" == *"ELF"* && "$path" =~ ^/(lib|usr/lib)/ ]]; then
        echo "shared_library"
    elif [[ "$info" == *"POSIX shell script"* || "$info" == *"Bourne-Again shell script"* ]]; then
        echo "script"
    else
        echo "other"
    fi
}

# Iterate over all installed package file lists
for list_file in "$LIST_DIR"/*.list; do
    pkg=$(basename "$list_file" .list)
    [[ -f "$list_file" ]] || continue

    while read -r rel_path; do
        [[ "$rel_path" != /* ]] && rel_path="/$rel_path"
        full_path="$ROOT$rel_path"
        [[ -f "$full_path" ]] || continue

        # Check if user-facing ELF binary
        if [[ "$rel_path" =~ ^/(bin|sbin|usr/bin|usr/sbin)/ ]] && file "$full_path" | grep -q "ELF"; then
            hash=$(sha256sum "$full_path" | cut -d ' ' -f1)
            key="$pkg:$hash"
            if [[ -z "${seen_hashes[$key]}" ]]; then
                seen_hashes[$key]=1
                pkg_binaries["$pkg"]+="$rel_path"$'\n'
            fi
        fi
    done < "$list_file"
done

# Classify packages into single/multi binary
for pkg in "${!pkg_binaries[@]}"; do
    IFS=$'\n' read -d '' -r -a paths <<< "${pkg_binaries[$pkg]}"
    if [[ ${#paths[@]} -eq 1 ]]; then
        single_binary["$pkg"]="${paths[0]}"
    elif [[ ${#paths[@]} -gt 1 ]]; then
        multi_binary["$pkg"]="${paths[*]}"
    fi
done

# Classify excluded packages by type
for list_file in "$LIST_DIR"/*.list; do
    pkg=$(basename "$list_file" .list)
    [[ -f "$list_file" ]] || continue

    # Skip if already handled
    [[ -n "${pkg_binaries[$pkg]}" ]] && continue

    while read -r rel_path; do
        [[ "$rel_path" != /* ]] && rel_path="/$rel_path"
        full_path="$ROOT$rel_path"
        [[ -f "$full_path" ]] || continue

        type=$(classify_component_type "$full_path")
        case "$type" in
            kernel_module)
                excluded_by_type_kernel_module["$pkg"]+="$rel_path"$'\n';;
            shared_library)
                excluded_by_type_shared_library["$pkg"]+="$rel_path"$'\n';;
            script)
                excluded_by_type_script["$pkg"]+="$rel_path"$'\n';;
            *)
                excluded_by_type_other["$pkg"]+="$rel_path"$'\n';;
        esac
    done < "$list_file"
done

# Emit group JSON utility
emit_group_json() {
    local -n group=$1
    local indent=$2
    local first=1
    for pkg in "${!group[@]}"; do
        [[ $first -eq 0 ]] && echo ","
        echo -n "$indent\"$pkg\": "
        IFS=$'\n' read -d '' -r -a paths <<< "${group[$pkg]}"
        if [[ ${#paths[@]} -eq 1 ]]; then
            echo -n "[\"${paths[0]}\"]"
        else
            echo -n "["
            for i in "${!paths[@]}"; do
                [[ $i -ne 0 ]] && echo -n ", "
                echo -n "\"${paths[$i]}\""
            done
            echo -n "]"
        fi
        first=0
    done
}

# Emit excluded_by_type
emit_excluded_by_type_json() {
    echo "  \"excluded_by_type\": {"
    local first_type=1
    for group in kernel_module shared_library script other; do
        local -n map="excluded_by_type_$group"
        [[ ${#map[@]} -eq 0 ]] && continue
        [[ $first_type -eq 0 ]] && echo ","
        echo "    \"$group\": {"
        emit_group_json map "      "
        echo
        echo -n "    }"
        first_type=0
    done
    echo
    echo "  }"
}

# Emit full JSON
echo "{"

echo "  \"single_binary\": {"
emit_group_json single_binary "    "
echo
echo "  },"

echo "  \"multi_binary\": {"
emit_group_json multi_binary "    "
echo
echo "  },"

emit_excluded_by_type_json

echo
echo "}"
