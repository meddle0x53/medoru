defmodule Medoru.Content.KanjiRadicalFix do
  @moduledoc """
  Hardcoded kanji → radical mapping extracted from Kanjidic2.
  Run `Medoru.Content.KanjiRadicalFix.apply/0` in a console to update the DB.
  """

  alias Medoru.Repo
  alias Medoru.Content.Kanji
  import Ecto.Query

  @mapping %{

  }

  @doc """
  Apply the radical fixes to the database.

  - Fixes kanji with nil or empty radicals
  - Skips kanji that already have a correct non-nil radical
  - Does not duplicate radicals
  """
  def apply do
    require Logger

    kanji_to_fix =
      Kanji
      |> where([k], fragment("array_length(?, 1) IS NULL OR array_length(?, 1) = 0", k.radicals, k.radicals))
      |> or_where([k], fragment("EXISTS (SELECT 1 FROM unnest(?) r WHERE r IS NULL)", k.radicals))
      |> Repo.all()

    fixed_count =
      Enum.reduce(kanji_to_fix, 0, fn kanji, count ->
        case Map.fetch(@mapping, kanji.character) do
          {:ok, radical} ->
            new_radicals =
              (kanji.radicals || [])
              |> Enum.reject(&is_nil/1)
              |> Enum.uniq()

            new_radicals =
              if radical in new_radicals do
                new_radicals
              else
                [radical | new_radicals]
              end

            kanji
            |> Ecto.Changeset.change(radicals: new_radicals)
            |> Repo.update!()

            count + 1

          :error ->
            Logger.warning("No radical mapping for kanji: #{kanji.character}")
            count
        end
      end)

    IO.puts("Fixed #{fixed_count} kanji radicals")
  end
end
