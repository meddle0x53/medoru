alias Medoru.Repo
alias Medoru.Content.Kanji

source_path = "lib/medoru/content/kanji_decomposition_radicals.ex"
source = File.read!(source_path)

# Extract the @fixes map literal from the source file and evaluate it.
fixes =
  case Regex.run(~r/@fixes %\{((?:.|\n)*?)\}\n\n  @doc/, source, capture: :all_but_first) do
    [map_string] ->
      {map, _} = Code.eval_string("%{" <> map_string <> "}", [], file: source_path)
      map

    _ ->
      IO.puts("Could not parse @fixes map from #{source_path}")
      exit(:normal)
  end

kanji_by_char =
  Repo.all(Kanji)
  |> Enum.map(&{&1.character, &1})
  |> Map.new()

missing_in_db =
  Enum.reduce(fixes, [], fn {char, expected_radicals}, acc ->
    case Map.get(kanji_by_char, char) do
      nil ->
        [{char, :missing} | acc]

      kanji ->
        db_radicals = MapSet.new(kanji.radicals || [])
        expected_set = MapSet.new(expected_radicals)
        missing = MapSet.difference(expected_set, db_radicals) |> MapSet.to_list() |> Enum.sort()

        if missing == [] do
          acc
        else
          [{char, kanji.radicals, missing} | acc]
        end
    end
  end)

extra_in_db =
  Enum.reduce(fixes, [], fn {char, expected_radicals}, acc ->
    case Map.get(kanji_by_char, char) do
      nil ->
        acc

      kanji ->
        db_radicals = MapSet.new(kanji.radicals || [])
        expected_set = MapSet.new(expected_radicals)
        extra = MapSet.difference(db_radicals, expected_set) |> MapSet.to_list() |> Enum.sort()

        if extra == [] do
          acc
        else
          [{char, kanji.radicals, extra} | acc]
        end
    end
  end)

IO.puts("=" |> String.duplicate(70))
IO.puts("KanjiDecompositionRadicals vs DB check")
IO.puts("=" |> String.duplicate(70))
IO.puts("Entries in hardcoded @fixes: #{map_size(fixes)}")
IO.puts("Kanji in DB: #{map_size(kanji_by_char)}")
IO.puts("")

IO.puts("Hardcoded radicals missing from DB: #{length(missing_in_db)} entries")

if missing_in_db != [] do
  missing_in_db
  |> Enum.sort_by(fn {char, _, _} -> char end)
  |> Enum.each(fn
    {char, :missing} ->
      IO.puts("  #{char}: kanji not in DB")

    {char, db_radicals, missing} ->
      IO.puts("  #{char}: DB #{inspect(db_radicals)} is missing #{inspect(missing)}")
  end)
end

IO.puts("")
IO.puts("DB radicals not listed in hardcoded @fixes: #{length(extra_in_db)} entries")

if extra_in_db != [] do
  extra_in_db
  |> Enum.sort_by(fn {char, _, _} -> char end)
  |> Enum.take(100)
  |> Enum.each(fn {char, db_radicals, extra} ->
    IO.puts("  #{char}: DB #{inspect(db_radicals)} has extra #{inspect(extra)}")
  end)
end

IO.puts("")
IO.puts("Check complete.")
