# fuse-dataset

This repository contains scripts for generating the datasets used by the *FUSE* project. It provides tools to download firmware images, extract components and build ground truth data for our experiments.

Dependencies:

* Python 3
* `curl`
* `binwalk` and `unsquashfs` (from `squashfs-tools`)

## OpenWrt dataset

1. **Download and extract images**

   ```bash
   ./openwrt-dataset/scripts/download_openwrt_images.sh
   ```

   The script downloads multiple OpenWrt images for several architectures and versions. Each image is decompressed and its SquashFS filesystem is unpacked under `openwrt-images/<version>-<arch>`.

2. **Generate component metadata**

   ```bash
   ./openwrt-dataset/scripts/extract_all_components.py
   ```

   Running the Python script over the extracted images produces three artifacts in the repository root:

   * `all_components.json` – detailed component information for every image
   * `fuse_ground_truth.json` – mapping of single‑binary packages to their location inside each firmware
   * `fuse_presence_matrix.csv` – CSV matrix showing which single‑binary packages appear in each firmware

These files form the main dataset used by FUSE.

## Case study firmware

To download the small example firmware used in the case study expeirments, run:

```bash
./casestudy-dataset/scripts/download_unifi_image.sh
```

This fetches a Ubiquiti image, extracts it with `binwalk` and unpacks the SquashFS filesystem to `unifi-image/rootfs`.

## Component descriptions

The `descriptions/` directory contains short textual descriptions for common components and variant lists that can be used for data augmentation or labelling.
