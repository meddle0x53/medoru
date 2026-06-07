#!/usr/bin/env python3
"""Generates lib/medoru/content/kanji_bulk_fix.ex with embedded data from JSON."""

import json
import os

PROJECT = "/var/home/meddle/development/elixir/medoru"

# Load all fix sources
stroke_fixes = {}
reading_fixes = {}

# 1. KanjiVG stroke fixes (best quality)
with open(f"{PROJECT}/priv/repo/seeds/bulk_stroke_fixes.json", "r", encoding="utf-8") as f:
    all_kvg = json.load(f)

# 2. Direction fixes for kanji with unknown directions
with open(f"{PROJECT}/priv/repo/seeds/bulk_direction_fixes.json", "r", encoding="utf-8") as f:
    all_direction = json.load(f)

# 3. Reading fixes from kanjidic2
with open(f"{PROJECT}/priv/repo/seeds/bulk_reading_fixes.json", "r", encoding="utf-8") as f:
    all_readings = json.load(f)

# Read chars that need fixing
with open("/tmp/chars_strokes.txt", "r", encoding="utf-8") as f:
    stroke_chars = set(f.read().strip().split("\n"))

with open("/tmp/chars_readings.txt", "r", encoding="utf-8") as f:
    reading_chars = set(f.read().strip().split("\n"))

# Build stroke fixes: prefer KanjiVG for types, but use direction fixes for directions
# For KanjiVG data, if direction is unknown, infer a reasonable default from type
TYPE_TO_DIRECTION = {
    "horizontal": "left-to-right",
    "vertical": "top-to-bottom",
    "diagonal": "top-left-to-bottom-right",
    "corner": "top-left-to-bottom-right",
    "dot": "top-to-bottom",
    "hook": "top-to-bottom",
    "curve": "top-left-to-bottom-right",
    "rising": "bottom-left-to-top-right",
}

for char in stroke_chars:
    if char in all_kvg:
        # Start with KanjiVG data
        kvg_data = all_kvg[char]
        improved = []
        for s in kvg_data["strokes"]:
            d = s["direction"]
            t = s["type"]
            if d == "unknown" and t in TYPE_TO_DIRECTION:
                d = TYPE_TO_DIRECTION[t]
            improved.append({
                "path": s["path"],
                "order": s["order"],
                "type": t,
                "direction": d,
            })
        stroke_fixes[char] = {
            "strokes": improved,
            "bounds": kvg_data["bounds"],
        }
    elif char in all_direction:
        stroke_fixes[char] = all_direction[char]

# Build reading fixes
# For katakana readings, force type to :on since the validator requires katakana for on-readings
def is_katakana(s):
    return all('\u30a0' <= c <= '\u30ff' for c in s)

for char in reading_chars:
    if char in all_readings:
        readings = []
        for r in all_readings[char]:
            r_type = r["type"]
            if r_type == "kun" and is_katakana(r["reading"]):
                r_type = "on"
            readings.append({"type": r_type, "reading": r["reading"], "romaji": r["romaji"]})
        reading_fixes[char] = readings

# Add manual fixes for chars not in kanjidic2
# 犰: used in 犰狳 (armadillo), reading キュウ
if "犰" in reading_chars:
    reading_fixes["犰"] = [{"type": "on", "reading": "キュウ", "romaji": "kyuu"}]

# 涮: used in 涮涮鍋, reading セン
if "涮" in reading_chars:
    reading_fixes["涮"] = [{"type": "on", "reading": "セン", "romaji": "sen"}]

print(f"Stroke fixes: {len(stroke_fixes)} (KanjiVG: {len([c for c in stroke_fixes if c in all_kvg])}, direction: {len([c for c in stroke_fixes if c in all_direction])})")
print(f"Reading fixes: {len(reading_fixes)}")

# Build module lines
lines = []
lines.append("defmodule Medoru.Content.KanjiBulkFix do")
lines.append('  @moduledoc """')
lines.append("  Self-contained bulk fix for kanji strokes and readings.")
lines.append("  Run: Medoru.Content.KanjiBulkFix.apply()")
lines.append('  """')
lines.append("")
lines.append("  alias Medoru.Repo")
lines.append("  alias Medoru.Content.{Kanji, KanjiReading}")
lines.append("  import Ecto.Query")
lines.append("  require Logger")
lines.append("")

# Stroke fixes
lines.append("  @stroke_fixes %{")
for char in sorted(stroke_fixes.keys()):
    strokes = stroke_fixes[char]["strokes"]
    if not strokes:
        continue
    lines.append(f'    "{char}" => [')
    for s in strokes:
        path = s["path"].replace("\\", "\\\\").replace('"', '\\"')
        lines.append(
            f'      %{{path: "{path}", order: {s["order"]}, type: "{s["type"]}", direction: "{s["direction"]}"}},'
        )
    lines.append("    ],")
lines.append("  }")
lines.append("")

# Reading fixes
lines.append("  @reading_fixes %{")
for char in sorted(reading_fixes.keys()):
    readings = reading_fixes[char]
    if not readings:
        continue
    lines.append(f'    "{char}" => [')
    for r in readings:
        lines.append(
            f'      %{{type: :{r["type"]}, reading: "{r["reading"]}", romaji: "{r["romaji"]}"}},'
        )
    lines.append("    ],")
lines.append("  }")
lines.append("")

# Functions
lines.extend([
    "  def apply do",
    "    apply_stroke_fixes()",
    "    apply_reading_fixes()",
    "  end",
    "",
    "  defp apply_stroke_fixes do",
    '    Logger.info("Applying stroke fixes...")',
    "",
    "    string_stroke_kanji =",
    "      Repo.all(Kanji)",
    '      |> Enum.filter(fn k ->',
    '        strokes = get_in(k.stroke_data, ["strokes"])',
    "        is_list(strokes) and length(strokes) > 0 and is_binary(hd(strokes))",
    "      end)",
    "",
    "    {fixed_kv, fixed_fb} =",
    "      Enum.reduce(string_stroke_kanji, {0, 0}, fn kanji, {kv, fb} ->",
    "        case Map.fetch(@stroke_fixes, kanji.character) do",
    "          {:ok, strokes} ->",
    "            current = kanji.stroke_data || %{}",
    '            new_data = Map.merge(current, %{"strokes" => strokes, "bounds" => %{"width" => 109, "height" => 109, "viewBox" => "0 0 109 109"}})',
    "            kanji |> Ecto.Changeset.change(stroke_data: new_data) |> Repo.update!()",
    "            {kv + 1, fb}",
    "",
    "          :error ->",
    '            strokes = kanji.stroke_data["strokes"] || []',
    "            new_strokes = Enum.with_index(strokes, 1) |> Enum.map(fn {path, idx} ->",
    '              %{"path" => path, "order" => idx, "type" => "unknown", "direction" => "unknown"}',
    "            end)",
    "            current = kanji.stroke_data || %{}",
    '            kanji |> Ecto.Changeset.change(stroke_data: Map.put(current, "strokes", new_strokes)) |> Repo.update!()',
    "            {kv, fb + 1}",
    "        end",
    "      end)",
    "",
    "    unknown_stroke_kanji =",
    "      Repo.all(Kanji)",
    '      |> Enum.filter(fn k ->',
    '        strokes = get_in(k.stroke_data, ["strokes"])',
    '        is_list(strokes) and is_map(hd(strokes)) and (hd(strokes)["type"] == "unknown" or hd(strokes)["direction"] == "unknown")',
    "      end)",
    "      |> Enum.filter(fn k -> Map.has_key?(@stroke_fixes, k.character) end)",
    "",
    "    replaced = Enum.reduce(unknown_stroke_kanji, 0, fn kanji, count ->",
    "      strokes = @stroke_fixes[kanji.character]",
    "      current = kanji.stroke_data || %{}",
    '      new_data = Map.merge(current, %{"strokes" => strokes, "bounds" => %{"width" => 109, "height" => 109, "viewBox" => "0 0 109 109"}})',
    "      kanji |> Ecto.Changeset.change(stroke_data: new_data) |> Repo.update!()",
    "      count + 1",
    "    end)",
    "",
    "    no_stroke_kanji =",
    "      Repo.all(Kanji)",
    '      |> Enum.filter(fn k ->',
    '        is_nil(k.stroke_data) or k.stroke_data == %{} or is_nil(k.stroke_data["strokes"]) or k.stroke_data["strokes"] == []',
    "      end)",
    "      |> Enum.filter(fn k -> Map.has_key?(@stroke_fixes, k.character) end)",
    "",
    "    added = Enum.reduce(no_stroke_kanji, 0, fn kanji, count ->",
    "      strokes = @stroke_fixes[kanji.character]",
    '      new_data = %{"strokes" => strokes, "bounds" => %{"width" => 109, "height" => 109, "viewBox" => "0 0 109 109"}}',
    "      kanji |> Ecto.Changeset.change(stroke_data: new_data) |> Repo.update!()",
    "      count + 1",
    "    end)",
    "",
    '    Logger.info("Strokes: #{fixed_kv} KanjiVG, #{fixed_fb} fallback, #{replaced} replaced, #{added} added")',
    "  end",
    "",
    "  defp apply_reading_fixes do",
    '    Logger.info("Applying reading fixes...")',
    "",
    "    kanji_without_readings =",
    "      from(k in Kanji,",
    "        left_join: r in assoc(k, :kanji_readings),",
    '        where: not is_nil(k.stroke_data) and k.stroke_data != ^%{},',
    "        group_by: k.id,",
    "        having: count(r.id) == 0,",
    "        select: k",
    "      )",
    "      |> Repo.all()",
    "",
    "    inserted =",
    "      Enum.reduce(kanji_without_readings, 0, fn kanji, count ->",
    "        case Map.fetch(@reading_fixes, kanji.character) do",
    "          {:ok, readings} when is_list(readings) and readings != [] ->",
    "            n = Enum.reduce(readings, 0, fn r, inner ->",
    '              attrs = %{kanji_id: kanji.id, reading_type: r.type, reading: r.reading, romaji: r.romaji}',
    "              case %KanjiReading{} |> KanjiReading.changeset(attrs) |> Repo.insert() do",
    "                {:ok, _} -> inner + 1",
    "                {:error, _} -> inner",
    "              end",
    "            end)",
    "            count + n",
    "",
    "          _ -> count",
    "        end",
    "      end)",
    "",
    '    Logger.info("Inserted #{inserted} readings")',
    "  end",
    "end",
])

output = "\n".join(lines) + "\n"
out_path = f"{PROJECT}/lib/medoru/content/kanji_bulk_fix.ex"
with open(out_path, "w", encoding="utf-8") as f:
    f.write(output)

size_kb = len(output) / 1024
print(f"\nWritten: {out_path}")
print(f"Size: {size_kb:.1f} KB")
print(f"Kanji with stroke fixes embedded: {len(stroke_fixes)}")
print(f"Kanji with reading fixes embedded: {len(reading_fixes)}")
