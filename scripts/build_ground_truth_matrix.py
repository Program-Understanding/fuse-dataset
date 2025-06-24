import os
import json
import csv
from pathlib import Path

GROUND_TRUTH_JSON = "fuse_ground_truth.json"
OUTPUT_CSV = "fuse_presence_matrix.csv"

# Load the JSON
with open(GROUND_TRUTH_JSON, "r") as f:
    ground_truth = json.load(f)

# Collect all firmware keys and all unique components
firmwares = sorted(ground_truth.keys())
all_components = set()

for components in ground_truth.values():
    all_components.update(components.keys())

all_components = sorted(all_components)

# Write CSV
with open(OUTPUT_CSV, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["Component"] + firmwares)

    for component in all_components:
        row = [component]
        for fw in firmwares:
            row.append("yes" if component in ground_truth.get(fw, {}) else "no")
        writer.writerow(row)

print(f"✅ Wrote matrix to {OUTPUT_CSV}")
