#!/bin/bash

set -euo pipefail

INPUT_DIR="openwrt-images"
OUTPUT_DIR="component-json"

mkdir -p "$OUTPUT_DIR"

SCRIPT_PATH="./scripts/list_openwrt_binaries.sh"

if [[ ! -x "$SCRIPT_PATH" ]]; then
    echo "❌ Error: $SCRIPT_PATH not found or not executable"
    exit 1
fi

for squashfs in $(find "$INPUT_DIR" -type d -name squashfs-root); do
    version_dir=$(dirname "$squashfs")
    rel_path="${version_dir#$INPUT_DIR/}"
    out_file="$OUTPUT_DIR/${rel_path//\//_}.json"

    echo "🔍 Processing $rel_path"
    "$SCRIPT_PATH" "$squashfs" > "$out_file"
    echo "✅ Wrote: $out_file"
done

echo "🎉 All firmware samples processed."
