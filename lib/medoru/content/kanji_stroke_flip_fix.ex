defmodule Medoru.Content.KanjiStrokeFlipFix do
  @moduledoc """
  Fixes upside-down stroke paths for kanji that were imported from makemeahanzi medians.

  Makemeahanzi uses a Y-up coordinate system (Y=0 at the bottom), while SVG uses
  Y-down (Y=0 at the top). This module detects kanji with makemeahanzi-style
  stroke paths (L-only polylines, no cubic beziers) and flips their Y coordinates
  to correct the orientation.

  ## Usage

      # In a remote console (iex):
      Medoru.Content.KanjiStrokeFlipFix.apply()

  The module is idempotent — it skips kanji that have already been fixed
  (tracked by a `"y_flipped"` flag in stroke_data).
  """

  alias Medoru.Repo
  alias Medoru.Content.Kanji

  import Ecto.Query

  require Logger

  @doc """
  Applies the Y-flip fix to all kanji with makemeahanzi-style stroke paths.

  Returns a summary of how many kanji were fixed or had errors.
  """
  def apply do
    candidates =
      Kanji
      |> where([k], not is_nil(k.stroke_data))
      |> Repo.all()
      |> Enum.filter(&needs_fix?/1)

    Logger.info("Found #{length(candidates)} kanji with makemeahanzi-style stroke paths")

    results =
      Enum.reduce(candidates, %{fixed: 0, errors: []}, fn kanji, acc ->
        case fix_kanji(kanji) do
          {:ok, :fixed} ->
            Map.update!(acc, :fixed, &(&1 + 1))

          {:error, reason} ->
            acc
            |> Map.update!(:errors, &[reason | &1])
        end
      end)

    Logger.info("")
    Logger.info("Kanji stroke flip fix complete!")
    Logger.info("  Fixed: #{results.fixed}")

    if results.errors != [] do
      Logger.warning("  Errors: #{length(results.errors)}")

      Enum.take(results.errors, 10)
      |> Enum.each(fn err -> Logger.warning("    #{err}") end)
    end

    {:ok, results}
  end

  @doc """
  Returns the list of characters that currently have makemeahanzi-style
  stroke paths in the database (L-only polylines, no cubic beziers).

  These are the kanji that would be affected by `apply/0`.
  """
  def affected_characters do
    Kanji
    |> where([k], not is_nil(k.stroke_data))
    |> Repo.all()
    |> Enum.filter(&needs_fix?/1)
    |> Enum.map(& &1.character)
  end

  defp needs_fix?(kanji) do
    stroke_data = kanji.stroke_data || %{}

    # Skip if already fixed
    if stroke_data["y_flipped"] do
      false
    else
      strokes = stroke_data["strokes"] || []

      length(strokes) > 0 &&
        Enum.all?(strokes, fn s ->
          path = s["path"] || ""
          # Makemeahanzi median paths use only L (line) commands.
          # KanjiVG paths use cubic beziers (c/C commands).
          String.contains?(path, "L") &&
            !String.contains?(path, "c") &&
            !String.contains?(path, "C")
        end)
    end
  end

  defp fix_kanji(kanji) do
    stroke_data = kanji.stroke_data
    strokes = stroke_data["strokes"] || []

    fixed_strokes =
      Enum.map(strokes, fn stroke ->
        path = stroke["path"] || ""
        fixed_path = flip_y_in_path(path)
        Map.put(stroke, "path", fixed_path)
      end)

    updated_stroke_data =
      stroke_data
      |> Map.put("strokes", fixed_strokes)
      |> Map.put("y_flipped", true)

    case Repo.update(Ecto.Changeset.change(kanji, stroke_data: updated_stroke_data)) do
      {:ok, _} ->
        Logger.debug("Fixed strokes for: #{kanji.character}")
        {:ok, :fixed}

      {:error, changeset} ->
        Logger.error("Failed to fix #{kanji.character}: #{inspect(changeset.errors)}")
        {:error, "#{kanji.character}: #{inspect(changeset.errors)}"}
    end
  end

  @doc """
  Flips the Y coordinates in an SVG path string.

  For a 109x109 viewBox, Y is transformed as: `y_new = 109 - y_old`.

  Supports M and L commands with comma-separated coordinates as produced by
  makemeahanzi median conversion (e.g. `M33.74,22.57L36.40,25.33...`).
  """
  def flip_y_in_path(path) do
    Regex.replace(
      ~r/([ML])(-?\d+\.\d+),(-?\d+\.\d+)/,
      path,
      fn _full, cmd, x, y ->
        y_new = 109.0 - String.to_float(y)
        "#{cmd}#{x},#{:erlang.float_to_binary(y_new, decimals: 2)}"
      end
    )
  end
end
