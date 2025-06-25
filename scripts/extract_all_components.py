#!/usr/bin/env python3
import argparse
import json
import subprocess
from pathlib import Path
from collections import defaultdict
import csv
import hashlib

# Directories containing user-executable binaries
EXEC_DIRS = ('/bin', '/sbin', '/usr/bin', '/usr/sbin')
# Minimum number of images a package must appear as a single unique binary
MIN_IMAGES = 4

def is_elf(path: Path) -> bool:
    """Quick check for ELF magic bytes."""
    try:
        with path.open('rb') as f:
            return f.read(4) == b'\x7fELF'
    except Exception:
        return False


def classify_component_type(path: Path) -> str:
    """Classify non-ELF components via `file` output."""
    try:
        info = subprocess.run(['file', str(path)], capture_output=True, text=True).stdout
    except Exception:
        info = ''
    if path.suffix == '.ko' or 'kernel module' in info:
        return 'kernel_module'
    elif 'ELF' in info and any(str(path).startswith(pref) for pref in ['/lib', '/usr/lib']):
        return 'shared_library'
    elif 'shell script' in info:
        return 'script'
    else:
        return 'other'


def file_hash(path: Path) -> str:
    """Compute SHA256 of a file in chunks."""
    h = hashlib.sha256()
    try:
        with path.open('rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                h.update(chunk)
    except Exception:
        return ''
    return h.hexdigest()


def scan_global_counts(input_dir: Path) -> dict:
    """Count in how many firmware images each package has exactly one user-executable ELF binary, excluding any pkg with a .so file."""
    component_count = defaultdict(int)
    for firmware_root in input_dir.iterdir():
        info_dir = firmware_root / 'usr' / 'lib' / 'opkg' / 'info'
        if not info_dir.is_dir():
            continue
        for list_file in info_dir.glob('*.list'):
            pkg = list_file.stem
            rels = list_file.read_text().splitlines()
            # skip package if any .so anywhere in its file list
            if any('.so' in rel for rel in rels):
                continue
            # collect user executables
            exec_paths = []
            for rel in rels:
                rel_path = rel if rel.startswith('/') else f'/{rel}'
                full = firmware_root / rel_path.lstrip('/')
                if full.is_file() and rel_path.startswith(EXEC_DIRS) and is_elf(full):
                    exec_paths.append(rel_path)
            # count if exactly one unique ELF
            if exec_paths:
                hashes = {file_hash(firmware_root / p.lstrip('/')) for p in exec_paths}
                if len(hashes) == 1:
                    component_count[pkg] += 1
    return component_count


def extract_components(input_dir: Path, component_count: dict) -> dict:
    """Build per-image component lists and categories, excluding pkgs with any .so file."""
    results = {}
    for firmware_root in input_dir.iterdir():
        info_dir = firmware_root / 'usr' / 'lib' / 'opkg' / 'info'
        if not info_dir.is_dir():
            continue
        rel_img = firmware_root.name
        single, multi, rare, excluded = {}, {}, {}, {}
        for list_file in info_dir.glob('*.list'):
            pkg = list_file.stem
            rels = list_file.read_text().splitlines()
            # skip any pkg containing .so anywhere in its file list
            if any('.so' in rel for rel in rels):
                continue
            # gather execs
            exec_paths = []
            for rel in rels:
                rel_path = rel if rel.startswith('/') else f'/{rel}'
                full = firmware_root / rel_path.lstrip('/')
                if full.is_file() and rel_path.startswith(EXEC_DIRS) and is_elf(full):
                    exec_paths.append(rel_path)
            # categorize
            if exec_paths:
                hash_map = defaultdict(list)
                for p in exec_paths:
                    h = file_hash(firmware_root / p.lstrip('/'))
                    hash_map[h].append(p)
                if len(hash_map) == 1:
                    rep = next(iter(hash_map.values()))[0]
                    if component_count.get(pkg, 0) >= MIN_IMAGES:
                        single[pkg] = [rep]
                    else:
                        rare[pkg] = [rep]
                else:
                    multi[pkg] = exec_paths
            else:
                # classify non-exec
                for rel in rels:
                    rel_path = rel if rel.startswith('/') else f'/{rel}'
                    full = firmware_root / rel_path.lstrip('/')
                    if not full.is_file():
                        continue
                    comp_type = classify_component_type(full)
                    excluded.setdefault(comp_type, {}).setdefault(pkg, []).append(rel_path)
        results[rel_img] = {
            'single_binary': single,
            'multi_binary': multi,
            'rare_components': rare,
            'excluded_by_type': excluded
        }
    return results


def build_ground_truth(data: dict) -> dict:
    """Extract ground truth mapping from single_binary entries."""
    return {fw: {pkg: paths[0] for pkg, paths in info['single_binary'].items()} for fw, info in data.items()}


def build_presence_matrix(ground_truth: dict, output_csv: Path) -> None:
    """Generate a presence matrix CSV for single-binary components across firmwares."""
    firmwares = sorted(ground_truth.keys())
    all_pkgs = sorted({pkg for m in ground_truth.values() for pkg in m})
    with output_csv.open('w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Component'] + firmwares)
        for pkg in all_pkgs:
            writer.writerow([pkg] + ['yes' if pkg in ground_truth[fw] else 'no' for fw in firmwares])


def main():
    parser = argparse.ArgumentParser(description='Extract OpenWRT components and generate artifacts')
    parser.add_argument('--input-dir', type=Path, default=Path('openwrt-images'))
    parser.add_argument('--components-output', type=Path, default=Path('all_components.json'))
    parser.add_argument('--ground-truth-output', type=Path, default=Path('fuse_ground_truth.json'))
    parser.add_argument('--matrix-output', type=Path, default=Path('fuse_presence_matrix.csv'))
    args = parser.parse_args()

    counts = scan_global_counts(args.input_dir)
    data = extract_components(args.input_dir, counts)
    args.components_output.write_text(json.dumps(data, indent=2))
    print(f"✅ Components written to {args.components_output}")

    gt = build_ground_truth(data)
    args.ground_truth_output.write_text(json.dumps(gt, indent=2))
    print(f"✅ Ground truth written to {args.ground_truth_output}")

    build_presence_matrix(gt, args.matrix_output)
    print(f"✅ Presence matrix written to {args.matrix_output}")

if __name__ == '__main__':
    main()
