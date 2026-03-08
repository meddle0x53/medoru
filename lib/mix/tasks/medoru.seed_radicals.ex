defmodule Mix.Tasks.Medoru.SeedRadicals do
  @moduledoc """
  Seeds radical data from JSON files into existing kanji records.

  This imports radical information from the full kanji export files
  (kanji_*_full.json) which contain data from Make Me A Hanzi.

  ## Examples

      # Seed radicals for all JLPT levels
      mix medoru.seed_radicals --all

      # Seed radicals for specific level
      mix medoru.seed_radicals --level N5

      # Seed from custom file
      mix medoru.seed_radicals --file priv/repo/seeds/kanji_n5_full.json
  """

  use Mix.Task

  alias Medoru.Release.Seeds.Kanjidic2

  @shortdoc "Seed radical data for existing kanji"

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
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
        file = "priv/repo/seeds/kanji_#{String.downcase(level)}_full.json"
        seed_from_file(file)

      file = opts[:file] ->
        seed_from_file(file)

      true ->
        Mix.shell().info("""
        Usage:
          mix medoru.seed_radicals --all          # Seed radicals for all JLPT levels
          mix medoru.seed_radicals --level N5     # Seed radicals for specific level
          mix medoru.seed_radicals --file path    # Seed from custom file
        """)
    end
  end

  defp seed_all_levels do
    levels = ["n5", "n4", "n3", "n2", "n1"]

    Mix.shell().info("Seeding radical data for all JLPT levels...")

    total =
      Enum.reduce(levels, 0, fn level, acc ->
        file = "priv/repo/seeds/kanji_#{level}_full.json"
        Mix.shell().info("")
        Mix.shell().info("=== #{String.upcase(level)} ===")

        case seed_from_file(file) do
          {:ok, count} -> acc + count
          _ -> acc
        end
      end)

    Mix.shell().info("")
    Mix.shell().info("Radical data import complete! Total updated: #{total} kanji")
  end

  defp seed_from_file(file_path) do
    unless File.exists?(file_path) do
      Mix.shell().error("File not found: #{file_path}")
      Mix.shell().info("Make sure you've exported the kanji with radicals:")
      Mix.shell().info("  medoru-data export-full --level N5 --output data/seeds/kanji_n5_full.json")
      Mix.shell().info("  cp data/seeds/kanji_n5_full.json priv/repo/seeds/")
      {:error, :file_not_found}
    else
      Mix.shell().info("Importing radical data from #{file_path}...")

      case Kanjidic2.seed_radical_data(file_path) do
        {:ok, count} ->
          Mix.shell().info("Updated #{count} kanji with radical data")
          {:ok, count}

        {:error, reason} ->
          Mix.shell().error("Import failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
