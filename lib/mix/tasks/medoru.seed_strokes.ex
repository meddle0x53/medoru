defmodule Mix.Tasks.Medoru.SeedStrokes do
  @moduledoc """
  Seeds stroke data from JSON files into existing kanji records.

  This is useful when you've already imported kanji metadata and now want to
  add stroke animation data without re-importing everything.

  ## Examples

      # Seed strokes for all JLPT levels
      mix medoru.seed_strokes --all

      # Seed strokes for specific level
      mix medoru.seed_strokes --level N5

      # Seed from custom file
      mix medoru.seed_strokes --file priv/repo/seeds/kanji_n5_with_strokes.json
  """

  use Mix.Task

  alias Medoru.Release.Seeds.Kanjidic2

  @shortdoc "Seed stroke data for existing kanji"

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          all: :boolean,
          level: :string,
          file: :string
        ],
        aliases: [
          a: :all,
          l: :level,
          f: :file
        ]
      )

    # Start the application
    Mix.Task.run("app.start")

    cond do
      opts[:all] ->
        seed_all_levels()

      level = opts[:level] ->
        file = "priv/repo/seeds/kanji_#{String.downcase(level)}_with_strokes.json"
        seed_from_file(file)

      file = opts[:file] ->
        seed_from_file(file)

      true ->
        Mix.shell().info("""
        Usage:
          mix medoru.seed_strokes --all          # Seed strokes for all JLPT levels
          mix medoru.seed_strokes --level N5     # Seed strokes for specific level
          mix medoru.seed_strokes --file path    # Seed from custom file
        """)
    end
  end

  defp seed_all_levels do
    levels = ["n5", "n4", "n3", "n2", "n1"]

    Mix.shell().info("Seeding stroke data for all JLPT levels...")

    total =
      Enum.reduce(levels, 0, fn level, acc ->
        file = "priv/repo/seeds/kanji_#{level}_with_strokes.json"
        Mix.shell().info("")
        Mix.shell().info("=== #{String.upcase(level)} ===")

        case seed_from_file(file) do
          {:ok, count} -> acc + count
          _ -> acc
        end
      end)

    Mix.shell().info("")
    Mix.shell().info("Stroke data import complete! Total updated: #{total} kanji")
  end

  defp seed_from_file(file_path) do
    unless File.exists?(file_path) do
      Mix.shell().error("File not found: #{file_path}")
      Mix.shell().info("Make sure you've exported the kanji with strokes:")

      Mix.shell().info(
        "  medoru-data kanji-data export-with-strokes --level N5 --output data/seeds/kanji_n5_with_strokes.json"
      )

      Mix.shell().info("  cp data/seeds/kanji_n5_with_strokes.json priv/repo/seeds/")
      {:error, :file_not_found}
    else
      Mix.shell().info("Importing stroke data from #{file_path}...")

      case Kanjidic2.seed_stroke_data(file_path) do
        {:ok, count} ->
          Mix.shell().info("Updated #{count} kanji with stroke data")
          {:ok, count}

        {:error, reason} ->
          Mix.shell().error("Import failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
