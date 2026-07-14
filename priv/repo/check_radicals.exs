alias Medoru.Repo
alias Medoru.Content.Kanji
alias Medoru.Content.KanjiRadicals
alias Medoru.Content.KanjiRadicalFixes

# Load all kanji and build the set of known radicals (canonical + variants).
kanji_list = Repo.all(Kanji)

known_radicals =
  KanjiRadicals.all()
  |> Enum.flat_map(fn r -> [r.character | r.variants] end)
  |> MapSet.new()

# 1. Kanji with empty/missing radicals.
empty_radicals =
  Enum.filter(kanji_list, fn k ->
    is_nil(k.radicals) or k.radicals == []
  end)

# 2. Unknown radicals used in the DB.
{unknown_radicals, _samples} =
  Enum.reduce(kanji_list, {MapSet.new(), %{}}, fn k, {unknown_acc, sample_acc} ->
    radicals = k.radicals || []

    Enum.reduce(radicals, {unknown_acc, sample_acc}, fn r, {u_acc, s_acc} ->
      if MapSet.member?(known_radicals, r) do
        {u_acc, s_acc}
      else
        updated_samples = Map.update(s_acc, r, [k.character], &[k.character | &1])
        {MapSet.put(u_acc, r), updated_samples}
      end
    end)
  end)

# 3. Check KanjiRadicalFixes mapping against the DB.
fix_mismatches =
  Enum.filter(KanjiRadicalFixes.fixes(), fn {char, expected_radicals} ->
    case Enum.find(kanji_list, &(&1.character == char)) do
      nil -> true
      kanji -> Enum.sort(kanji.radicals || []) != Enum.sort(expected_radicals)
    end
  end)

# 4. Radical usage coverage from the DB against the hardcoded list.
used_radicals =
  kanji_list
  |> Enum.flat_map(&(&1.radicals || []))
  |> MapSet.new()

unused_radicals = MapSet.difference(known_radicals, used_radicals)

# Report.
IO.puts("=" |> String.duplicate(60))
IO.puts("Radical consistency check")
IO.puts("=" |> String.duplicate(60))
IO.puts("Total kanji in DB: #{length(kanji_list)}")
IO.puts("Known radicals (canonical + variants): #{MapSet.size(known_radicals)}")
IO.puts("Distinct radicals used in DB: #{MapSet.size(used_radicals)}")
IO.puts("")

IO.puts("Kanji with empty/missing radicals: #{length(empty_radicals)}")
if empty_radicals != [] do
  sample = empty_radicals |> Enum.take(20) |> Enum.map(& &1.character) |> Enum.join(", ")
  IO.puts("  Sample: #{sample}")
end

IO.puts("")
IO.puts("Unknown radicals used in DB: #{MapSet.size(unknown_radicals)}")
if MapSet.size(unknown_radicals) > 0 do
  unknown_radicals
  |> MapSet.to_list()
  |> Enum.each(fn radical ->
    sample =
      kanji_list
      |> Enum.filter(&(radical in (&1.radicals || [])))
      |> Enum.take(10)
      |> Enum.map(& &1.character)
      |> Enum.join(", ")

    IO.puts("  - #{radical} (used by: #{sample})")
  end)
end

IO.puts("")
IO.puts("KanjiRadicalFixes mismatches: #{length(fix_mismatches)}")
if fix_mismatches != [] do
  fix_mismatches
  |> Enum.take(20)
  |> Enum.each(fn {char, expected} ->
    db_radicals =
      case Enum.find(kanji_list, &(&1.character == char)) do
        nil -> "NOT IN DB"
        k -> inspect(k.radicals)
      end

    IO.puts("  #{char}: expected #{inspect(expected)}, DB has #{db_radicals}")
  end)
end

IO.puts("")
IO.puts("Known radicals never used in DB: #{MapSet.size(unused_radicals)}")
if MapSet.size(unused_radicals) > 0 do
  unused_radicals
  |> MapSet.to_list()
  |> Enum.sort()
  |> Enum.each(&IO.puts("  - #{&1}"))
end

IO.puts("")
IO.puts("Check complete.")
