defmodule Medoru.Content.KanjiComponents do
  @moduledoc """
  Decomposition-based components for kanji, plus a re-runnable backfill.

  The backfill reads the original seed JSON files and derives:
    - `radicals`   -> single classical radical (normalized to a canonical form)
    - `components` -> multi-component list extracted from the IDS decomposition

  This separates the classical radical browser (`/radicals`) from the component
  hunt game and the new `/components` browser.
  """

  import Ecto.Query

  alias Medoru.Repo
  alias Medoru.Content.{Kanji, KanjiDecompositionRadicals, KanjiRadicals, KanjiRadicalFixes}

  require Logger

  @seed_files [
    "kanji_n1_full.json",
    "kanji_n2_full.json",
    "kanji_n3_full.json",
    "kanji_n4_full.json",
    "kanji_n5_full.json",
    "missing_kanji_full.json"
  ]

  # ============================================================================
  # Backfill
  # ============================================================================

  @doc """
  Re-runnable backfill that populates `kanji.radicals` and `kanji.components`
  from the seed JSON files.

  Returns `{:ok, %{radicals_updated: n, components_updated: n}}`.
  """
  def backfill!(opts \\ []) do
    seeds_dir = Keyword.get(opts, :seeds_dir, default_seeds_dir())
    json_data = load_seed_data(seeds_dir)
    radical_fixes = KanjiRadicalFixes.fixes()

    kanji_list = Repo.all(from(k in Kanji, select: [:id, :character, :radicals, :components]))

    {radicals_updated, components_updated} =
      Enum.reduce(kanji_list, {0, 0}, fn kanji, {r_acc, c_acc} ->
        case Map.get(json_data, kanji.character) do
          nil ->
            {r_acc, c_acc}

          %{radical: raw_radical, decomposition: decomposition} ->
            canonical_radical = normalize_radical(raw_radical)

            {classical_radical, components} =
              case Map.fetch(radical_fixes, kanji.character) do
                {:ok, [fixed_radical | _]} ->
                  fixed_radical = normalize_radical(fixed_radical)
                  comps = compute_components(decomposition, fixed_radical)
                  {fixed_radical, comps}

                _ ->
                  comps = compute_components(decomposition, canonical_radical)
                  {canonical_radical, comps}
              end

            new_radicals = [classical_radical]
            new_components = Enum.uniq(components)

            changed? =
              kanji.radicals != new_radicals or kanji.components != new_components

            if changed? do
              Kanji
              |> Repo.get!(kanji.id)
              |> Ecto.Changeset.change(
                radicals: new_radicals,
                components: new_components
              )
              |> Repo.update!()

              r_delta = if kanji.radicals != new_radicals, do: 1, else: 0
              c_delta = if kanji.components != new_components, do: 1, else: 0

              {r_acc + r_delta, c_acc + c_delta}
            else
              {r_acc, c_acc}
            end
        end
      end)

    Logger.info(
      "KanjiComponents.backfill! complete: " <>
        "radicals_updated=#{radicals_updated}, components_updated=#{components_updated}"
    )

    {:ok, %{radicals_updated: radicals_updated, components_updated: components_updated}}
  end

  defp default_seeds_dir do
    Path.join([:code.priv_dir(:medoru), "repo", "seeds"])
  end

  defp load_seed_data(seeds_dir) do
    Enum.reduce(@seed_files, %{}, fn file, acc ->
      path = Path.join(seeds_dir, file)

      if File.exists?(path) do
        data =
          path
          |> File.read!()
          |> Jason.decode!()

        list = if is_list(data), do: data, else: data["kanji"] || []

        Enum.reduce(list, acc, fn entry, inner_acc ->
          character = entry["character"]

          if is_binary(character) and character != "" do
            Map.put(inner_acc, character, %{
              radical: entry["radical"] || character,
              decomposition: entry["decomposition"] || "？"
            })
          else
            inner_acc
          end
        end)
      else
        Logger.warning("KanjiComponents backfill: seed file not found: #{path}")
        acc
      end
    end)
  end

  defp normalize_radical(nil), do: nil

  defp normalize_radical(radical) do
    case KanjiRadicals.get(radical) do
      nil -> radical
      %{character: character} -> character
    end
  end

  defp compute_components(decomposition, fallback_radical) do
    components = KanjiDecompositionRadicals.extract_radicals(decomposition)

    components =
      if fallback_radical not in components and KanjiRadicals.radical?(fallback_radical) do
        [fallback_radical | components]
      else
        components
      end

    Enum.reject(components, &is_nil/1)
  end

  # ============================================================================
  # Catalog API
  # ============================================================================

  @doc """
  Returns every component currently stored on kanji, with frequency and metadata.
  """
  def all do
    component_counts()
    |> Enum.map(fn {character, frequency} ->
      radical = KanjiRadicals.get(character)

      %{
        character: character,
        meaning: radical && radical.meaning,
        frequency: frequency,
        stroke_count: radical && radical.stroke_count,
        category: radical && radical.category
      }
    end)
    |> Enum.sort_by(& &1.frequency, :desc)
  end

  @doc "Alias for all/0 sorted by frequency."
  def by_frequency, do: all()

  @doc """
  Looks up a single component by character. Returns metadata or nil.
  """
  def get(character) when is_binary(character) do
    case Enum.find(all(), &(&1.character == character)) do
      nil -> build_component_info(character, frequency(character))
      info -> info
    end
  end

  @doc """
  Returns the meaning for a component, or nil if unknown.
  """
  def meaning(character) when is_binary(character) do
    KanjiRadicals.meaning(character)
  end

  @doc """
  Returns true if the character is a known component/radical.
  """
  def component?(character) when is_binary(character) do
    KanjiRadicals.radical?(character)
  end

  def component?(nil), do: false

  @doc """
  Returns the number of kanji that contain this component.
  """
  def frequency(character) when is_binary(character) do
    Kanji
    |> where([k], ^character in k.components)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns the top kanji containing this component.
  """
  def top_kanji(character, limit \\ 50) when is_binary(character) do
    Kanji
    |> where([k], ^character in k.components)
    |> order_by([k], asc: k.frequency)
    |> limit(^limit)
    |> Repo.all()
  end

  defp component_counts do
    components =
      Kanji
      |> where([k], not is_nil(k.components) and k.components != [])
      |> select([k], k.components)
      |> Repo.all()

    components
    |> List.flatten()
    |> Enum.frequencies()
    |> Enum.reject(fn {char, _} -> is_nil(char) or char == "" end)
  end

  defp build_component_info(character, frequency) do
    radical = KanjiRadicals.get(character)

    %{
      character: character,
      meaning: radical && radical.meaning,
      frequency: frequency,
      stroke_count: radical && radical.stroke_count,
      category: radical && radical.category
    }
  end
end
