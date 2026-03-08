defmodule Mix.Tasks.Medoru.SeedKanji do
  @moduledoc """
  Seeds kanji data from JSON files into the database.

  ## Examples

      # Seed all JLPT levels
      mix medoru.seed_kanji --all

      # Seed specific level
      mix medoru.seed_kanji --level N5

      # Seed from custom file
      mix medoru.seed_kanji --file priv/repo/seeds/kanji_n5.json

      # Dry run (show what would be imported)
      mix medoru.seed_kanji --all --dry-run
  """

  use Mix.Task

  alias Medoru.Repo
  alias Medoru.Content
  alias Medoru.Content.{Kanji, KanjiReading}

  import Ecto.Query

  require Logger

  @shortdoc "Seed kanji data from JSON files"

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          all: :boolean,
          level: :string,
          file: :string,
          dry_run: :boolean
        ],
        aliases: [
          a: :all,
          l: :level,
          f: :file,
          d: :dry_run
        ]
      )

    # Start the application
    Mix.Task.run("app.start")

    dry_run = Keyword.get(opts, :dry_run, false)

    cond do
      opts[:all] ->
        seed_all_levels(dry_run)

      level = opts[:level] ->
        file = "priv/repo/seeds/kanji_#{String.downcase(level)}.json"
        seed_from_file(file, dry_run)

      file = opts[:file] ->
        seed_from_file(file, dry_run)

      true ->
        Mix.shell().info("""
        Usage:
          mix medoru.seed_kanji --all          # Seed all JLPT levels
          mix medoru.seed_kanji --level N5     # Seed specific level
          mix medoru.seed_kanji --file path    # Seed from custom file
          mix medoru.seed_kanji --all --dry-run # Preview what would be imported
        """)
    end
  end

  defp seed_all_levels(dry_run) do
    levels = ["n5", "n4", "n3", "n2", "n1"]

    Mix.shell().info("Seeding all JLPT levels...")
    if dry_run, do: Mix.shell().info("(DRY RUN - no changes will be made)")

    Enum.each(levels, fn level ->
      file = "priv/repo/seeds/kanji_#{level}.json"
      Mix.shell().info("")
      Mix.shell().info("=== #{String.upcase(level)} ===")
      seed_from_file(file, dry_run)
    end)

    unless dry_run do
      Mix.shell().info("")
      Mix.shell().info("All kanji imported successfully!")
      show_stats()
    end
  end

  defp seed_from_file(file_path, dry_run) do
    unless File.exists?(file_path) do
      Mix.shell().error("File not found: #{file_path}")

      Mix.shell().info(
        "Run: medoru-data kanji-data export --level N5 --output data/seeds/kanji_n5.json"
      )

      return()
    end

    Mix.shell().info("Loading #{file_path}...")

    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"kanji" => kanji_list} = data} ->
            meta = Map.get(data, "_meta", %{})

            Mix.shell().info("Source: #{meta["source"] || "unknown"}")
            Mix.shell().info("License: #{meta["license"] || "unknown"}")
            Mix.shell().info("Found #{length(kanji_list)} kanji to import")

            if dry_run do
              preview_import(kanji_list)
            else
              do_import(kanji_list)
            end

          {:error, reason} ->
            Mix.shell().error("Failed to parse JSON: #{inspect(reason)}")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to read file: #{inspect(reason)}")
    end
  end

  defp preview_import(kanji_list) do
    Enum.take(kanji_list, 5)
    |> Enum.each(fn k ->
      Mix.shell().info(
        "  #{k["character"]} - #{Enum.join(k["meanings"], ", ")} (N#{k["jlpt_level"]})"
      )
    end)

    if length(kanji_list) > 5 do
      Mix.shell().info("  ... and #{length(kanji_list) - 5} more")
    end

    Mix.shell().info("(Dry run - no changes made)")
  end

  defp do_import(kanji_list) do
    Enum.each(kanji_list, fn kanji_data ->
      import_kanji(kanji_data)
    end)

    Mix.shell().info("Import complete!")
  end

  defp import_kanji(%{"character" => character} = data) do
    # Check if kanji already exists
    existing = Repo.get_by(Kanji, character: character)

    if existing do
      # Update with new data if needed
      update_existing_kanji(existing, data)
    else
      create_new_kanji(data)
    end
  end

  defp create_new_kanji(data) do
    kanji_attrs =
      %{
        character: data["character"],
        meanings: data["meanings"] || [],
        stroke_count: data["stroke_count"],
        jlpt_level: data["jlpt_level"],
        frequency: data["frequency"],
        radicals: data["radicals"] || [],
        stroke_data: %{}
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    case Content.create_kanji(kanji_attrs) do
      {:ok, kanji} ->
        import_readings(kanji, data["readings"] || [])
        Mix.shell().info("  Created: #{kanji.character}")

      {:error, changeset} ->
        Mix.shell().error("  Failed to create #{data["character"]}: #{inspect(changeset.errors)}")
    end
  end

  defp update_existing_kanji(kanji, data) do
    # Update missing fields
    updates = %{}

    updates =
      if is_nil(kanji.jlpt_level) and data["jlpt_level"] do
        Map.put(updates, :jlpt_level, data["jlpt_level"])
      else
        updates
      end

    updates =
      if is_nil(kanji.stroke_count) and data["stroke_count"] do
        Map.put(updates, :stroke_count, data["stroke_count"])
      else
        updates
      end

    updates =
      if is_nil(kanji.frequency) and data["frequency"] do
        Map.put(updates, :frequency, data["frequency"])
      else
        updates
      end

    if map_size(updates) > 0 do
      case Content.update_kanji(kanji, updates) do
        {:ok, _} ->
          Mix.shell().info("  Updated: #{kanji.character}")

        {:error, changeset} ->
          Mix.shell().error("  Failed to update #{kanji.character}: #{inspect(changeset.errors)}")
      end
    end

    # Import missing readings
    kanji_id = kanji.id

    existing_readings =
      Repo.all(from r in KanjiReading, where: r.kanji_id == ^kanji_id)
      |> Enum.map(&{&1.reading_type, &1.reading})
      |> MapSet.new()

    new_readings =
      (data["readings"] || [])
      |> Enum.reject(fn r ->
        type = String.to_existing_atom(r["reading_type"])
        reading = r["reading"]
        MapSet.member?(existing_readings, {type, reading})
      end)

    import_readings(kanji, new_readings)
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
        # Ignore duplicates
        {:error, _} -> :ok
      end
    end)
  end

  defp show_stats do
    import Ecto.Query

    total_kanji = Repo.aggregate(Kanji, :count, :id)
    total_readings = Repo.aggregate(KanjiReading, :count, :id)

    by_level =
      Kanji
      |> group_by([k], k.jlpt_level)
      |> select([k], {k.jlpt_level, count(k.id)})
      |> Repo.all()
      |> Map.new()

    Mix.shell().info("")
    Mix.shell().info("Database Statistics:")
    Mix.shell().info("  Total Kanji: #{total_kanji}")
    Mix.shell().info("  Total Readings: #{total_readings}")
    Mix.shell().info("  By JLPT Level:")

    Enum.each([5, 4, 3, 2, 1], fn level ->
      count = Map.get(by_level, level, 0)
      Mix.shell().info("    N#{level}: #{count}")
    end)
  end

  defp return, do: :ok
end
