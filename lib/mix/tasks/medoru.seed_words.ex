defmodule Mix.Tasks.Medoru.SeedWords do
  @moduledoc """
  Seeds word/vocabulary data from JSON files into the database.

  ## Examples

      # Seed from default N5 words file
      mix medoru.seed_words

      # Seed from specific file
      mix medoru.seed_words --file priv/repo/seeds/words_n5.json

      # Seed from JMdict-generated file
      mix medoru.seed_words --file priv/repo/seeds/words_jmdict_n5.json

      # Dry run (show what would be imported)
      mix medoru.seed_words --file words.json --dry-run
  """

  use Mix.Task

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Word, WordKanji}

  import Ecto.Query

  require Logger

  @shortdoc "Seed word/vocabulary data from JSON files"

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          file: :string,
          dry_run: :boolean
        ],
        aliases: [
          f: :file,
          d: :dry_run
        ]
      )

    # Start the application
    Mix.Task.run("app.start")

    dry_run = Keyword.get(opts, :dry_run, false)
    file = Keyword.get(opts, :file, "priv/repo/seeds/words_n5.json")

    seed_from_file(file, dry_run)
  end

  defp seed_from_file(file_path, dry_run) do
    unless File.exists?(file_path) do
      Mix.shell().error("File not found: #{file_path}")

      Mix.shell().info("""

      To generate word data from JMdict:
        cd data
        medoru-data jmdict download
        medoru-data jmdict export-for-seeding \\
          --kanji "日,月,火,水,木,金,土,..." \\
          --max-per-kanji 10 \\
          --output ../priv/repo/seeds/words_custom.json
      """)

      return()
    end

    Mix.shell().info("Loading #{file_path}...")

    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, word_list} when is_list(word_list) ->
            Mix.shell().info("Found #{length(word_list)} words to import")

            if dry_run do
              preview_import(word_list)
            else
              do_import(word_list)
            end

          {:ok, %{"words" => word_list}} when is_list(word_list) ->
            Mix.shell().info("Found #{length(word_list)} words to import")

            if dry_run do
              preview_import(word_list)
            else
              do_import(word_list)
            end

          {:ok, %{"words_by_kanji" => words_by_kanji}} when is_map(words_by_kanji) ->
            # Flatten the words_by_kanji structure
            word_list =
              words_by_kanji
              |> Map.values()
              |> List.flatten()
              |> Enum.uniq_by(& &1["text"])

            Mix.shell().info("Found #{length(word_list)} unique words to import")

            if dry_run do
              preview_import(word_list)
            else
              do_import(word_list)
            end

          {:error, reason} ->
            Mix.shell().error("Failed to parse JSON: #{inspect(reason)}")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to read file: #{inspect(reason)}")
    end
  end

  defp preview_import(word_list) do
    Enum.take(word_list, 5)
    |> Enum.each(fn w ->
      kanji_str = Enum.map(w["kanji"] || [], & &1["character"]) |> Enum.join(", ")
      Mix.shell().info("  #{w["text"]} (#{w["reading"]}) - #{w["meaning"]}")
      Mix.shell().info("    Kanji: #{kanji_str}")
    end)

    if length(word_list) > 5 do
      Mix.shell().info("  ... and #{length(word_list) - 5} more")
    end

    Mix.shell().info("(Dry run - no changes made)")
  end

  defp do_import(word_list) do
    # Build a lookup map of kanji character to kanji record with readings
    kanji_map =
      Content.list_kanji()
      |> Repo.preload(:kanji_readings)
      |> Map.new(fn kanji -> {kanji.character, kanji} end)

    Mix.shell().info("Found #{map_size(kanji_map)} kanji in database")

    imported = Enum.reduce(word_list, 0, fn word_data, count ->
      case import_word(word_data, kanji_map) do
        :ok -> count + 1
        :error -> count
      end
    end)

    Mix.shell().info("")
    Mix.shell().info("Import complete! Imported #{imported}/#{length(word_list)} words")
    show_stats()
  end

  defp import_word(word_data, kanji_map) do
    word_attrs = %{
      text: word_data["text"],
      meaning: word_data["meaning"],
      reading: word_data["reading"],
      difficulty: normalize_difficulty(word_data["difficulty"]),
      usage_frequency: word_data["usage_frequency"] || 1000,
      word_type: normalize_word_type(word_data["word_type"])
    }

    # Build kanji links for this word
    kanji_links =
      Enum.map(word_data["kanji"] || [], fn kanji_data ->
        character = kanji_data["character"]
        position = kanji_data["position"]
        reading_text = kanji_data["reading"] || ""

        case Map.get(kanji_map, character) do
          nil ->
            Mix.shell().info("  ⚠ Kanji not found: #{character}")
            nil

          kanji ->
            # Find the reading that matches
            reading_id =
              if reading_text != "" do
                Enum.find_value(kanji.kanji_readings, nil, fn reading ->
                  if reading.reading == reading_text, do: reading.id, else: nil
                end)
              else
                nil
              end

            %{
              position: position,
              kanji_id: kanji.id,
              kanji_reading_id: reading_id
            }
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Only create if we found all kanji
    if length(kanji_links) == length(word_data["kanji"] || []) and length(kanji_links) > 0 do
      # Check if word already exists
      existing = Repo.get_by(Word, text: word_attrs.text)

      cond do
        existing && should_update?(existing, word_attrs) ->
          # Update existing word with new classification
          case Content.update_word(existing, %{
            word_type: word_attrs.word_type,
            difficulty: word_attrs.difficulty
          }) do
            {:ok, _word} ->
              Mix.shell().info("  ⟳ Updated word: #{word_attrs.text} (type: #{word_attrs.word_type}, difficulty: #{word_attrs.difficulty})")
              :ok

            {:error, changeset} ->
              Mix.shell().error("  ✗ Failed to update word: #{word_attrs.text}")
              IO.inspect(changeset.errors, label: "Errors")
              :error
          end

        existing ->
          Mix.shell().info("  ⚠ Word already exists: #{word_attrs.text}")
          :ok

        true ->
          case Content.create_word_with_kanji(word_attrs, kanji_links) do
            {:ok, _word} ->
              Mix.shell().info("  ✓ Created word: #{word_attrs.text}")
              :ok

            {:error, changeset} ->
              Mix.shell().error("  ✗ Failed to create word: #{word_attrs.text}")
              IO.inspect(changeset.errors, label: "Errors")
              :error
          end
      end
    else
      Mix.shell().info("  ⚠ Skipped word (missing kanji): #{word_attrs.text}")
      :error
    end
  end

  # Check if existing word should be updated with new classification
  defp should_update?(existing, new_attrs) do
    # Update if word_type changed from default :other
    type_changed = existing.word_type == :other && new_attrs.word_type != :other
    
    # Update if difficulty changed from default 3
    difficulty_changed = existing.difficulty == 3 && new_attrs.difficulty != 3
    
    type_changed || difficulty_changed
  end

  # Normalize difficulty to 1-5 scale
  defp normalize_difficulty(nil), do: 3
  defp normalize_difficulty(d) when is_integer(d) and d >= 1 and d <= 5, do: d
  defp normalize_difficulty(d) when is_integer(d) and d > 5, do: 5
  defp normalize_difficulty(d) when is_integer(d) and d < 1, do: 1
  # If difficulty is 1-100, map to 1-5
  defp normalize_difficulty(d) when is_integer(d), do: max(1, min(5, div(d, 20) + 1))
  defp normalize_difficulty(_), do: 3

  # Normalize word type to atom
  defp normalize_word_type(nil), do: :other
  defp normalize_word_type(type) when is_atom(type), do: type
  defp normalize_word_type(type) when is_binary(type) do
    case String.downcase(type) do
      "noun" -> :noun
      "verb" -> :verb
      "adjective" -> :adjective
      "adverb" -> :adverb
      "particle" -> :particle
      "pronoun" -> :pronoun
      "counter" -> :counter
      "expression" -> :expression
      _ -> :other
    end
  end
  defp normalize_word_type(_), do: :other

  defp show_stats do
    total_words = Repo.aggregate(Word, :count, :id)
    total_links = Repo.aggregate(WordKanji, :count, :id)

    by_type =
      Word
      |> group_by([w], w.word_type)
      |> select([w], {w.word_type, count(w.id)})
      |> Repo.all()
      |> Map.new()

    Mix.shell().info("")
    Mix.shell().info("Database Statistics:")
    Mix.shell().info("  Total Words: #{total_words}")
    Mix.shell().info("  Word-Kanji Links: #{total_links}")
    Mix.shell().info("  By Type:")

    Enum.each([:noun, :verb, :adjective, :expression, :other], fn type ->
      count = Map.get(by_type, type, 0)
      Mix.shell().info("    #{type}: #{count}")
    end)
  end

  defp return, do: :ok
end
