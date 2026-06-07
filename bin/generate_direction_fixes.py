#!/usr/bin/env python3
"""Generate direction fixes for kanji with unknown directions by analyzing path geometry."""

import json
import re
import os
import subprocess

PROJECT = "/var/home/meddle/development/elixir/medoru"

def infer_direction(path_d):
    if not path_d:
        return "unknown"
    match = re.match(r"M\s*([\d.]+)[,\s]+([\d.]+)", path_d, re.IGNORECASE)
    if not match:
        return "unknown"
    start_x = float(match.group(1))
    start_y = float(match.group(2))
    coords = re.findall(r"[\d.]+", path_d[match.end():])
    if len(coords) >= 2:
        end_x = float(coords[-2])
        end_y = float(coords[-1])
        dx = end_x - start_x
        dy = end_y - start_y
        abs_dx = abs(dx)
        abs_dy = abs(dy)
        if abs_dx > abs_dy * 2:
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
    return "unknown"


def infer_type_from_direction(direction):
    if direction in ("left-to-right", "right-to-left"):
        return "horizontal"
    if direction in ("top-to-bottom", "bottom-to-top"):
        return "vertical"
    if "diagonal" in direction or direction in (
        "top-left-to-bottom-right",
        "top-right-to-bottom-left",
        "bottom-left-to-top-right",
        "bottom-right-to-top-left",
    ):
        return "diagonal"
    return "unknown"


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

# For each stroke, infer direction and type from path geometry
fixes = {}
for k in unknown_kanji:
    char = k["character"]
    if char not in chars:
        continue
    improved_strokes = []
    for s in k["strokes"]:
        path = s["path"]
        order = s["order"]
        stroke_type = s.get("type", "unknown")
        direction = s.get("direction", "unknown")

        # Only re-infer if currently unknown
        if direction == "unknown":
            direction = infer_direction(path)
        if stroke_type == "unknown":
            stroke_type = infer_type_from_direction(direction)

        improved_strokes.append({
            "path": path,
            "order": order,
            "type": stroke_type,
            "direction": direction
        })
    fixes[char] = {
        "strokes": improved_strokes,
        "bounds": {"width": 109, "height": 109, "viewBox": "0 0 109 109"}
    }

print(f"Generated direction+type fixes for {len(fixes)} kanji")

# Write to JSON
out_path = f"{PROJECT}/priv/repo/seeds/bulk_direction_fixes.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(fixes, f, ensure_ascii=False, indent=2)
print(f"Written: {out_path}")
