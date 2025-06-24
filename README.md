# fuse-dataset

This repository contains tools for processing firmware sample metadata stored as JSON files.

## Filtering `single_binary` entries

Use `scripts/filter_single_binary.py` to remove `single_binary` values that occur in two or fewer firmware samples across all JSON files in a directory.

```
python scripts/filter_single_binary.py <json_directory> --inplace
```

By default the script writes the filtered files to the specified directory when `--inplace` is used. Without `--inplace`, use `-o <output_dir>` to specify where filtered files should be written.

