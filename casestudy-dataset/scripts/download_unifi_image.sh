#!/bin/bash
set -euo pipefail

# Firmware download URL
URL="https://www.ui.com/downloads/unifi/firmware/BZ2/3.8.3.6587/BZ.ar7240.v3.8.3.6587.170609.0748.bin"

# Directory to hold the downloaded image and extracted files
BASE_DIR="unifi-image"
mkdir -p "$BASE_DIR"

BIN_PATH="$BASE_DIR/$(basename "$URL")"

# Download the firmware image
echo "📥 Downloading $(basename "$URL")"
curl -L -o "$BIN_PATH" "$URL"

echo "📂 Extracting firmware with binwalk"
binwalk -e "$BIN_PATH"

EXTRACT_DIR="${BIN_PATH}.extracted"

# Find the SquashFS partition produced by binwalk
SQUASHFS_FILE=$(find "$EXTRACT_DIR" -name '*.squashfs' | head -n 1)
if [ -z "$SQUASHFS_FILE" ]; then
  echo "⚠️  SquashFS archive not found in $EXTRACT_DIR"
  exit 1
fi

echo "📂 Unpacking SquashFS to $BASE_DIR/rootfs"
unsquashfs -d "$BASE_DIR/rootfs" "$SQUASHFS_FILE" \
  || echo "⚠️  Warning: non-zero exit (likely permissions issues)"

echo "✅ Firmware extracted to $BASE_DIR/rootfs"
