defmodule Mix.Tasks.Medoru.FixWordReadings do
  @moduledoc """
  Fixes word-kanji associations by matching the specific kanji readings used in words.

  Many word-kanji associations were created without linking to the specific reading
  (e.g., 上 in のし上がる should link to reading "あ" but has null reading_id).

  This task scans all word-kanji associations and attempts to match the reading
  based on the word's hiragana reading.

  ## Examples

      # Fix all word-kanji associations
      mix medoru.fix_word_readings

      # Dry run (show what would be fixed)
      mix medoru.fix_word_readings --dry-run

      # Fix for specific level only
      mix medoru.fix_word_readings --level N5
  """

  use Mix.Task

  alias Medoru.Repo
  alias Medoru.Content.{WordKanji, KanjiReading}

  import Ecto.Query

  require Logger

  @shortdoc "Fix word-kanji reading associations"
  @batch_size 1000

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          dry_run: :boolean,
          level: :string
        ],
        aliases: [
          d: :dry_run,
          l: :level
        ]
      )

    Mix.Task.run("app.start")

    dry_run = Keyword.get(opts, :dry_run, false)
    level = parse_level(opts[:level])

    if dry_run do
      Mix.shell().info("DRY RUN - No changes will be made")
    end

    # Preload all kanji readings for efficient lookup
    kanji_readings = load_kanji_readings()
    Mix.shell().info("Loaded #{map_size(kanji_readings)} kanji with readings")

    # Process in batches
    {total_fixed, total_failed} = process_batches(0, 0, 0, kanji_readings, level, dry_run)

    Mix.shell().info("")
    Mix.shell().info("Results:")
    Mix.shell().info("  Fixed: #{total_fixed}")
    Mix.shell().info("  Failed: #{total_failed}")

    if dry_run do
      Mix.shell().info("")
      Mix.shell().info("Run without --dry-run to apply fixes")
    end
  end

  defp parse_level(nil), do: nil

  defp parse_level(level) when is_binary(level) do
    case String.upcase(level) do
      "N5" -> 5
      "N4" -> 4
      "N3" -> 3
      "N2" -> 2
      "N1" -> 1
      _ -> nil
    end
  end

  defp load_kanji_readings do
    from(kr in KanjiReading,
      join: k in assoc(kr, :kanji),
      select: {k.character, kr}
    )
    |> Repo.all()
    |> Enum.group_by(fn {char, _} -> char end, fn {_, kr} -> kr end)
  end

  defp process_batches(offset, total_fixed, total_failed, kanji_readings, level_filter, dry_run) do
    # Get batch of word-kanji associations without reading links
    query =
      from(wk in WordKanji,
        join: w in assoc(wk, :word),
        join: k in assoc(wk, :kanji),
        where: is_nil(wk.kanji_reading_id) and not is_nil(wk.kanji_id),
        preload: [word: w, kanji: k],
        limit: ^@batch_size,
        offset: ^offset
      )

    # Apply level filter if specified
    query =
      if level_filter do
        where(query, [wk, w, k], w.difficulty == ^level_filter)
      else
        query
      end

    batch = Repo.all(query)

    if batch == [] do
      {total_fixed, total_failed}
    else
      {fixed, failed} = process_batch(batch, kanji_readings, dry_run)
      new_fixed = total_fixed + fixed
      new_failed = total_failed + failed
      new_offset = offset + @batch_size

      if rem(new_offset, 5000) == 0 do
        Mix.shell().info("Processed #{new_offset} records... (fixed: #{new_fixed})")
      end

      process_batches(new_offset, new_fixed, new_failed, kanji_readings, level_filter, dry_run)
    end
  end

  defp process_batch(word_kanjis, kanji_readings, dry_run) do
    Enum.reduce(word_kanjis, {0, 0}, fn wk, {success, failed} ->
      readings = Map.get(kanji_readings, wk.kanji.character, [])

      case find_matching_reading(wk, readings) do
        nil ->
          {success, failed + 1}

        reading_id ->
          if dry_run do
            {success + 1, failed}
          else
            case update_word_kanji(wk, reading_id) do
              :ok -> {success + 1, failed}
              :error -> {success, failed + 1}
            end
          end
      end
    end)
  end

  defp find_matching_reading(%WordKanji{} = wk, readings) when is_list(readings) do
    word_reading = wk.word.reading
    _kanji_char = wk.kanji.character

    # Count kanji in word
    kanji_count = count_kanji(wk.word.text)

    if kanji_count == 1 do
      # Single kanji word - try to match reading directly
      Enum.find_value(readings, fn kr ->
        if matches_single_kanji_reading?(word_reading, kr) do
          kr.id
        else
          nil
        end
      end)
    else
      # Multi-kanji word - try to match based on position
      # For now, only handle first-position kanji
      text = wk.word.text
      first_kanji_pos = first_kanji_position(text)

      if wk.position == first_kanji_pos do
        # First kanji - try prefix matching
        Enum.find_value(readings, fn kr ->
          if String.starts_with?(word_reading, kr.reading) do
            kr.id
          else
            nil
          end
        end)
      else
        nil
      end
    end
  end

  defp matches_single_kanji_reading?(word_reading, %KanjiReading{} = kr) do
    # Direct match
    if word_reading == kr.reading do
      true
    else
      # Check if word reading starts with kanji reading (handles okurigana)
      String.starts_with?(word_reading, kr.reading)
    end
  end

  defp count_kanji(text) do
    text
    |> String.graphemes()
    |> Enum.count(fn char ->
      codepoint = :binary.first(char)

      (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or
        (codepoint >= 0x3400 and codepoint <= 0x4DBF)
    end)
  end

  defp first_kanji_position(text) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.find_value(fn {char, idx} ->
      codepoint = :binary.first(char)

      if (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or
           (codepoint >= 0x3400 and codepoint <= 0x4DBF) do
        idx
      else
        nil
      end
    end)
  end

  defp update_word_kanji(%WordKanji{} = wk, reading_id) do
    case Repo.update(Ecto.Changeset.change(wk, kanji_reading_id: reading_id)) do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Mix.shell().error("Failed to update #{wk.word.text}: #{inspect(changeset.errors)}")
        :error
    end
  end
end
