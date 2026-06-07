#!/usr/bin/env python3
"""Generate direction fixes for kanji with unknown directions by analyzing path geometry."""

import json
import re
import os
import subprocess

PROJECT = "/var/home/meddle/development/elixir/medoru"

def parse_path_numbers(path_d):
    """Extract all numbers from an SVG path."""
    return [float(n) for n in re.findall(r"-?[\d.]+", path_d)]


def get_path_bbox(path_d):
    """Get bounding box of an SVG path (approximate, using all coordinates)."""
    nums = parse_path_numbers(path_d)
    if len(nums) < 2:
        return None
    xs = nums[0::2]
    ys = nums[1::2]
    return min(xs), min(ys), max(xs), max(ys)


def infer_type_from_bbox(path_d):
    """Infer stroke type from path bounding box."""
    bbox = get_path_bbox(path_d)
    if not bbox:
        return "unknown"
    min_x, min_y, max_x, max_y = bbox
    width = max_x - min_x
    height = max_y - min_y
    if width > height * 2:
        return "horizontal"
    elif height > width * 2:
        return "vertical"
    elif width > 0 and height > 0:
        return "diagonal"
    return "unknown"


def infer_direction_from_path(path_d):
    """Infer stroke direction from path start/end points.
    For closed paths (ends with Z), returns unknown since direction is ambiguous."""
    path_d = path_d.strip()
    if path_d.endswith("Z") or path_d.endswith("z"):
        return "unknown"
    
    # Find start point
    match = re.match(r"[Mm]\s*([\d.]+)[,\s]+([\d.]+)", path_d)
    if not match:
        return "unknown"
    start_x = float(match.group(1))
    start_y = float(match.group(2))
    
    # Find last coordinate pair before any trailing command
    coords = re.findall(r"-?[\d.]+[\s,]+-?[\d.]+", path_d[match.end():])
    if not coords:
        return "unknown"
    
    last = coords[-1]
    parts = re.findall(r"-?[\d.]+", last)
    if len(parts) < 2:
        return "unknown"
    
    end_x = float(parts[-2])
    end_y = float(parts[-1])
    
    dx = end_x - start_x
    dy = end_y - start_y
    abs_dx = abs(dx)
    abs_dy = abs(dy)
    
    if abs_dx < 1 and abs_dy < 1:
        return "unknown"
    elif abs_dx > abs_dy * 2:
        return "left-to-right" if dx > 0 else "right-to-left"
    elif abs_dy > abs_dx * 2:
        return "top-to-bottom" if dy > 0 else "bottom-to-top"
    else:
        if dx > 0 and dy > 0:
            return "top-left-to-bottom-right"
        elif dx < 0 and dy > 0:
            return "top-right-to-bottom-left"
        elif dx > 0 and dy < 0:
            return "bottom-left-to-top-right"
        else:
            return "bottom-right-to-top-left"


def detect_coordinate_system(paths):
    """Detect if paths use makemeahanzi (1024) or KanjiVG (109) coordinates."""
    all_nums = []
    for p in paths:
        nums = parse_path_numbers(p)
        all_nums.extend(nums)
    if not all_nums:
        return 109
    max_val = max(abs(n) for n in all_nums)
    if max_val > 200:
        return 1024
    return 109


# Read the characters that need fixing
with open("/tmp/chars_strokes.txt", "r", encoding="utf-8") as f:
    chars = set(f.read().strip().split("\n"))

# Query DB for kanji with unknown type/direction
elixir_script = """
alias Medoru.Repo
alias Medoru.Content.Kanji

all = Repo.all(Kanji)

unknown = Enum.filter(all, fn k ->
  strokes = get_in(k.stroke_data, ["strokes"])
  is_list(strokes) and is_map(hd(strokes)) and (hd(strokes)["type"] == "unknown" or hd(strokes)["direction"] == "unknown")
end)

export = Enum.map(unknown, fn k ->
  %{
    character: k.character,
    strokes: k.stroke_data["strokes"]
  }
end)

File.write!("/tmp/unknown_strokes.json", Jason.encode!(export))
IO.puts("Exported #{length(unknown)} kanji with unknown strokes")
"""

with open("/tmp/export_unknown.exs", "w", encoding="utf-8") as f:
    f.write(elixir_script)

subprocess.run(["mix", "run", "/tmp/export_unknown.exs"], cwd=PROJECT, check=True)

with open("/tmp/unknown_strokes.json", "r", encoding="utf-8") as f:
    unknown_kanji = json.load(f)

print(f"Loaded {len(unknown_kanji)} kanji with unknown strokes")

fixes = {}
for k in unknown_kanji:
    char = k["character"]
    if char not in chars:
        continue
    
    paths = [s["path"] for s in k["strokes"]]
    coord_system = detect_coordinate_system(paths)
    
    improved_strokes = []
    for s in k["strokes"]:
        path = s["path"]
        order = s["order"]
        stroke_type = infer_type_from_bbox(path)
        direction = infer_direction_from_path(path)
        improved_strokes.append({
            "path": path,
            "order": order,
            "type": stroke_type,
            "direction": direction,
        })
    
    if coord_system == 1024:
        bounds = {"width": 1024, "height": 1024, "viewBox": "0 0 1024 1024"}
    else:
        bounds = {"width": 109, "height": 109, "viewBox": "0 0 109 109"}
    
    fixes[char] = {
        "strokes": improved_strokes,
        "bounds": bounds,
    }

print(f"Generated fixes for {len(fixes)} kanji")

# Write to JSON
out_path = f"{PROJECT}/priv/repo/seeds/bulk_direction_fixes.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(fixes, f, ensure_ascii=False, indent=2)
print(f"Written: {out_path}")
