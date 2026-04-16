# fuse-dataset

This repository contains the datasets and scripts for the paper "Strings-Only File Localization in Firmware Images." It includes pre-generated ground truth data, component metadata, and tools to download and extract firmware images.

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
   python3 openwrt-dataset/scripts/extract_all_components.py
   ```

   Running the Python script over the extracted images produces three artifacts under `openwrt-dataset/`:

   * `all_components.json` – detailed component information for every image
   * `fuse_ground_truth.json` – mapping of single‑binary packages to their location inside each firmware
   * `fuse_presence_matrix.csv` – CSV matrix showing which single‑binary packages appear in each firmware

Pre-generated versions of these files are included in `openwrt-dataset/` and form the main dataset used by FUSE.

## Case study firmware

To download the firmware used in the case study experiments, run:

```bash
./casestudy-dataset/scripts/download_unifi_image.sh
```

This fetches the Ubiquiti UAP-Outdoor (U2HSR) firmware image (`BZ.ar7240.v3.8.3.6587`), extracts it with `binwalk`, and unpacks the SquashFS filesystem to `unifi-image/rootfs`.

## Component descriptions

The `descriptions/` directory contains natural-language descriptions and query variants for each evaluated component. It includes:

* `component_descriptions.json` – canonical capability descriptions for all 26 OpenWrt components
* `variant-descriptions.json` – 11 paraphrase variants for the five robustness-study components
* `case_study_variants.json` – 11 query variants for the case study targets (`dropbear`, `tinysshd`)
* `case_study_ground_truth.json` – ground truth binary paths for the UAP-outdoor case study collections
* Per-component description files (`dropbear-descriptions.json`, `tinysshd-descriptions.json`, etc.)
