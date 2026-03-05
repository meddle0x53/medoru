# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

alias Medoru.Content

# Load N5 Kanji from JSON
n5_kanji_path = Path.join(__DIR__, "seeds/kanji_n5.json")

if File.exists?(n5_kanji_path) do
  n5_kanji =
    n5_kanji_path
    |> File.read!()
    |> Jason.decode!()

  IO.puts("Seeding #{length(n5_kanji)} N5 kanji...")

  Enum.each(n5_kanji, fn kanji_data ->
    readings_attrs = kanji_data["readings"]

    kanji_attrs = %{
      character: kanji_data["character"],
      meanings: kanji_data["meanings"],
      stroke_count: kanji_data["stroke_count"],
      jlpt_level: kanji_data["jlpt_level"],
      frequency: kanji_data["frequency"],
      radicals: kanji_data["radicals"],
      stroke_data: %{}
    }

    # Convert reading data to atom keys
    readings_attrs =
      Enum.map(readings_attrs, fn reading ->
        %{
          reading_type: String.to_atom(reading["reading_type"]),
          reading: reading["reading"],
          romaji: reading["romaji"],
          usage_notes: Map.get(reading, "usage_notes")
        }
      end)

    case Content.create_kanji_with_readings(kanji_attrs, readings_attrs) do
      {:ok, _kanji} ->
        IO.puts("  ✓ Created kanji: #{kanji_data["character"]}")

      {:error, changeset} ->
        IO.puts("  ✗ Failed to create kanji: #{kanji_data["character"]}")
        IO.inspect(changeset.errors, label: "Errors")
    end
  end)

  IO.puts("\nSeeding complete!")
  IO.puts("Total kanji: #{Enum.count(Content.list_kanji())}")
  IO.puts("Total readings: #{Enum.count(Content.list_kanji_readings())}")
else
  IO.puts("Warning: #{n5_kanji_path} not found. Skipping kanji seeds.")
end
