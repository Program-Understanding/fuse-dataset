#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def collect_counts(json_files):
    counts = {}
    for path in json_files:
        with open(path, 'r') as f:
            data = json.load(f)
        entries = data.get('single_binary', [])
        for entry in entries:
            counts[entry] = counts.get(entry, 0) + 1
    return counts


def filter_files(json_files, counts, output_dir, inplace):
    for path in json_files:
        with open(path, 'r') as f:
            data = json.load(f)
        entries = data.get('single_binary', [])
        filtered = [e for e in entries if counts.get(e, 0) > 2]
        data['single_binary'] = filtered

        target = path if inplace else output_dir / path.name
        with open(target, 'w') as f:
            json.dump(data, f, indent=2, sort_keys=True)


def main():
    parser = argparse.ArgumentParser(
        description="Remove single_binary entries appearing in two or fewer firmware samples.")
    parser.add_argument('directory', help='Directory with JSON files to process')
    parser.add_argument('-o', '--output', help='Output directory for filtered files')
    parser.add_argument('--inplace', action='store_true',
                        help='Modify files in place instead of writing to output directory')
    args = parser.parse_args()

    base = Path(args.directory)
    json_files = sorted(base.glob('*.json'))
    counts = collect_counts(json_files)

    output_dir = base if args.inplace else Path(args.output or base)
    if not args.inplace:
        output_dir.mkdir(parents=True, exist_ok=True)

    filter_files(json_files, counts, output_dir, args.inplace)


if __name__ == '__main__':
    main()
