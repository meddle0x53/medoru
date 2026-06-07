import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

KVG_NS = "http://kanjivg.tagaini.net"
SVG_NS = "http://www.w3.org/2000/svg"

kanji_dir = Path('/var/home/meddle/development/elixir/medoru/raw/kanjivg/kanji')
graphics_path = Path('/var/home/meddle/development/elixir/medoru/raw/makemeahanzi/graphics.txt')

# Load missing kanji
with open('/var/home/meddle/development/elixir/medoru/priv/repo/seeds/missing_kanji_full.json') as f:
    missing_data = json.load(f)
missing_kanji = missing_data['kanji']
missing_chars = {k['character'] for k in missing_kanji}

print(f"Total missing kanji: {len(missing_kanji)}")


def categorize_stroke_type(kvg_type):
    if not kvg_type:
        return "unknown"
    stroke_map = {
        "㇐": "horizontal", "㇑": "vertical", "㇒": "diagonal", "㇏": "diagonal",
        "㇔": "dot", "㇀": "rising", "㇕": "corner", "㇆": "hook", "㇇": "corner",
        "㇂": "hook", "㇃": "hook", "㇄": "corner", "㇅": "corner", "㇈": "corner",
        "㇉": "corner", "㇊": "corner", "㇋": "corner", "㇌": "corner", "㇍": "corner",
        "㇎": "corner", "㇓": "diagonal", "㇖": "corner", "㇗": "corner", "㇘": "corner",
        "㇙": "corner", "㇚": "hook", "㇛": "curve", "㇜": "curve", "㇝": "curve",
        "㇞": "curve", "㇟": "curve",
    }
    return stroke_map.get(kvg_type[0], "unknown")


def infer_direction(path_d, stroke_type):
    match = re.match(r"M\s*([\d.]+)[,\s]+([\d.]+)", path_d)
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


def extract_kanjivg_strokes(char):
    hex_code = f"{ord(char):05x}"
    svg_path = kanji_dir / f"{hex_code}.svg"
    if not svg_path.exists():
        return None
    try:
        tree = ET.parse(svg_path)
        root = tree.getroot()
    except ET.ParseError:
        return None

    stroke_paths_group = None
    for g in root.iter(f"{{{SVG_NS}}}g"):
        if "StrokePaths" in g.get("id", ""):
            stroke_paths_group = g
            break
    if not stroke_paths_group:
        return None

    strokes = []
    for path in stroke_paths_group.iter():
        if path.tag == f"{{{SVG_NS}}}path":
            path_id = path.get("id", "")
            d = path.get("d", "")
            stroke_type = path.get(f"{{{KVG_NS}}}type", "")
            match = re.search(r"-s(\d+)$", path_id)
            if match and d:
                stroke_num = int(match.group(1))
                strokes.append({
                    "order": stroke_num,
                    "path": d,
                    "type": categorize_stroke_type(stroke_type),
                    "direction": infer_direction(d, stroke_type)
                })

    strokes.sort(key=lambda x: x["order"])
    if not strokes:
        return None
    return {
        "bounds": {"width": 109, "height": 109, "viewBox": "0 0 109 109"},
        "strokes": strokes
    }


def median_to_path(points):
    """Convert median points to SVG path string, scaled from 1024 to 109.
    
    Makemeahanzi uses Y-up coordinates (Y=0 at bottom), SVG uses Y-down (Y=0 at top).
    So we flip Y: y_svg = 109 - y_scaled
    """
    scale = 109 / 1024
    scaled = [(x * scale, 109 - (y * scale)) for x, y in points]
    path = f"M{scaled[0][0]:.2f},{scaled[0][1]:.2f}"
    for x, y in scaled[1:]:
        path += f"L{x:.2f},{y:.2f}"
    return path


def infer_type_from_path(path_d):
    """Infer stroke type from path bounding box."""
    coords = re.findall(r"[\d.]+", path_d)
    if len(coords) < 4:
        return "unknown"
    xs = [float(coords[i]) for i in range(0, len(coords), 2)]
    ys = [float(coords[i]) for i in range(1, len(coords), 2)]
    w = max(xs) - min(xs)
    h = max(ys) - min(ys)
    if w > h * 2:
        return "horizontal"
    elif h > w * 2:
        return "vertical"
    else:
        return "diagonal"


# Load makemeahanzi medians into memory
mmah_medians = {}
print("Loading makemeahanzi graphics.txt...")
with open(graphics_path) as f:
    for line in f:
        obj = json.loads(line.strip())
        char = obj.get("character")
        if char in missing_chars:
            mmah_medians[char] = obj.get("medians", [])

print(f"Loaded {len(mmah_medians)} makemeahanzi entries")

# Process each missing kanji
updated_count = 0
kanjivg_count = 0
mmah_count = 0
empty_count = 0

for kanji in missing_kanji:
    char = kanji["character"]
    stroke_data = extract_kanjivg_strokes(char)
    if stroke_data:
        kanji["stroke_data"] = stroke_data
        updated_count += 1
        kanjivg_count += 1
    elif char in mmah_medians and mmah_medians[char]:
        # Convert medians to stroke data
        medians = mmah_medians[char]
        strokes = []
        for i, points in enumerate(medians):
            path_d = median_to_path(points)
            strokes.append({
                "order": i + 1,
                "path": path_d,
                "type": infer_type_from_path(path_d),
                "direction": infer_direction(path_d, "")
            })
        kanji["stroke_data"] = {
            "bounds": {"width": 109, "height": 109, "viewBox": "0 0 109 109"},
            "strokes": strokes
        }
        updated_count += 1
        mmah_count += 1
    else:
        # Remove bad stroke data
        if "stroke_data" in kanji:
            del kanji["stroke_data"]
        empty_count += 1

print(f"\nUpdated: {updated_count}")
print(f"  From KanjiVG: {kanjivg_count}")
print(f"  From makemeahanzi medians: {mmah_count}")
print(f"  Empty (no data): {empty_count}")

# Save
output_path = Path('/var/home/meddle/development/elixir/medoru/priv/repo/seeds/missing_kanji_full.json')
with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(missing_data, f, ensure_ascii=False, indent=2)

print(f"\nSaved to {output_path}")
