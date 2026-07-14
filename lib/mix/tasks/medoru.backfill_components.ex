defmodule Mix.Tasks.Medoru.BackfillComponents do
  @moduledoc """
  Re-runnable backfill that populates `kanji.radicals` and `kanji.components`.

  Reads the full kanji export files (kanji_*_full.json) and derives:
    - `radicals`   -> single classical radical, normalized to a canonical form
    - `components` -> multi-component list extracted from the IDS decomposition

  ## Examples

      mix medoru.backfill_components

      mix medoru.backfill_components --seeds-dir priv/repo/seeds
  """

  use Mix.Task

  alias Medoru.Content.KanjiComponents

  @shortdoc "Backfill kanji radicals and components from seed JSON"

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: ["seeds-dir": :string],
        aliases: [d: :"seeds-dir"]
      )

    Mix.Task.run("app.start")

    Mix.shell().info("Backfilling kanji radicals and components...")

    opts =
      case opts[:"seeds-dir"] do
        nil -> []
        dir -> [seeds_dir: dir]
      end

    {:ok, %{radicals_updated: r, components_updated: c}} = KanjiComponents.backfill!(opts)

    Mix.shell().info("Backfill complete!")
    Mix.shell().info("  Radicals updated:   #{r}")
    Mix.shell().info("  Components updated: #{c}")
  end
end
