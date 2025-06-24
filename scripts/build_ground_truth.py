import os
import json
from pathlib import Path

INPUT_DIR = "component-json"
OUTPUT_FILE = "fuse_ground_truth.json"

def load_components(path):
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"⚠️  Failed to load {path}: {e}")
        return {}

def main():
    ground_truth = {}

    for json_file in Path(INPUT_DIR).glob("*.json"):
        firmware_key = json_file.stem  # e.g., x86_21.02.4
        full_data = load_components(json_file)
        if not full_data:
            continue

        # Only use the 'single_binary' section
        single_bin_data = full_data.get("single_binary", {})
        cleaned = {
            pkg: paths[0] for pkg, paths in single_bin_data.items()
            if isinstance(paths, list) and len([p for p in paths if p.strip()]) == 1
        }

        ground_truth[firmware_key] = cleaned
        print(f"✅ {firmware_key}: {len(cleaned)} single-binary components")

    with open(OUTPUT_FILE, 'w') as out:
        json.dump(ground_truth, out, indent=2)

    print(f"\n🎯 Wrote ground truth to: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
