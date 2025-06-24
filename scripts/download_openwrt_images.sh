#!/bin/bash

set -euo pipefail

BASE_DIR="openwrt-images"

declare -A URLS=(
  # x86
  ["x86/21.02.4"]="https://mirror-03.infra.openwrt.org/releases/21.02.4/targets/x86/generic/openwrt-21.02.4-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/23.05.2"]="https://mirror-03.infra.openwrt.org/releases/23.05.2/targets/x86/generic/openwrt-23.05.2-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/24.10.0"]="https://mirror-03.infra.openwrt.org/releases/24.10.0/targets/x86/generic/openwrt-24.10.0-x86-generic-generic-squashfs-rootfs.img.gz"

  # ARM (armvirt / armsr)
  ["armvirt/21.02.4"]="https://mirror-03.infra.openwrt.org/releases/21.02.4/targets/armvirt/64/openwrt-21.02.4-armvirt-64-rootfs-squashfs.img.gz"
  ["armvirt/23.05.2"]="https://mirror-03.infra.openwrt.org/releases/23.05.2/targets/armsr/armv7/openwrt-23.05.2-armsr-armv7-generic-squashfs-rootfs.img.gz"
  ["armvirt/24.10.0"]="https://mirror-03.infra.openwrt.org/releases/24.10.0/targets/armsr/armv7/openwrt-24.10.0-armsr-armv7-generic-squashfs-rootfs.img.gz"

  # MIPS (malta)
  ["malta/21.02.4"]="https://mirror-03.infra.openwrt.org/releases/21.02.4/targets/malta/be/openwrt-21.02.4-malta-be-rootfs-squashfs.img.gz"
  ["malta/23.05.2"]="https://mirror-03.infra.openwrt.org/releases/23.05.2/targets/malta/be/openwrt-23.05.2-malta-be-rootfs-squashfs.img.gz"
  ["malta/24.10.0"]="https://mirror-03.infra.openwrt.org/releases/24.10.0/targets/malta/be/openwrt-24.10.0-malta-be-rootfs-squashfs.img.gz"
)

mkdir -p "$BASE_DIR"

for key in $(printf "%s\n" "${!URLS[@]}" | sort); do
  url="${URLS[$key]}"
  dest_dir="$BASE_DIR/$key"
  mkdir -p "$dest_dir"
  filename="${url##*/}"
  img_file="${filename%.gz}"

  echo "📥 Downloading $filename to $dest_dir"
  curl -L -o "$dest_dir/$filename" "$url"

  echo "📦 Extracting $filename..."
  gunzip -f "$dest_dir/$filename"

  echo "📂 Unpacking SquashFS from $img_file..."
  unsquashfs -d "$dest_dir/squashfs-root" "$dest_dir/$img_file" || echo "⚠️  Warning: non-zero exit code (likely due to /dev files)"

  echo "🧹 Cleaning up $img_file"
  rm -f "$dest_dir/$img_file"

  echo "✅ Done: $key"
done

echo "🎉 All builds downloaded and extracted under: $BASE_DIR"
