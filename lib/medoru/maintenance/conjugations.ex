defmodule Medoru.Maintenance.Conjugations do
  @moduledoc """
  Module for generating word conjugations in production with full readings.

  Handles:
  - Godan (五段) verbs with proper stem changes (e.g., 書く → 書かない)
  - Ichidan (一段) verbs (e.g., 食べる → 食べない)
  - Irregular verbs (くる/来る, する, 為る)
  - い-adjectives (e.g., 高い → 高くない)
  - な-adjectives (e.g., 静かだ → 静かではない)

  ## Usage in IEx (Remote Console)

      # Generate all conjugations:
      Medoru.Maintenance.Conjugations.generate_all()

      # Or generate for specific types:
      Medoru.Maintenance.Conjugations.generate_for_type(:verb)
      Medoru.Maintenance.Conjugations.generate_for_type(:adjective)

  ## Example Output

      食べる (taberu) → 食べない (tabenai), 食べます (tabemasu)
      書く (kaku) → 書かない (kakanai), 書きます (kakimasu)
      くる (kuru) → こない (konai), きます (kimasu)
  """

  import Ecto.Query
  alias Medoru.Repo
  alias Medoru.Content.{Word, WordConjugation, GrammarForm}

  @doc """
  Clears all existing word conjugations from the database.
  Use this before regenerating with updated logic.
  """
  def clear_all do
    IO.puts("Clearing all word conjugations...")
    {count, _} = Repo.delete_all(WordConjugation)
    IO.puts("  Deleted #{count} conjugations")
    :ok
  end

  @doc """
  Generates all conjugations for verbs and adjectives.
  Safe to run multiple times (upserts on conflict).

  ## Options
    * `:clear_first` - If true, deletes all existing conjugations first (default: false)
  """
  def generate_all(opts \\ []) do
    if opts[:clear_first] do
      clear_all()
    end

    IO.puts("Generating conjugations with full readings...")

    forms = Repo.all(GrammarForm) |> Enum.group_by(& &1.word_type)

    {v_count, v_errors} = generate_verbs(forms)
    {i_count, i_errors} = generate_i_adjectives(forms)
    {na_count, na_errors} = generate_na_adjectives(forms)

    total = v_count + i_count + na_count
    errors = v_errors + i_errors + na_errors

    IO.puts("\n✅ Conjugations generation complete!")
    IO.puts("Total: #{total} conjugations created (#{errors} errors)")

    %{
      total: total,
      errors: errors,
      verbs: v_count,
      i_adjectives: i_count,
      na_adjectives: na_count
    }
  end

  @doc """
  Generates conjugations for a specific word type (:verb or :adjective).
  """
  def generate_for_type(:verb) do
    IO.puts("Generating verb conjugations...")
    forms = Repo.all(GrammarForm) |> Enum.group_by(& &1.word_type)
    {count, errors} = generate_verbs(forms)
    IO.puts("✅ Created #{count} verb conjugations (#{errors} errors)")
    %{count: count, errors: errors}
  end

  def generate_for_type(:adjective) do
    IO.puts("Generating adjective conjugations...")
    forms = Repo.all(GrammarForm) |> Enum.group_by(& &1.word_type)
    {i_count, i_errors} = generate_i_adjectives(forms)
    {na_count, na_errors} = generate_na_adjectives(forms)
    total = i_count + na_count
    errors = i_errors + na_errors
    IO.puts("✅ Created #{total} adjective conjugations (#{errors} errors)")
    %{count: total, errors: errors, i_adjectives: i_count, na_adjectives: na_count}
  end

  # Internal: Generate verb conjugations
  defp generate_verbs(forms) do
    IO.puts("\nProcessing verbs...")

    verbs = Repo.all(from w in Word, where: w.word_type == :verb)
    verb_forms = Map.get(forms, "verb", [])

    Enum.reduce(verbs, {0, 0}, fn word, {count, errors} ->
      verb_type = classify_verb(word.text)

      Enum.reduce(verb_forms, {count, errors}, fn form, {c, e} ->
        case conjugate_verb_full(word.text, verb_type, form.name) do
          nil ->
            {c, e}

          # Handle multiple forms (e.g., kanji + kana for irregular verbs)
          # Save kanji as conjugated_form and kana as reading
          [kanji_form, kana_form] ->
            attrs = %{
              word_id: word.id,
              grammar_form_id: form.id,
              conjugated_form: kanji_form,
              reading: kana_form,
              is_regular: verb_type in [:ichidan, :godan]
            }

            case insert_conjugation(attrs) do
              {:ok, _} -> {c + 1, e}
              {:error, _} -> {c, e + 1}
            end

          # Single form
          conjugated ->
            attrs = %{
              word_id: word.id,
              grammar_form_id: form.id,
              conjugated_form: conjugated,
              is_regular: verb_type in [:ichidan, :godan]
            }

            case insert_conjugation(attrs) do
              {:ok, _} -> {c + 1, e}
              {:error, _} -> {c, e + 1}
            end
        end
      end)
    end)
    |> tap(fn {count, errors} ->
      IO.puts("  Created #{count} verb conjugations (#{errors} errors)")
    end)
  end

  # Internal: Generate い-adjective conjugations
  defp generate_i_adjectives(forms) do
    IO.puts("\nProcessing い-adjectives...")

    i_adjectives =
      Repo.all(from w in Word, where: w.word_type == :adjective and like(w.text, "%い"))

    adj_forms = Map.get(forms, "adjective", [])
    i_adj_forms = Enum.filter(adj_forms, &String.starts_with?(&1.name, "k"))

    Enum.reduce(i_adjectives, {0, 0}, fn word, {count, errors} ->
      Enum.reduce(i_adj_forms, {count, errors}, fn form, {c, e} ->
        case conjugate_i_adjective_full(word.text, form.name) do
          nil ->
            {c, e}

          conjugated ->
            attrs = %{
              word_id: word.id,
              grammar_form_id: form.id,
              conjugated_form: conjugated,
              is_regular: true
            }

            case insert_conjugation(attrs) do
              {:ok, _} -> {c + 1, e}
              {:error, _} -> {c, e + 1}
            end
        end
      end)
    end)
    |> tap(fn {count, errors} ->
      IO.puts("  Created #{count} い-adjective conjugations (#{errors} errors)")
    end)
  end

  # Internal: Generate な-adjective conjugations
  defp generate_na_adjectives(forms) do
    IO.puts("\nProcessing な-adjectives...")

    na_adjectives =
      Repo.all(
        from w in Word,
          where: w.word_type == :adjective and (like(w.text, "%だ") or like(w.text, "%な"))
      )

    adj_forms = Map.get(forms, "adjective", [])

    na_adj_forms =
      Enum.filter(adj_forms, &String.starts_with?(&1.name, "d"))
      |> Enum.concat(Enum.filter(adj_forms, &(&1.name in ["dictionary", "na-form"])))

    Enum.reduce(na_adjectives, {0, 0}, fn word, {count, errors} ->
      Enum.reduce(na_adj_forms, {count, errors}, fn form, {c, e} ->
        case conjugate_na_adjective_full(word.text, form.name) do
          nil ->
            {c, e}

          conjugated ->
            attrs = %{
              word_id: word.id,
              grammar_form_id: form.id,
              conjugated_form: conjugated,
              is_regular: true
            }

            case insert_conjugation(attrs) do
              {:ok, _} -> {c + 1, e}
              {:error, _} -> {c, e + 1}
            end
        end
      end)
    end)
    |> tap(fn {count, errors} ->
      IO.puts("  Created #{count} な-adjective conjugations (#{errors} errors)")
    end)
  end

  # Insert with upsert (safe to run multiple times)
  defp insert_conjugation(attrs) do
    %WordConjugation{}
    |> WordConjugation.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:conjugated_form, :updated_at]},
      conflict_target: [:word_id, :grammar_form_id]
    )
  end

  # Classify verb type
  defp classify_verb(text) do
    cond do
      # Irregular verbs
      text in ["くる", "来る"] -> :kuru
      text in ["する", "為る"] -> :suru
      # Ichidan verbs: end with る and have ichidan pattern
      String.ends_with?(text, "る") and ichidan_pattern?(text) -> :ichidan
      # Godan verbs: everything else
      true -> :godan
    end
  end

  # Check if verb follows ichidan (一段) pattern
  # Ends in iru/eru sounds (い段 or え段 + る)
  defp ichidan_pattern?(text) do
    stem = String.slice(text, 0..-2//1)
    last_char = String.last(stem)

    # Check if the character before る is in い or え column
    last_char in [
      # い column
      "い",
      "き",
      "ぎ",
      "し",
      "じ",
      "ち",
      "ぢ",
      "に",
      "ひ",
      "び",
      "ぴ",
      "み",
      "り",
      # え column
      "え",
      "け",
      "げ",
      "せ",
      "ぜ",
      "て",
      "で",
      "ね",
      "へ",
      "べ",
      "ぺ",
      "め",
      "れ"
    ]
  end

  # Get godan stem by changing the final character to appropriate column
  defp godan_stem(text, target_column) do
    last_char = String.last(text)

    mapping = %{
      # From う column to other columns
      "う" => %{"a" => "わ", "i" => "い", "e" => "え", "o" => "お"},
      "く" => %{"a" => "か", "i" => "き", "e" => "け", "o" => "こ"},
      "ぐ" => %{"a" => "が", "i" => "ぎ", "e" => "げ", "o" => "ご"},
      "す" => %{"a" => "さ", "i" => "し", "e" => "せ", "o" => "そ"},
      "つ" => %{"a" => "た", "i" => "ち", "e" => "て", "o" => "と"},
      "づ" => %{"a" => "だ", "i" => "ぢ", "e" => "で", "o" => "ど"},
      "ぬ" => %{"a" => "な", "i" => "に", "e" => "ね", "o" => "の"},
      "ふ" => %{"a" => "は", "i" => "ひ", "e" => "へ", "o" => "ほ"},
      "ぶ" => %{"a" => "ば", "i" => "び", "e" => "べ", "o" => "ぼ"},
      "ぷ" => %{"a" => "ぱ", "i" => "ぴ", "e" => "ぺ", "o" => "ぽ"},
      "む" => %{"a" => "ま", "i" => "み", "e" => "め", "o" => "も"},
      "る" => %{"a" => "ら", "i" => "り", "e" => "れ", "o" => "ろ"}
    }

    stem = String.slice(text, 0..-2//1)
    new_ending = get_in(mapping, [last_char, target_column]) || last_char
    stem <> new_ending
  end

  # Full verb conjugation with proper stem changes
  defp conjugate_verb_full(text, verb_type, form_name) do
    case verb_type do
      :ichidan -> conjugate_ichidan(text, form_name)
      :godan -> conjugate_godan(text, form_name)
      :kuru -> conjugate_kuru(form_name)
      :suru -> conjugate_suru(form_name)
    end
  end

  # Ichidan (一段) verb conjugation
  defp conjugate_ichidan(text, form_name) do
    stem = String.replace_suffix(text, "る", "")

    case form_name do
      "dictionary" -> text
      "masu-form" -> stem <> "ます"
      "te-form" -> stem <> "て"
      "ta-form" -> stem <> "た"
      "nai-form" -> stem <> "ない"
      "nakute-form" -> stem <> "なくて"
      "nakatta-form" -> stem <> "なかった"
      "potential" -> stem <> "られる"
      "passive" -> stem <> "られる"
      "causative" -> stem <> "させる"
      "imperative" -> stem <> "ろ"
      "volitional" -> stem <> "よう"
      "conditional" -> stem <> "れば"
      _ -> nil
    end
  end

  # Godan (五段) verb conjugation with stem changes
  defp conjugate_godan(text, form_name) do
    case form_name do
      "dictionary" ->
        text

      "masu-form" ->
        godan_stem(text, "i") <> "ます"

      "te-form" ->
        last = String.last(text)
        stem = godan_stem(text, "i")

        cond do
          # う, つ, る → って
          last in ["う", "つ", "る"] -> String.replace_suffix(stem, "i", "") <> "って"
          # ぶ, む, ぬ → んで
          last in ["ぶ", "む", "ぬ"] -> String.replace_suffix(stem, "i", "") <> "んで"
          # く → いて (special: 行く→行って handled below)
          last == "く" -> String.replace_suffix(stem, "i", "") <> "いて"
          # ぐ → いで
          last == "ぐ" -> String.replace_suffix(stem, "i", "") <> "いで"
          # す → して
          last == "す" -> String.replace_suffix(stem, "i", "") <> "して"
          true -> stem <> "て"
        end
        |> handle_iku_te_form(text)

      "ta-form" ->
        # Similar to te-form but with た/だ
        last = String.last(text)
        stem = godan_stem(text, "i")

        cond do
          last in ["う", "つ", "る"] -> String.replace_suffix(stem, "i", "") <> "った"
          last in ["ぶ", "む", "ぬ"] -> String.replace_suffix(stem, "i", "") <> "んだ"
          last == "く" -> String.replace_suffix(stem, "i", "") <> "いた"
          last == "ぐ" -> String.replace_suffix(stem, "i", "") <> "いだ"
          last == "す" -> String.replace_suffix(stem, "i", "") <> "した"
          true -> stem <> "た"
        end

      "nai-form" ->
        godan_stem(text, "a") <> "ない"

      "nakute-form" ->
        godan_stem(text, "a") <> "なくて"

      "nakatta-form" ->
        godan_stem(text, "a") <> "なかった"

      "potential" ->
        godan_stem(text, "e") <> "る"

      "passive" ->
        godan_stem(text, "a") <> "れる"

      "causative" ->
        godan_stem(text, "a") <> "せる"

      "imperative" ->
        godan_stem(text, "e")

      "volitional" ->
        godan_stem(text, "o") <> "う"

      "conditional" ->
        godan_stem(text, "e") <> "ば"

      _ ->
        nil
    end
  end

  # Special case: 行く→行って (iku→itte), not 行いて
  defp handle_iku_te_form(result, original) do
    if original in ["いく", "行く"] do
      String.replace_suffix(original, "く", "いて") |> String.replace("いて", "って")
    else
      result
    end
  end

  # Irregular verb: くる/来る
  # Returns list of forms: [kanji_form, kana_form] for common written forms
  defp conjugate_kuru(form_name) do
    case form_name do
      "dictionary" -> ["来る", "くる"]
      "masu-form" -> ["来ます", "きます"]
      "te-form" -> ["来て", "きて"]
      "ta-form" -> ["来た", "きた"]
      "nai-form" -> ["来ない", "こない"]
      "nakute-form" -> ["来なくて", "こなくて"]
      "nakatta-form" -> ["来なかった", "こなかった"]
      "potential" -> ["来られる", "こられる"]
      "passive" -> ["来られる", "こられる"]
      "causative" -> ["来させる", "こさせる"]
      "imperative" -> ["来い", "こい"]
      "volitional" -> ["来よう", "こよう"]
      "conditional" -> ["来れば", "くれば"]
      _ -> nil
    end
  end

  # Irregular verb: する/為る
  # Returns list of forms: [kanji_form, kana_form] where kanji usage is acceptable
  defp conjugate_suru(form_name) do
    case form_name do
      "dictionary" -> ["為る", "する"]
      "masu-form" -> ["為ます", "します"]
      "te-form" -> ["為て", "して"]
      "ta-form" -> ["為た", "した"]
      "nai-form" -> ["為ない", "しない"]
      "nakute-form" -> ["為なくて", "しなくて"]
      "nakatta-form" -> ["為なかった", "しなかった"]
      "potential" -> "できる"
      "passive" -> ["為れる", "される"]
      "causative" -> ["為せる", "させる"]
      "imperative" -> ["為ろ", "しろ"]
      "volitional" -> ["為よう", "しよう"]
      "conditional" -> ["為れば", "すれば"]
      _ -> nil
    end
  end

  # い-adjective conjugation with full forms
  defp conjugate_i_adjective_full(text, form_name) do
    stem = String.replace_suffix(text, "い", "")

    case form_name do
      "dictionary" -> text
      "ku-form" -> stem <> "く"
      "kute-form" -> stem <> "くて"
      "katta-form" -> stem <> "かった"
      "kunai-form" -> stem <> "くない"
      "kunakatta-form" -> stem <> "くなかった"
      _ -> nil
    end
  end

  # な-adjective conjugation with full forms
  defp conjugate_na_adjective_full(text, form_name) do
    base =
      text
      |> String.replace_suffix("だ", "")
      |> String.replace_suffix("な", "")

    case form_name do
      "dictionary" -> base <> "だ"
      "na-form" -> base <> "な"
      "de-form" -> base <> "で"
      "deshita-form" -> base <> "でした"
      "dewa-nai-form" -> base <> "ではない"
      "dewa-nakatta-form" -> base <> "ではなかった"
      _ -> nil
    end
  end
end
