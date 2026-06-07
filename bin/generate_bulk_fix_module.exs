#!/usr/bin/env elixir
# Generates lib/medoru/content/kanji_bulk_fix.ex with embedded data
# Usage: mix run bin/generate_bulk_fix_module.exs

alias Medoru.Repo
alias Medoru.Content.Kanji
import Ecto.Query

stroke_fixes_file = "priv/repo/seeds/bulk_stroke_fixes.json"
reading_fixes_file = "priv/repo/seeds/bulk_reading_fixes.json"

stroke_fixes =
  case File.read(stroke_fixes_file) do
    {:ok, contents} -> Jason.decode!(contents)
    {:error, _} -> %{}  
  end

reading_fixes =
  case File.read(reading_fixes_file) do
    {:ok, contents} -> Jason.decode!(contents)
    {:error, _} -> %{}  
  end

all = Repo.all(Kanji)

string_strokes = Enum.filter(all, fn k ->
  strokes = get_in(k.stroke_data, ["strokes"])
  is_list(strokes) and length(strokes) > 0 and is_binary(hd(strokes))
end)

unknown_strokes = Enum.filter(all, fn k ->
  strokes = get_in(k.stroke_data, ["strokes"])
  is_list(strokes) and is_map(hd(strokes)) and (hd(strokes)["type"] == "unknown" or hd(strokes)["direction"] == "unknown")
end)

no_strokes = Enum.filter(all, fn k ->
  is_nil(k.stroke_data) or k.stroke_data == %{} or is_nil(k.stroke_data["strokes"]) or k.stroke_data["strokes"] == []
end)

no_readings = from(k in Kanji,
  left_join: r in assoc(k, :kanji_readings),
  where: not is_nil(k.stroke_data) and k.stroke_data != ^%{},
  group_by: k.id,
  having: count(r.id) == 0,
  select: k
) |> Repo.all()

chars_strokes = (string_strokes ++ unknown_strokes ++ no_strokes) |> Enum.map(& &1.character) |> Enum.uniq()
chars_readings = no_readings |> Enum.map(& &1.character) |> Enum.uniq()

IO.puts("Kanji needing strokes: #{length(chars_strokes)}")
IO.puts("Kanji needing readings: #{length(chars_readings)}")

# Build module lines
lines = []
lines = lines ++ ['defmodule Medoru.Content.KanjiBulkFix do']
lines = lines ++ ['  @moduledoc """']
lines = lines ++ ['  Self-contained bulk fix for kanji strokes and readings.']
lines = lines ++ ['  Run: Medoru.Content.KanjiBulkFix.apply()']
lines = lines ++ ['  """']
lines = lines ++ ['']
lines = lines ++ ['  alias Medoru.Repo']
lines = lines ++ ['  alias Medoru.Content.{Kanji, KanjiReading}']
lines = lines ++ ['  import Ecto.Query']
lines = lines ++ ['  require Logger']
lines = lines ++ ['']

# Stroke fixes
lines = lines ++ ['  @stroke_fixes %{']
for char <- chars_strokes do
  strokes = Map.get(stroke_fixes, char)
  if strokes && strokes["strokes"] && length(strokes["strokes"]) > 0 do
    lines = lines ++ ['    "#{char}" => [']
    for s <- strokes["strokes"] do
      path = String.replace(s["path"], "\"", "\\\"")
      lines = lines ++ ['      %{path: "#{path}", order: #{s["order"]}, type: "#{s["type"]}", direction: "#{s["direction"]}"},']
    end
    lines = lines ++ ['    ],']
  end
end
lines = lines ++ ['  }']
lines = lines ++ ['']

# Reading fixes
lines = lines ++ ['  @reading_fixes %{']
for char <- chars_readings do
  readings = Map.get(reading_fixes, char)
  if readings && length(readings) > 0 do
    lines = lines ++ ['    "#{char}" => [']
    for r <- readings do
      lines = lines ++ ['      %{type: :#{r["type"]}, reading: "#{r["reading"]}", romaji: "#{r["romaji"]}"},']
    end
    lines = lines ++ ['    ],']
  end
end
lines = lines ++ ['  }']
lines = lines ++ ['']

# Functions
lines = lines ++ ['  def apply do']
lines = lines ++ ['    apply_stroke_fixes()']
lines = lines ++ ['    apply_reading_fixes()']
lines = lines ++ ['  end']
lines = lines ++ ['']
lines = lines ++ ['  defp apply_stroke_fixes do']
lines = lines ++ ['    Logger.info("Applying stroke fixes...")']
lines = lines ++ ['']
lines = lines ++ ['    string_stroke_kanji =']
lines = lines ++ ['      Repo.all(Kanji)']
lines = lines ++ ['      |> Enum.filter(fn k ->']
lines = lines ++ ['        strokes = get_in(k.stroke_data, ["strokes"])']
lines = lines ++ ['        is_list(strokes) and length(strokes) > 0 and is_binary(hd(strokes))']
lines = lines ++ ['      end)']
lines = lines ++ ['']
lines = lines ++ ['    {fixed_kv, fixed_fb} =']
lines = lines ++ ['      Enum.reduce(string_stroke_kanji, {0, 0}, fn kanji, {kv, fb} ->']
lines = lines ++ ['        case Map.fetch(@stroke_fixes, kanji.character) do']
lines = lines ++ ['          {:ok, strokes} ->']
lines = lines ++ ['            current = kanji.stroke_data || %{}']
lines = lines ++ ['            new_data = Map.merge(current, %{"strokes" => strokes, "bounds" => %{"width" => 109, "height" => 109, "viewBox" => "0 0 109 109"}})']
lines = lines ++ ['            kanji |> Ecto.Changeset.change(stroke_data: new_data) |> Repo.update!()']
lines = lines ++ ['            {kv + 1, fb}']
lines = lines ++ ['']
lines = lines ++ ['          :error ->']
lines = lines ++ ['            strokes = kanji.stroke_data["strokes"] || []']
lines = lines ++ ['            new_strokes = Enum.with_index(strokes, 1) |> Enum.map(fn {path, idx} ->']
lines = lines ++ ['              %{"path" => path, "order" => idx, "type" => "unknown", "direction" => "unknown"}']
lines = lines ++ ['            end)']
lines = lines ++ ['            current = kanji.stroke_data || %{}']
lines = lines ++ ['            kanji |> Ecto.Changeset.change(stroke_data: Map.put(current, "strokes", new_strokes)) |> Repo.update!()']
lines = lines ++ ['            {kv, fb + 1}']
lines = lines ++ ['        end']
lines = lines ++ ['      end)']
lines = lines ++ ['']
lines = lines ++ ['    unknown_stroke_kanji =']
lines = lines ++ ['      Repo.all(Kanji)']
lines = lines ++ ['      |> Enum.filter(fn k ->']
lines = lines ++ ['        strokes = get_in(k.stroke_data, ["strokes"])']
lines = lines ++ ['        is_list(strokes) and is_map(hd(strokes)) and (hd(strokes)["type"] == "unknown" or hd(strokes)["direction"] == "unknown")']
lines = lines ++ ['      end)']
lines = lines ++ ['      |> Enum.filter(fn k -> Map.has_key?(@stroke_fixes, k.character) end)']
lines = lines ++ ['']
lines = lines ++ ['    replaced = Enum.reduce(unknown_stroke_kanji, 0, fn kanji, count ->']
lines = lines ++ ['      strokes = @stroke_fixes[kanji.character]']
lines = lines ++ ['      current = kanji.stroke_data || %{}']
lines = lines ++ ['      new_data = Map.merge(current, %{"strokes" => strokes, "bounds" => %{"width" => 109, "height" => 109, "viewBox" => "0 0 109 109"}})']
lines = lines ++ ['      kanji |> Ecto.Changeset.change(stroke_data: new_data) |> Repo.update!()']
lines = lines ++ ['      count + 1']
lines = lines ++ ['    end)']
lines = lines ++ ['']
lines = lines ++ ['    no_stroke_kanji =']
lines = lines ++ ['      Repo.all(Kanji)']
lines = lines ++ ['      |> Enum.filter(fn k ->']
lines = lines ++ ['        is_nil(k.stroke_data) or k.stroke_data == %{} or is_nil(k.stroke_data["strokes"]) or k.stroke_data["strokes"] == []']
lines = lines ++ ['      end)']
lines = lines ++ ['      |> Enum.filter(fn k -> Map.has_key?(@stroke_fixes, k.character) end)']
lines = lines ++ ['']
lines = lines ++ ['    added = Enum.reduce(no_stroke_kanji, 0, fn kanji, count ->']
lines = lines ++ ['      strokes = @stroke_fixes[kanji.character]']
lines = lines ++ ['      new_data = %{"strokes" => strokes, "bounds" => %{"width" => 109, "height" => 109, "viewBox" => "0 0 109 109"}}']
lines = lines ++ ['      kanji |> Ecto.Changeset.change(stroke_data: new_data) |> Repo.update!()']
lines = lines ++ ['      count + 1']
lines = lines ++ ['    end)']
lines = lines ++ ['']
lines = lines ++ ['    Logger.info("Strokes: #{fixed_kv} KanjiVG, #{fixed_fb} fallback, #{replaced} replaced, #{added} added")']
lines = lines ++ ['  end']
lines = lines ++ ['']
lines = lines ++ ['  defp apply_reading_fixes do']
lines = lines ++ ['    Logger.info("Applying reading fixes...")']
lines = lines ++ ['']
lines = lines ++ ['    kanji_without_readings =']
lines = lines ++ ['      from(k in Kanji,']
lines = lines ++ ['        left_join: r in assoc(k, :kanji_readings),']
lines = lines ++ ['        where: not is_nil(k.stroke_data) and k.stroke_data != ^%{},']
lines = lines ++ ['        group_by: k.id,']
lines = lines ++ ['        having: count(r.id) == 0,']
lines = lines ++ ['        select: k']
lines = lines ++ ['      )']
lines = lines ++ ['      |> Repo.all()']
lines = lines ++ ['']
lines = lines ++ ['    inserted =']
lines = lines ++ ['      Enum.reduce(kanji_without_readings, 0, fn kanji, count ->']
lines = lines ++ ['        case Map.fetch(@reading_fixes, kanji.character) do']
lines = lines ++ ['          {:ok, readings} when is_list(readings) and readings != [] ->']
lines = lines ++ ['            n = Enum.reduce(readings, 0, fn r, inner ->']
lines = lines ++ ['              attrs = %{kanji_id: kanji.id, reading_type: r.type, reading: r.reading, romaji: r.romaji}']
lines = lines ++ ['              case %KanjiReading{} |> KanjiReading.changeset(attrs) |> Repo.insert() do']
lines = lines ++ ['                {:ok, _} -> inner + 1']
lines = lines ++ ['                {:error, _} -> inner']
lines = lines ++ ['              end']
lines = lines ++ ['            end)']
lines = lines ++ ['            count + n']
lines = lines ++ ['']
lines = lines ++ ['          _ -> count']
lines = lines ++ ['        end']
lines = lines ++ ['      end)']
lines = lines ++ ['']
lines = lines ++ ['    Logger.info("Inserted #{inserted} readings")']
lines = lines ++ ['  end']
lines = lines ++ ['end']

output = Enum.join(lines, "\n") <> "\n"
out_path = "lib/medoru/content/kanji_bulk_fix.ex"
File.write!(out_path, output)

size_kb = byte_size(output) / 1024
IO.puts("\nWritten: #{out_path}")
IO.puts("Size: #{:erlang.float_to_binary(size_kb, decimals: 1)} KB")
IO.puts("Kanji with stroke fixes embedded: #{length(chars_strokes)}")
IO.puts("Kanji with reading fixes embedded: #{length(chars_readings)}")
