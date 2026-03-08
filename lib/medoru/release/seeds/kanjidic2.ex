defmodule Medoru.Release.Seeds.Kanjidic2 do
  @moduledoc """
  Seeds kanji and readings from KANJIDIC2 export files.

  KANJIDIC2 provides:
  - Kanji characters with stroke counts
  - JLPT levels
  - Meanings (English translations)
  - On'yomi (katakana) and Kun'yomi (hiragana) readings
  - Frequency rankings
  - Radical information

  Data source: KANJIDIC2 by EDRG (Electronic Dictionary Research and Development Group)
  License: CC BY-SA 4.0
  """

  alias Medoru.Content
  alias Medoru.Content.{Kanji, KanjiReading}
  alias Medoru.Repo

  import Ecto.Query

  require Logger

  @seed_file "priv/repo/seeds/kanjidic2.json"

  @doc """
  Seed kanji from KANJIDIC2 JSON export.
  """
  def seed do
    Logger.info("Seeding kanji from KANJIDIC2...")

    seed_file = Path.join(File.cwd!(), @seed_file)

    if File.exists?(seed_file) do
      seed_from_file(seed_file)
    else
      Logger.warning("KANJIDIC2 seed file not found: #{seed_file}")

      Logger.info(
        "Run: medoru-data kanjidic2 export --level all --output data/seeds/kanjidic2.json"
      )

      :ok
    end
  end

  @doc """
  Seed radical data and additional metadata from a JSON file.
  Imports: radicals, decomposition, etymology into stroke_data.
  """
  def seed_radical_data(path) do
    Logger.info("Seeding radical and etymology data from #{path}...")

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"kanji" => kanji_list}} ->
            updated_count =
              Enum.reduce(kanji_list, 0, fn kanji_data, count ->
                char = kanji_data["character"]
                radical = kanji_data["radical"]
                radicals = kanji_data["radicals"]
                decomposition = kanji_data["decomposition"]
                etymology = kanji_data["etymology"]

                if char do
                  case Repo.get_by(Kanji, character: char) do
                    nil ->
                      Logger.warning("Kanji not found: #{char}")
                      count

                    kanji ->
                      # Build updates using reduce pattern
                      updates = %{}

                      # Update radicals
                      radical_list = radicals || [radical]
                      current_radicals = kanji.radicals || []
                      updates =
                        if radical_list != [] and radical_list != current_radicals do
                          Map.put(updates, :radicals, radical_list)
                        else
                          updates
                        end

                      # Update stroke_data with decomposition and etymology
                      stroke_data = kanji.stroke_data || %{}

                      stroke_data =
                        if decomposition do
                          Map.put(stroke_data, "decomposition", decomposition)
                        else
                          stroke_data
                        end

                      stroke_data =
                        if etymology do
                          Map.put(stroke_data, "etymology", etymology)
                        else
                          stroke_data
                        end

                      original_stroke_data = kanji.stroke_data || %{}
                      updates =
                        if stroke_data != original_stroke_data do
                          Map.put(updates, :stroke_data, stroke_data)
                        else
                          updates
                        end

                      if map_size(updates) > 0 do
                        case Content.update_kanji(kanji, updates) do
                          {:ok, _} ->
                            Logger.debug("Updated metadata for: #{char}")
                            count + 1

                          {:error, changeset} ->
                            Logger.error(
                              "Failed to update metadata for #{char}: #{inspect(changeset.errors)}"
                            )
                            count
                        end
                      else
                        count
                      end
                  end
                else
                  count
                end
              end)

            Logger.info("Metadata import complete! Updated #{updated_count} kanji.")
            {:ok, updated_count}

          {:error, reason} ->
            Logger.error("Failed to parse JSON: #{inspect(reason)}")
            {:error, :json_parse_error}
        end

      {:error, reason} ->
        Logger.error("Failed to read file: #{inspect(reason)}")
        {:error, :file_read_error}
    end
  end

  @doc """
  Seed only stroke data from a JSON file (for updating existing kanji).
  """
  def seed_stroke_data(path) do
    Logger.info("Seeding stroke data from #{path}...")

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"kanji" => kanji_list}} ->
            updated_count =
              Enum.reduce(kanji_list, 0, fn kanji_data, count ->
                char = kanji_data["character"]
                stroke_data = kanji_data["stroke_data"]

                if char && stroke_data not in [nil, %{}] do
                  case Repo.get_by(Kanji, character: char) do
                    nil ->
                      Logger.warning("Kanji not found: #{char}")
                      count

                    kanji ->
                      if kanji.stroke_data == %{} or is_nil(kanji.stroke_data) do
                        case Content.update_kanji(kanji, %{stroke_data: stroke_data}) do
                          {:ok, _} ->
                            Logger.debug("Updated stroke data for: #{char}")
                            count + 1

                          {:error, changeset} ->
                            Logger.error(
                              "Failed to update stroke data for #{char}: #{inspect(changeset.errors)}"
                            )

                            count
                        end
                      else
                        count
                      end
                  end
                else
                  count
                end
              end)

            Logger.info("Stroke data import complete! Updated #{updated_count} kanji.")
            {:ok, updated_count}

          {:error, reason} ->
            Logger.error("Failed to parse JSON: #{inspect(reason)}")
            {:error, :json_parse_error}
        end

      {:error, reason} ->
        Logger.error("Failed to read file: #{inspect(reason)}")
        {:error, :file_read_error}
    end
  end

  @doc """
  Seed kanji from a specific JSON file.
  """
  def seed_from_file(path) do
    Logger.info("Loading KANJIDIC2 data from #{path}...")

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"kanji" => kanji_list} = data} ->
            count = length(kanji_list)
            meta = Map.get(data, "_meta", %{})

            Logger.info("Found #{count} kanji to import")
            Logger.debug("Source: #{meta["source"] || "unknown"}")
            Logger.debug("License: #{meta["license"] || "unknown"}")

            import_kanji_list(kanji_list)

          {:error, reason} ->
            Logger.error("Failed to parse JSON: #{inspect(reason)}")
            {:error, :json_parse_error}
        end

      {:error, reason} ->
        Logger.error("Failed to read file: #{inspect(reason)}")
        {:error, :file_read_error}
    end
  end

  defp import_kanji_list(kanji_list) do
    Repo.transaction(fn ->
      kanji_list
      |> Enum.with_index()
      |> Enum.each(fn {kanji_data, index} ->
        import_kanji(kanji_data)

        # Log progress every 100 kanji
        if rem(index + 1, 100) == 0 do
          Logger.info("Imported #{index + 1}/#{length(kanji_list)} kanji...")
        end
      end)
    end)

    stats = get_import_stats()
    Logger.info("KANJIDIC2 import complete!")
    Logger.info("Total kanji: #{stats.total_kanji}")
    Logger.info("Total readings: #{stats.total_readings}")

    {:ok, stats}
  rescue
    e ->
      Logger.error("Import failed: #{Exception.message(e)}")
      {:error, e}
  end

  defp import_kanji(%{"character" => character} = data) do
    # Check if kanji already exists
    existing = Repo.get_by(Kanji, character: character)

    if existing do
      # Update existing kanji with KANJIDIC2 data
      update_existing_kanji(existing, data)
    else
      # Create new kanji
      create_new_kanji(data)
    end
  end

  defp create_new_kanji(data) do
    stroke_data = data["stroke_data"] || %{}

    kanji_attrs =
      %{
        character: data["character"],
        meanings: data["meanings"] || [],
        stroke_count: data["stroke_count"],
        jlpt_level: data["jlpt_level"],
        frequency: data["frequency"],
        radicals: data["radicals"] || [],
        stroke_data: stroke_data
      }
      # Remove nil values
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    case Content.create_kanji(kanji_attrs) do
      {:ok, kanji} ->
        # Import readings if present
        readings = data["readings"] || []
        import_readings(kanji, readings)
        {:ok, kanji}

      {:error, changeset} ->
        Logger.warning(
          "Failed to create kanji #{data["character"]}: #{inspect(changeset.errors)}"
        )

        {:error, changeset}
    end
  end

  defp update_existing_kanji(kanji, data) do
    # Only update fields that are nil or empty in the existing record
    updates = %{}

    updates =
      if is_nil(kanji.jlpt_level) and data["jlpt_level"] do
        Map.put(updates, :jlpt_level, data["jlpt_level"])
      else
        updates
      end

    updates =
      if is_nil(kanji.frequency) and data["frequency"] do
        Map.put(updates, :frequency, data["frequency"])
      else
        updates
      end

    updates =
      if Enum.empty?(kanji.radicals) and data["radicals"] do
        Map.put(updates, :radicals, data["radicals"])
      else
        updates
      end

    # Update stroke_data if it's empty and we have new stroke data
    updates =
      if (is_nil(kanji.stroke_data) or kanji.stroke_data == %{}) and
           data["stroke_data"] not in [nil, %{}] do
        Map.put(updates, :stroke_data, data["stroke_data"])
      else
        updates
      end

    # Update if we have any changes
    if map_size(updates) > 0 do
      case Content.update_kanji(kanji, updates) do
        {:ok, updated} ->
          # Import any missing readings
          existing_readings =
            Repo.all(from r in KanjiReading, where: r.kanji_id == ^updated.id)
            |> Enum.map(&{&1.reading_type, &1.reading})
            |> MapSet.new()

          new_readings =
            (data["readings"] || [])
            |> Enum.reject(fn r ->
              type = String.to_atom(r["reading_type"])
              reading = r["reading"]
              MapSet.member?(existing_readings, {type, reading})
            end)

          import_readings(updated, new_readings)
          {:ok, updated}

        {:error, changeset} ->
          Logger.warning(
            "Failed to update kanji #{kanji.character}: #{inspect(changeset.errors)}"
          )

          {:error, changeset}
      end
    else
      {:ok, kanji}
    end
  end

  defp import_readings(kanji, readings) when is_list(readings) do
    Enum.each(readings, fn reading_data ->
      reading_attrs = %{
        kanji_id: kanji.id,
        reading_type: String.to_atom(reading_data["reading_type"]),
        reading: reading_data["reading"],
        romaji: reading_data["romaji"] || "",
        usage_notes: reading_data["usage_notes"] || ""
      }

      case Content.create_kanji_reading(reading_attrs) do
        {:ok, _reading} ->
          :ok

        {:error, changeset} ->
          # Log but don't fail - duplicate readings are expected
          if Enum.any?(changeset.errors, fn {_, {msg, _}} ->
               String.contains?(msg, "has already been taken")
             end) do
            :ok
          else
            Logger.warning(
              "Failed to create reading for #{kanji.character}: #{inspect(changeset.errors)}"
            )
          end
      end
    end)
  end

  defp get_import_stats do
    import Ecto.Query

    total_kanji = Repo.aggregate(Kanji, :count, :id)
    total_readings = Repo.aggregate(KanjiReading, :count, :id)

    by_level =
      Kanji
      |> group_by([k], k.jlpt_level)
      |> select([k], {k.jlpt_level, count(k.id)})
      |> Repo.all()
      |> Map.new()

    %{
      total_kanji: total_kanji,
      total_readings: total_readings,
      by_level: by_level
    }
  end
end
