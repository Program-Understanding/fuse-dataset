#!/bin/bash
set -euo pipefail

BASE_DIR="openwrt-images"

# Map of arch/version → download URL
declare -A URLS=(
  # x86
  ["x86/21.02.4"]="https://mirror-03.infra.openwrt.org/releases/21.02.4/targets/x86/generic/openwrt-21.02.4-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/23.05.2"]="https://mirror-03.infra.openwrt.org/releases/23.05.2/targets/x86/generic/openwrt-23.05.2-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/24.10.0"]="https://mirror-03.infra.openwrt.org/releases/24.10.0/targets/x86/generic/openwrt-24.10.0-x86-generic-generic-squashfs-rootfs.img.gz"

  # ARM (armvirt / armsr)
  ["ARM/21.02.4"]="https://mirror-03.infra.openwrt.org/releases/21.02.4/targets/armvirt/64/openwrt-21.02.4-armvirt-64-rootfs-squashfs.img.gz"
  ["ARM/23.05.2"]="https://mirror-03.infra.openwrt.org/releases/23.05.2/targets/armsr/armv7/openwrt-23.05.2-armsr-armv7-generic-squashfs-rootfs.img.gz"
  ["ARM/24.10.0"]="https://mirror-03.infra.openwrt.org/releases/24.10.0/targets/armsr/armv7/openwrt-24.10.0-armsr-armv7-generic-squashfs-rootfs.img.gz"

  # MIPS (malta)
  ["MIPS/21.02.4"]="https://mirror-03.infra.openwrt.org/releases/21.02.4/targets/malta/be/openwrt-21.02.4-malta-be-rootfs-squashfs.img.gz"
  ["MIPS/23.05.2"]="https://mirror-03.infra.openwrt.org/releases/23.05.2/targets/malta/be/openwrt-23.05.2-malta-be-rootfs-squashfs.img.gz"
  ["MIPS/24.10.0"]="https://mirror-03.infra.openwrt.org/releases/24.10.0/targets/malta/be/openwrt-24.10.0-malta-be-rootfs-squashfs.img.gz"
)

mkdir -p "$BASE_DIR"

for key in $(printf '%s\n' "${!URLS[@]}" | sort); do
  arch="${key%%/*}"
  version="${key##*/}"
  name="${version}-${arch}"

  url="${URLS[$key]}"
  gz_path="$BASE_DIR/${name}.img.gz"
  img_path="${gz_path%.gz}"

  echo "📥 Downloading ${name}.img.gz"
  curl -L -o "$gz_path" "$url"

  echo "📦 Decompressing ${name}.img.gz"
  gunzip -f "$gz_path"

  echo "📂 Unpacking SquashFS into $BASE_DIR/${name}"
  unsquashfs -d "$BASE_DIR/${name}" "$img_path" \
    || echo "⚠️ Warning: non-zero exit (likely /dev files)"

  echo "🧹 Removing raw image ${name}.img"
  rm -f "$img_path"

  echo "✅ Done: $name"
done

echo "🎉 All images are in $BASE_DIR, each extracted under its own <version>-<arch> folder."
