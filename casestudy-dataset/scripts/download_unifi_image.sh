#!/bin/bash
set -euo pipefail

# ---------- Config ----------
URL="https://www.ui.com/downloads/unifi/firmware/U2HSR/3.8.3.6587/BZ.ar7240.v3.8.3.6587.170609.0748.bin"
BASE_DIR="${BASE_DIR:-unifi-image}"
OUT_ROOT="${BASE_DIR}/rootfs"
CURL_OPTS=( -fL --retry 3 --retry-connrefused --retry-delay 2 )

# Prefer system binwalk to avoid venv shadowing
BINWALK="${BINWALK:-/usr/bin/binwalk}"
UNSQUASHFS="${UNSQUASHFS:-$(command -v unsquashfs || true)}"
SASQUATCH="${SASQUATCH:-$(command -v sasquatch || true)}"   # optional fallback

copy_root() {
  local src="$1" dst="$2"
  rm -rf "$dst"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -aHAX "$src"/ "$dst"/
  else
    cp -a "$src"/. "$dst"/
  fi
}

# ---------- Preflight ----------
for cmd in curl "${BINWALK}"; do
  command -v "${cmd%% *}" >/dev/null || { echo "Missing dependency: $cmd"; exit 1; }
done

mkdir -p "$BASE_DIR"
BIN_PATH="$BASE_DIR/$(basename "$URL")"

# ---------- Download ----------
echo "📥 Downloading $(basename "$URL") → $BIN_PATH"
if [[ -f "$BIN_PATH" ]]; then
  echo "  File exists; resuming/checking..."
fi
curl "${CURL_OPTS[@]}" -o "$BIN_PATH" "$URL"

# ---------- Extract container with binwalk ----------
echo "📂 Extracting firmware container with binwalk"
# -eM: extract + heuristic recursion, -q: quieten output
"${BINWALK}" -q -eM "$BIN_PATH"

# Binwalk usually creates "_<file>.extracted" in the CWD
EXTRACT_DIR="$(dirname "$BIN_PATH")/_$(basename "$BIN_PATH").extracted"
if [[ ! -d "$EXTRACT_DIR" ]]; then
  # fallback pattern some scripts expect
  EXTRACT_DIR="$BIN_PATH.extracted"
fi
# final discovery pass if still missing
if [[ ! -d "$EXTRACT_DIR" ]]; then
  EXTRACT_DIR="$(find "$BASE_DIR" -maxdepth 1 -type d -name "*$(basename "$BIN_PATH")*.extracted" | head -n 1 || true)"
fi
[[ -d "$EXTRACT_DIR" ]] || { echo "❌ Extract dir not found for $BIN_PATH"; exit 1; }

# ---------- Fast path: binwalk already unpacked a rootfs ----------
if [[ -d "$EXTRACT_DIR/squashfs-root" ]]; then
  echo "✅ Found pre-extracted squashfs-root → copying to $OUT_ROOT"
  copy_root "$EXTRACT_DIR/squashfs-root" "$OUT_ROOT"
  echo "✅ Firmware rootfs extracted to $OUT_ROOT"
  exit 0
fi

# ---------- Locate best SquashFS candidate ----------
echo "🔎 Searching for SquashFS images in $EXTRACT_DIR"
mapfile -t SQUASHES < <(find "$EXTRACT_DIR" -type f -name '*.squashfs' -printf '%s %p\n' | sort -nr | awk '{print $2}')
if [[ ${#SQUASHES[@]} -eq 0 ]]; then
  echo "⚠️  No *.squashfs files found. Directory contents:"
  find "$EXTRACT_DIR" -maxdepth 2 -type f -printf '  %p\n' || true
  exit 1
fi
SQUASHFS_FILE="${SQUASHES[0]}"
echo "  ✓ Selected: $SQUASHFS_FILE"

# ---------- Unpack SquashFS (tool-based) ----------
rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"

echo "📂 Unpacking SquashFS → $OUT_ROOT"
if [[ -n "${UNSQUASHFS:-}" ]] && unsquashfs -version >/dev/null 2>&1; then
  if unsquashfs -d "$OUT_ROOT" "$SQUASHFS_FILE"; then
    echo "✅ Firmware rootfs extracted to $OUT_ROOT"
    exit 0
  else
    echo "⚠️  unsquashfs failed; will try sasquatch if available"
  fi
fi

if [[ -n "${SASQUATCH:-}" ]]; then
  echo "🪓 Falling back to sasquatch (legacy LZMA etc.)"
  tmpdir="$(mktemp -d)"
  ( cd "$tmpdir" && "$SASQUATCH" "$SQUASHFS_FILE" )
  if [[ -d "$tmpdir/squashfs-root" ]]; then
    copy_root "$tmpdir/squashfs-root" "$OUT_ROOT"
    rm -rf "$tmpdir"
    echo "✅ Firmware rootfs extracted to $OUT_ROOT (sasquatch)"
    exit 0
  else
    echo "❌ sasquatch did not produce expected output."
    ls -la "$tmpdir" || true
    rm -rf "$tmpdir"
  fi
fi

echo "❌ Could not extract SquashFS with available tools."
echo "   Try installing a newer unsquashfs (squashfs-tools-ng) or building sasquatch."
exit 1
