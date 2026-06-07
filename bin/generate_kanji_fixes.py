#!/usr/bin/env python3
"""
Generate JSON fix files for kanji with:
1. String-format strokes -> convert to map format using KanjiVG data
2. Missing readings -> extract from kanjidic2.xml

Outputs:
- priv/repo/seeds/bulk_stroke_fixes.json
- priv/repo/seeds/bulk_reading_fixes.json

Run with: python3 bin/generate_kanji_fixes.py
"""

import json
import os
import re
from pathlib import Path
from xml.etree import ElementTree as ET

KVG_NS = "http://kanjivg.tagaini.net"
SVG_NS = "http://www.w3.org/2000/svg"

STROKE_MAP = {
    "㇐": "horizontal", "㇑": "vertical", "㇒": "diagonal", "㇏": "diagonal",
    "㇔": "dot", "㇀": "rising", "㇕": "corner", "㇆": "hook", "㇇": "corner",
    "㇂": "hook", "㇃": "hook", "㇄": "corner", "㇅": "corner", "㇈": "corner",
    "㇉": "corner", "㇊": "corner", "㇋": "corner", "㇌": "corner", "㇍": "corner",
    "㇎": "corner", "㇓": "diagonal", "㇖": "corner", "㇗": "corner", "㇘": "corner",
    "㇙": "corner", "㇚": "hook", "㇛": "curve", "㇜": "curve", "㇝": "curve",
    "㇞": "curve", "㇟": "curve",
}

KANA_MAP = {
    "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
    "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
    "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
    "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
    "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
    "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
    "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
    "や": "ya", "ゆ": "yu", "よ": "yo",
    "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
    "わ": "wa", "を": "wo", "ん": "n",
    "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
    "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
    "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
    "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
    "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
    "きゃ": "kya", "きゅ": "kyu", "きょ": "kyo",
    "しゃ": "sha", "しゅ": "shu", "しょ": "sho",
    "ちゃ": "cha", "ちゅ": "chu", "ちょ": "cho",
    "にゃ": "nya", "にゅ": "nyu", "にょ": "nyo",
    "ひゃ": "hya", "ひゅ": "hyu", "ひょ": "hyo",
    "みゃ": "mya", "みゅ": "myu", "みょ": "myo",
    "りゃ": "rya", "りゅ": "ryu", "りょ": "ryo",
    "ぎゃ": "gya", "ぎゅ": "gyu", "ぎょ": "gyo",
    "じゃ": "ja", "じゅ": "ju", "じょ": "jo",
    "びゃ": "bya", "びゅ": "byu", "びょ": "byo",
    "ぴゃ": "pya", "ぴゅ": "pyu", "ぴょ": "pyo",
    "っ": "", "ー": "-",
    "ア": "a", "イ": "i", "ウ": "u", "エ": "e", "オ": "o",
    "カ": "ka", "キ": "ki", "ク": "ku", "ケ": "ke", "コ": "ko",
    "サ": "sa", "シ": "shi", "ス": "su", "セ": "se", "ソ": "so",
    "タ": "ta", "チ": "chi", "ツ": "tsu", "テ": "te", "ト": "to",
    "ナ": "na", "ニ": "ni", "ヌ": "nu", "ネ": "ne", "ノ": "no",
    "ハ": "ha", "ヒ": "hi", "フ": "fu", "ヘ": "he", "ホ": "ho",
    "マ": "ma", "ミ": "mi", "ム": "mu", "メ": "me", "モ": "mo",
    "ヤ": "ya", "ユ": "yu", "ヨ": "yo",
    "ラ": "ra", "リ": "ri", "ル": "ru", "レ": "re", "ロ": "ro",
    "ワ": "wa", "ヲ": "wo", "ン": "n",
    "ガ": "ga", "ギ": "gi", "グ": "gu", "ゲ": "ge", "ゴ": "go",
    "ザ": "za", "ジ": "ji", "ズ": "zu", "ゼ": "ze", "ゾ": "zo",
    "ダ": "da", "ヂ": "ji", "ヅ": "zu", "デ": "de", "ド": "do",
    "バ": "ba", "ビ": "bi", "ブ": "bu", "ベ": "be", "ボ": "bo",
    "パ": "pa", "ピ": "pi", "プ": "pu", "ペ": "pe", "ポ": "po",
    "キャ": "kya", "キュ": "kyu", "キョ": "kyo",
    "シャ": "sha", "シュ": "shu", "ショ": "sho",
    "チャ": "cha", "チュ": "chu", "チョ": "cho",
    "ニャ": "nya", "ニュ": "nyu", "ニョ": "nyo",
    "ヒャ": "hya", "ヒュ": "hyu", "ヒョ": "hyo",
    "ミャ": "mya", "ミュ": "myu", "ミョ": "myo",
    "リャ": "rya", "リュ": "ryu", "リョ": "ryo",
    "ギャ": "gya", "ギュ": "gyu", "ギョ": "gyo",
    "ジャ": "ja", "ジュ": "ju", "ジョ": "jo",
    "ビャ": "bya", "ビュ": "byu", "ビョ": "byo",
    "ピャ": "pya", "ピュ": "pyu", "ピョ": "pyo",
    "ッ": "", "ー": "-",
}


def kana_to_romaji(kana: str) -> str:
    """Convert kana to romaji (basic implementation)."""
    if not kana:
        return ""

    result = []
    i = 0
    while i < len(kana):
        if i + 1 < len(kana):
            two_char = kana[i:i+2]
            if two_char in KANA_MAP:
                val = KANA_MAP[two_char]
                if val:
                    result.append(val)
                i += 2
                continue

        char = kana[i]
        if char in KANA_MAP:
            val = KANA_MAP[char]
            if val:
                result.append(val)
        i += 1

    return "".join(result)


def categorize_stroke_type(kvg_type):
    if not kvg_type:
        return "unknown"
    return STROKE_MAP.get(kvg_type[0], "unknown")


def infer_direction(path_d):
    if not path_d:
        return "unknown"
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
    svg_path = Path(f"raw/kanjivg/kanji/{hex_code}.svg")
    if not svg_path.exists():
        return None
    try:
        tree = ET.parse(svg_path)
        root = tree.getroot()
    except ET.ParseError:
        return None

    stroke_paths_group = None
    for g in root.iter(f"{{{SVG_NS}}}g"):
        gid = g.get("id", "")
        if "StrokePaths" in gid:
            stroke_paths_group = g
            break
    if stroke_paths_group is None:
        return None

    strokes = []
    for path in stroke_paths_group.iter():
        if path.tag == f"{{{SVG_NS}}}path":
            path_id = path.get("id", "")
            d = path.get("d", "")
            kvg_type = path.get(f"{{{KVG_NS}}}type", "")
            match = re.search(r"-s(\d+)$", path_id)
            if match and d:
                stroke_num = int(match.group(1))
                strokes.append({
                    "order": stroke_num,
                    "path": d,
                    "type": categorize_stroke_type(kvg_type),
                    "direction": infer_direction(d)
                })
    strokes.sort(key=lambda x: x["order"])
    return strokes


def parse_kanjidic2(xml_path):
    """Parse kanjidic2.xml and return {char: [{type, reading, romaji}, ...]}"""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    result = {}
    for character in root.iter("character"):
        literal = character.find("literal")
        if literal is None or literal.text is None:
            continue
        char = literal.text

        readings = []
        rmgroup = character.find("reading_meaning/rmgroup")
        if rmgroup is not None:
            for r in rmgroup.iter("reading"):
                r_type = r.get("r_type")
                text = r.text or ""
                if r_type == "ja_on":
                    readings.append({"type": "on", "reading": text, "romaji": kana_to_romaji(text)})
                elif r_type == "ja_kun":
                    # Remove okurigana marker (e.g., "あ.る" -> "あ")
                    clean = text.split(".")[0]
                    readings.append({"type": "kun", "reading": clean, "romaji": kana_to_romaji(clean)})

        if readings:
            result[char] = readings

    return result


def main():
    print("Loading kanjidic2.xml...")
    kanjidic2 = parse_kanjidic2("raw/kanjidic2/kanjidic2.xml")
    print(f"  Loaded {len(kanjidic2)} kanji with readings")

    print("\nScanning KanjiVG SVG files...")
    kanjivg_dir = Path("raw/kanjivg/kanji")
    svg_files = [f for f in kanjivg_dir.glob("*.svg") if re.match(r"^[0-9a-f]{5}\.svg$", f.name)]
    print(f"  Found {len(svg_files)} SVG files")

    print("\nGenerating stroke fixes...")
    stroke_fixes = {}
    for svg_file in svg_files:
        hex_code = svg_file.stem
        char = chr(int(hex_code, 16))
        strokes = extract_kanjivg_strokes(char)
        if strokes:
            stroke_fixes[char] = {
                "strokes": strokes,
                "bounds": {"width": 109, "height": 109, "viewBox": "0 0 109 109"}
            }

    print(f"  Generated fixes for {len(stroke_fixes)} kanji")

    out_dir = Path("priv/repo/seeds")
    out_dir.mkdir(parents=True, exist_ok=True)

    stroke_file = out_dir / "bulk_stroke_fixes.json"
    with open(stroke_file, "w", encoding="utf-8") as f:
        json.dump(stroke_fixes, f, ensure_ascii=False, indent=2)
    print(f"  Written: {stroke_file}")

    print("\nGenerating reading fixes...")
    reading_file = out_dir / "bulk_reading_fixes.json"
    with open(reading_file, "w", encoding="utf-8") as f:
        json.dump(kanjidic2, f, ensure_ascii=False, indent=2)
    print(f"  Written: {reading_file}")

    print("\n" + "=" * 50)
    print("Fix summary (apply with Elixir module)")
    print("=" * 50)
    print(f"Kanji with KanjiVG stroke data: {len(stroke_fixes)}")
    print(f"Kanji with reading data: {len(kanjidic2)}")
    print("\nNext steps:")
    print("1. Copy bin/generate_kanji_fixes.py to the server")
    print("2. Run: python3 bin/generate_kanji_fixes.py")
    print("3. Paste the Elixir module into remote console")
    print("4. Run: Medoru.Content.KanjiBulkFix.apply()")


if __name__ == "__main__":
    main()
