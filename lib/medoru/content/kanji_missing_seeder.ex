defmodule Medoru.Content.KanjiMissingSeeder do
  @moduledoc """
  Seeds missing kanji into the database from a packaged JSON file.

  This module is designed to be run in a remote console in production
  to add kanji that appear in words but were not included in the initial
  N1-N5 kanji seed.

  ## Usage

      # In a remote console (iex):
      Medoru.Content.KanjiMissingSeeder.run()

      # Or with a specific subset of characters:
      Medoru.Content.KanjiMissingSeeder.run(characters: ["廻", "阪"])

  The data is read from `priv/repo/seeds/missing_kanji_full.json` which is
  packaged with the release.
  """

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Kanji, KanjiReading}

  import Ecto.Query

  require Logger

  @seed_file "priv/repo/seeds/missing_kanji_full.json"

  @doc """
  Runs the missing kanji seeder.

  ## Options

    * `:characters` - List of specific characters to seed. If not provided,
      all missing kanji from the seed file are inserted.

  ## Examples

      Medoru.Content.KanjiMissingSeeder.run()
      Medoru.Content.KanjiMissingSeeder.run(characters: ["廻", "阪"])
  """
  def run(opts \\ []) do
    target_chars = Keyword.get(opts, :characters)

    seed_file =
      if File.exists?(@seed_file) do
        @seed_file
      else
        # In a release, priv is under the application directory
        Path.join([:code.priv_dir(:medoru), "repo", "seeds", "missing_kanji_full.json"])
      end

    unless File.exists?(seed_file) do
      Logger.error("Missing kanji seed file not found: #{seed_file}")
      return()
    end

    Logger.info("Loading missing kanji data from #{seed_file}...")

    case File.read(seed_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"kanji" => kanji_list, "_meta" => meta}} ->
            Logger.info("Seed file contains #{meta["count"]} kanji")
            Logger.info("  With stroke data: #{meta["with_stroke_data"]}")
            Logger.info("  With radical data: #{meta["with_radical_data"]}")

            kanji_to_import =
              if target_chars do
                target_set = MapSet.new(target_chars)
                Enum.filter(kanji_list, fn k -> MapSet.member?(target_set, k["character"]) end)
              else
                kanji_list
              end

            Logger.info("Importing #{length(kanji_to_import)} kanji...")
            do_import(kanji_to_import)

          {:error, reason} ->
            Logger.error("Failed to parse JSON: #{inspect(reason)}")
            {:error, :json_parse_error}
        end

      {:error, reason} ->
        Logger.error("Failed to read file: #{inspect(reason)}")
        {:error, :file_read_error}
    end
  end

  defp do_import(kanji_list) do
    results =
      Enum.reduce(kanji_list, %{created: 0, updated: 0, skipped: 0, errors: []}, fn kanji_data,
                                                                                     acc ->
        case import_kanji(kanji_data) do
          {:ok, :created} -> Map.update!(acc, :created, &(&1 + 1))
          {:ok, :skipped} -> Map.update!(acc, :skipped, &(&1 + 1))
          {:error, reason} ->
            acc
            |> Map.update!(:errors, &[reason | &1])
            |> Map.update!(:skipped, &(&1 + 1))
        end
      end)

    Logger.info("")
    Logger.info("Missing kanji import complete!")
    Logger.info("  Created: #{results.created}")
    Logger.info("  Updated: #{results.updated}")
    Logger.info("  Skipped: #{results.skipped}")

    if results.errors != [] do
      Logger.warning("  Errors: #{length(results.errors)}")
      Enum.take(results.errors, 10)
      |> Enum.each(fn err -> Logger.warning("    #{err}") end)
    end

    show_stats()
    {:ok, results}
  end

  defp import_kanji(%{"character" => character} = data) do
    existing = Repo.get_by(Kanji, character: character)

    if existing do
      Logger.debug("Kanji already exists: #{character}")
      {:ok, :skipped}
    else
      create_new_kanji(data)
    end
  end

  defp create_new_kanji(data) do
    stroke_data = data["stroke_data"] || %{}

    # Merge decomposition and etymology into stroke_data
    stroke_data =
      if data["decomposition"] do
        Map.put(stroke_data, "decomposition", data["decomposition"])
      else
        stroke_data
      end

    stroke_data =
      if data["etymology"] do
        Map.put(stroke_data, "etymology", data["etymology"])
      else
        stroke_data
      end

    kanji_attrs = %{
      character: data["character"],
      meanings: data["meanings"] || [],
      stroke_count: data["stroke_count"],
      jlpt_level: data["jlpt_level"],
      frequency: data["frequency"],
      radicals: data["radicals"] || [],
      stroke_data: stroke_data
    }

    case Content.create_kanji(kanji_attrs) do
      {:ok, kanji} ->
        import_readings(kanji, data["readings"] || [])
        Logger.debug("Created kanji: #{kanji.character}")
        {:ok, :created}

      {:error, changeset} ->
        Logger.error(
          "Failed to create kanji #{data["character"]}: #{inspect(changeset.errors)}"
        )

        {:error, "#{data["character"]}: #{inspect(changeset.errors)}"}
    end
  end

  defp import_readings(kanji, readings) when is_list(readings) do
    Enum.each(readings, fn reading_data ->
      reading_attrs = %{
        kanji_id: kanji.id,
        reading_type: String.to_existing_atom(reading_data["reading_type"]),
        reading: reading_data["reading"],
        romaji: reading_data["romaji"] || ""
      }

      case Content.create_kanji_reading(reading_attrs) do
        {:ok, _} -> :ok
        {:error, _} -> :ok
      end
    end)
  end

  defp show_stats do
    total_kanji = Repo.aggregate(Kanji, :count, :id)
    total_readings = Repo.aggregate(KanjiReading, :count, :id)

    by_level =
      Kanji
      |> group_by([k], k.jlpt_level)
      |> select([k], {k.jlpt_level, count(k.id)})
      |> Repo.all()
      |> Map.new()

    Logger.info("")
    Logger.info("Database Statistics:")
    Logger.info("  Total Kanji: #{total_kanji}")
    Logger.info("  Total Readings: #{total_readings}")
    Logger.info("  By JLPT Level:")

    Enum.each([5, 4, 3, 2, 1, nil], fn level ->
      count = Map.get(by_level, level, 0)
      label = if level, do: "N#{level}", else: "Unclassified"
      Logger.info("    #{label}: #{count}")
    end)
  end

  defp return, do: :ok
end
