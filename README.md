# fuse-dataset

This repository contains tools for processing firmware sample metadata stored as JSON files.

## Filtering `single_binary` entries

Use `scripts/filter_single_binary.py` to remove `single_binary` values that occur in two or fewer firmware samples across all JSON files in a directory.

```
python scripts/filter_single_binary.py <json_directory> --inplace
```

By default the script writes the filtered files to the specified directory when `--inplace` is used. Without `--inplace`, use `-o <output_dir>` to specify where filtered files should be written.


## Case study firmware

Run `casestudy-dataset/scripts/download_unifi_image.sh` to fetch and extract the
Ubiquiti firmware used for case studies. The script downloads the binary,
extracts it with `binwalk`, and unpacks the SquashFS filesystem under
`unifi-image/rootfs`.
