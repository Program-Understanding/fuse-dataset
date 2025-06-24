#!/bin/bash

# USAGE: ./classify_multi_firmware.sh <path-to-squashfs-root1> [<path-to-squashfs-root2> ...]
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path-to-squashfs-root1> [<path-to-squashfs-root2> ...]"
    exit 1
fi

# Global maps
declare -A global_counts          # component_key -> number of images seen
declare -A component_paths        # component_key -> representative relative path
declare -A component_pkgs         # component_key -> package name

# Iterate each firmware root
for ROOT in "$@"; do
    LIST_DIR="$ROOT/usr/lib/opkg/info"
    if [[ ! -d "$LIST_DIR" ]]; then
        echo "Error: '$LIST_DIR' not found in $ROOT. Skipping."
        continue
    fi

    # Track components seen in this image only once
    declare -A seen_in_image

    # Scan installed package file lists
    for list_file in "$LIST_DIR"/*.list; do
        pkg=$(basename "$list_file" .list)
        [[ -f "$list_file" ]] || continue

        while read -r rel_path; do
            [[ "$rel_path" != /* ]] && rel_path="/$rel_path"
            full_path="$ROOT$rel_path"
            [[ -f "$full_path" ]] || continue

            # Only consider user-facing ELF binaries
            if [[ "$rel_path" =~ ^/(bin|sbin|usr/bin|usr/sbin)/ ]] && file --brief --mime-type "$full_path" | grep -q "application/x-executable"; then
                hash=$(sha256sum "$full_path" | cut -d ' ' -f1)
                key="$pkg:$hash"
                if [[ -z "${seen_in_image[$key]}" ]]; then
                    seen_in_image[$key]=1
                    # Record representative path and package
                    if [[ -z "${component_paths[$key]}" ]]; then
                        component_paths[$key]="$rel_path"
                        component_pkgs[$key]="$pkg"
                    fi
                fi
            fi
        done < "$list_file"
    done

    # Update global counts
    for key in "${!seen_in_image[@]}"; do
        global_counts[$key]=$(( ${global_counts[$key]:-0} + 1 ))
    done

    # unset local map for next iteration
    unset seen_in_image
done

# Classification: frequent (>=3 images) vs infrequent (<3)
declare -A single_binary
declare -A infrequent_binary
for key in "${!global_counts[@]}"; do
    count=${global_counts[$key]}
    pkg=${component_pkgs[$key]}
    path=${component_paths[$key]}
    if (( count >= 3 )); then
        single_binary["$pkg"]+="$path"$'\n'
    else
        infrequent_binary["$pkg"]+="$path"$'\n'
    fi
done

# Emit JSON
emit_group_json() {
    local -n group=$1
    local indent=$2
    local first=1
    for pkg in "${!group[@]}"; do
        [[ $first -eq 0 ]] && echo ","
        echo -n "$indent\"$pkg\": ["
        IFS=$'\n' read -d '' -r -a paths <<< "${group[$pkg]}"
        for i in "${!paths[@]}"; do
            [[ $i -ne 0 ]] && echo -n ", "
            echo -n "\"${paths[$i]}\""
        done
        echo -n "]"
        first=0
    done
}

echo "{"

echo "  \"single_binary\": {"
emit_group_json single_binary "    "
echo
"  },"

echo "  \"infrequent_binary\": {"
emit_group_json infrequent_binary "    "
echo
"  }"

echo "}"
