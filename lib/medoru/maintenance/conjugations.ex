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
  Seeds or updates grammar forms required for conjugation generation.

  This ensures the grammar_forms table has all the forms expected by
  `generate_all/1` and `generate_for_type/1`.

  ## Options
    * `:clear_first` - If true, deletes all existing grammar forms first (default: false)

  ## Usage
      Medoru.Maintenance.Conjugations.seed_grammar_forms()
      Medoru.Maintenance.Conjugations.seed_grammar_forms(clear_first: true)
  """
  def seed_grammar_forms(opts \\ []) do
    if opts[:clear_first] do
      IO.puts("Clearing existing grammar forms...")
      {count, _} = Repo.delete_all(GrammarForm)
      IO.puts("  Deleted #{count} forms")
    end

    IO.puts("Seeding grammar forms...")

    # Verb forms (13 forms)
    verb_forms = [
      %{
        name: "dictionary",
        display_name: "る",
        word_type: "verb",
        suffix_pattern: "る",
        description: "Dictionary form, plain form"
      },
      %{
        name: "masu-form",
        display_name: "ます",
        word_type: "verb",
        suffix_pattern: "ます",
        description: "Polite present/future"
      },
      %{
        name: "te-form",
        display_name: "て",
        word_type: "verb",
        suffix_pattern: "て",
        description: "Te-form for connecting verbs"
      },
      %{
        name: "ta-form",
        display_name: "た",
        word_type: "verb",
        suffix_pattern: "た",
        description: "Past plain form"
      },
      %{
        name: "nai-form",
        display_name: "ない",
        word_type: "verb",
        suffix_pattern: "ない",
        description: "Negative plain form"
      },
      %{
        name: "nakute-form",
        display_name: "なくて",
        word_type: "verb",
        suffix_pattern: "なくて",
        description: "Negative te-form"
      },
      %{
        name: "nakatta-form",
        display_name: "なかった",
        word_type: "verb",
        suffix_pattern: "なかった",
        description: "Negative past"
      },
      %{
        name: "potential",
        display_name: "られる",
        word_type: "verb",
        suffix_pattern: "られる",
        description: "Potential form (can do)"
      },
      %{
        name: "passive",
        display_name: "られる",
        word_type: "verb",
        suffix_pattern: "られる",
        description: "Passive form"
      },
      %{
        name: "causative",
        display_name: "させる",
        word_type: "verb",
        suffix_pattern: "させる",
        description: "Causative form (make/let do)"
      },
      %{
        name: "imperative",
        display_name: "ろ",
        word_type: "verb",
        suffix_pattern: "ろ",
        description: "Imperative/command form"
      },
      %{
        name: "volitional",
        display_name: "よう",
        word_type: "verb",
        suffix_pattern: "よう",
        description: "Volitional form (let's do)"
      },
      %{
        name: "conditional",
        display_name: "れば",
        word_type: "verb",
        suffix_pattern: "れば",
        description: "Conditional form (if)"
      }
    ]

    # い-adjective forms (6 forms)
    i_adjective_forms = [
      %{
        name: "dictionary",
        display_name: "い",
        word_type: "adjective",
        suffix_pattern: "い",
        description: "Dictionary form"
      },
      %{
        name: "ku-form",
        display_name: "く",
        word_type: "adjective",
        suffix_pattern: "く",
        description: "Ku-form for adverbs (adverbial)"
      },
      %{
        name: "kute-form",
        display_name: "くて",
        word_type: "adjective",
        suffix_pattern: "くて",
        description: "Te-form for connecting (kute-form)"
      },
      %{
        name: "katta-form",
        display_name: "かった",
        word_type: "adjective",
        suffix_pattern: "かった",
        description: "Past tense (katta-form)"
      },
      %{
        name: "kunai-form",
        display_name: "くない",
        word_type: "adjective",
        suffix_pattern: "くない",
        description: "Negative present (kunai-form)"
      },
      %{
        name: "kunakatta-form",
        display_name: "くなかった",
        word_type: "adjective",
        suffix_pattern: "くなかった",
        description: "Negative past (kunakatta-form)"
      }
    ]

    # な-adjective forms (6 forms)
    na_adjective_forms = [
      %{
        name: "dictionary-na",
        display_name: "だ",
        word_type: "adjective",
        suffix_pattern: "だ",
        description: "Dictionary form with da"
      },
      %{
        name: "na-form",
        display_name: "な",
        word_type: "adjective",
        suffix_pattern: "な",
        description: "Attributive form (before noun)"
      },
      %{
        name: "adverbial",
        display_name: "で",
        word_type: "adjective",
        suffix_pattern: "で",
        description: "Te-form/de-form for connecting"
      },
      %{
        name: "past-i",
        display_name: "だった",
        word_type: "adjective",
        suffix_pattern: "だった",
        description: "Past form (deshita/datta)"
      },
      %{
        name: "negative-na",
        display_name: "ではない",
        word_type: "adjective",
        suffix_pattern: "ではない",
        description: "Negative plain (dewa nai)"
      }
    ]

    all_forms = verb_forms ++ i_adjective_forms ++ na_adjective_forms

    results =
      Enum.map(all_forms, fn form_attrs ->
        case Repo.get_by(GrammarForm, name: form_attrs.name, word_type: form_attrs.word_type) do
          nil ->
            %GrammarForm{}
            |> GrammarForm.changeset(form_attrs)
            |> Repo.insert()
            |> case do
              {:ok, form} ->
                IO.puts("  ✓ Created: #{form.name} (#{form.word_type})")
                {:created, form}

              {:error, changeset} ->
                IO.puts("  ✗ Error creating #{form_attrs.name}: #{inspect(changeset.errors)}")
                {:error, changeset}
            end

          existing ->
            # Update if needed
            existing
            |> GrammarForm.changeset(form_attrs)
            |> Repo.update()
            |> case do
              {:ok, form} ->
                IO.puts("  ✓ Updated: #{form.name} (#{form.word_type})")
                {:updated, form}

              {:error, changeset} ->
                IO.puts("  ✗ Error updating #{form_attrs.name}: #{inspect(changeset.errors)}")
                {:error, changeset}
            end
        end
      end)

    created = Enum.count(results, fn {status, _} -> status == :created end)
    updated = Enum.count(results, fn {status, _} -> status == :updated end)
    errors = Enum.count(results, fn {status, _} -> status == :error end)

    IO.puts("\n✅ Grammar forms seeding complete!")

    IO.puts(
      "Total: #{length(all_forms)} forms (#{created} created, #{updated} updated, #{errors} errors)"
    )

    %{
      total: length(all_forms),
      created: created,
      updated: updated,
      errors: errors
    }
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

    # Ensure important special verbs exist (hiragana forms of common verbs)
    ensure_special_verbs()

    verbs = Repo.all(from w in Word, where: w.word_type == :verb)
    verb_forms = Map.get(forms, "verb", [])

    Enum.reduce(verbs, {0, 0}, fn word, {count, errors} ->
      # Use reading to determine verb type for verbs ending in る
      verb_type = classify_verb(word.text, word.reading)

      Enum.reduce(verb_forms, {count, errors}, fn form, {c, e} ->
        case conjugate_verb_full(word.text, verb_type, form.name) do
          nil ->
            {c, e}

          # Handle multiple forms (e.g., kanji + kana for irregular verbs)
          # Save kanji as conjugated_form and kana as reading
          [kanji_form, kana_form] ->
            # Generate alternative forms using the kanji form
            alt_forms = generate_alternative_forms(kanji_form, form.name)

            attrs = %{
              word_id: word.id,
              grammar_form_id: form.id,
              conjugated_form: kanji_form,
              reading: kana_form,
              alternative_forms: alt_forms,
              is_regular: verb_type in [:ichidan, :godan]
            }

            case insert_conjugation(attrs) do
              {:ok, _} -> {c + 1, e}
              {:error, _} -> {c, e + 1}
            end

          # Single form
          conjugated ->
            # Generate alternative forms for certain grammar forms
            alt_forms = generate_alternative_forms(conjugated, form.name)

            attrs = %{
              word_id: word.id,
              grammar_form_id: form.id,
              conjugated_form: conjugated,
              alternative_forms: alt_forms,
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

    # Map database form names to conjugation functions
    # Supports both naming conventions:
    # - New: dictionary-i, adverbial, te-form-adj, past-i, negative-i
    # - Legacy: dictionary, ku-form, kute-form, katta-form, kunai-form
    i_adj_forms =
      adj_forms
      |> Enum.filter(
        &(&1.name in [
            "dictionary-i",
            "adverbial",
            "te-form-adj",
            "past-i",
            "negative-i",
            "dictionary",
            "ku-form",
            "kute-form",
            "katta-form",
            "kunai-form"
          ])
      )

    Enum.reduce(i_adjectives, {0, 0}, fn word, {count, errors} ->
      Enum.reduce(i_adj_forms, {count, errors}, fn form, {c, e} ->
        case conjugate_i_adjective_full(word.text, word.reading, form.name) do
          nil ->
            {c, e}

          {conjugated, reading} ->
            attrs = %{
              word_id: word.id,
              grammar_form_id: form.id,
              conjugated_form: conjugated,
              reading: reading,
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

    # Na-adjectives are all adjectives that don't end in い
    # (includes words ending in だ, な, and loanwords like ハンサム)
    na_adjectives =
      Repo.all(
        from w in Word,
          where: w.word_type == :adjective and not like(w.text, "%い")
      )

    adj_forms = Map.get(forms, "adjective", [])

    # Map database form names to conjugation functions
    # Database has: dictionary-na, na-form, adverbial, te-form-adj, te-form-na, past-i, negative-na
    na_adj_forms =
      adj_forms
      |> Enum.filter(
        &(&1.name in [
            "dictionary-na",
            "na-form",
            "adverbial",
            "te-form-adj",
            "te-form-na",
            "past-i",
            "negative-na"
          ])
      )

    Enum.reduce(na_adjectives, {0, 0}, fn word, {count, errors} ->
      Enum.reduce(na_adj_forms, {count, errors}, fn form, {c, e} ->
        case conjugate_na_adjective_full(word.text, word.reading, form.name) do
          nil ->
            {c, e}

          {conjugated, reading} ->
            attrs = %{
              word_id: word.id,
              grammar_form_id: form.id,
              conjugated_form: conjugated,
              reading: reading,
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
      on_conflict: {:replace, [:conjugated_form, :reading, :alternative_forms, :updated_at]},
      conflict_target: [:word_id, :grammar_form_id]
    )
  end

  # Generates alternative forms for certain grammar forms
  # These are contracted forms used when combining with certain suffixes
  defp generate_alternative_forms(conjugated, form_name) do
    case form_name do
      # For nai-form, the alternative is without い (for combining with くて, ければ, etc.)
      # e.g., 来ない → 来な (used in 来なくて, 来なければ)
      "nai-form" ->
        if String.ends_with?(conjugated, "ない") do
          [String.replace_suffix(conjugated, "ない", "な")]
        else
          []
        end

      # For masu-form, two alternatives:
      # 1. Without す: 行きま (used in 行きましょうか, 行きません)
      # 2. Bare i-stem: 行き (used in 行きたい, 行きたがる, etc.)
      "masu-form" ->
        if String.ends_with?(conjugated, "ます") do
          without_masu = String.replace_suffix(conjugated, "ます", "")
          [without_masu <> "ま", without_masu]
        else
          []
        end

      _ ->
        []
    end
  end

  # COMPREHENSIVE list of godan verbs ending in -iru or -eru
  # These verbs look like ichidan but conjugate as godan.
  #
  # Sources:
  # - https://www.sljfaq.org/afaq/which-godan.html (authoritative list)
  # - https://community.wanikani.com/t/list-of-godan-iru-eru-exception-verbs/55127
  # - https://kodamadict.kodamalabs.dev/verbs/2024/04/01/how-many-ichidan-verbs-are-there.html
  #
  # IMPORTANT: For each verb, we list BOTH kanji and hiragana forms because
  # verbs may appear in the database in either form. The classify_verb function
  # checks these sets before applying the ichidan rule.
  #
  @godan_iru_exceptions MapSet.new([
                          # === Core/common verbs (JLPT N5-N4) ===
                          # to enter
                          "入る",
                          "はいる",
                          # to run
                          "走る",
                          "はしる",
                          # to know
                          "知る",
                          "しる",
                          # to cut
                          "切る",
                          "きる",
                          # to need (いる - hiragana removed to allow ichidan いる/居る "to be")
                          "要る",
                          # to return
                          "帰る",
                          "かえる",
                          # to limit
                          "限る",
                          "かぎる",
                          # to scatter
                          "散る",
                          "ちる",

                          # === JLPT N3-N2 level ===
                          # to be in a hurry
                          "焦る",
                          "あせる",
                          # to feel hot/flush
                          "火照る",
                          "ほてる",
                          # to darken/be clouded
                          "陰る",
                          "かげる",
                          # to be overturned
                          "覆る",
                          "くつがえる",
                          # to slip
                          "滑る",
                          "すべる",
                          # to be slippery
                          "滑る",
                          "ぬめる",
                          # to chat/talk
                          "喋る",
                          "しゃべる",
                          # to grow thick
                          "茂る",
                          "しげる",
                          # to grow thick (alt kanji)
                          "繁る",
                          "しげる",
                          # to get damp
                          "湿気る",
                          "しける",
                          # to rage/act violently
                          "猛る",
                          "たける",
                          # to be resurrected
                          "蘇る",
                          "よみがえる",
                          # to mingle
                          "混じる",
                          "まじる",
                          # to rebuke
                          "詰る",
                          "なじる",
                          # to flatter
                          "阿る",
                          "おもねる",
                          # to compete
                          "競る",
                          "せる",
                          # to shine
                          "照る",
                          "てる",
                          # to knead/temper (not 寝る sleep - ichidan)
                          "煉る",
                          "ねる",
                          # to twist/distort
                          "攀じる",
                          "よじる",
                          # to tear to pieces
                          "千切る",
                          "ちぎる",
                          # to pick/dig out (also うがる)
                          "穿る",
                          "ほじる",
                          # to gush/spurt
                          "迸る",
                          "ほとばしる",
                          # to fiddle with (also もてあそる)
                          "弄る",
                          "いじる",
                          # to squeak/creak
                          "軋る",
                          "きしる",
                          # to pry (also えぐる)
                          "抉る",
                          "こじる",
                          # to overflow
                          "漲る",
                          "みなぎる",
                          # to slander (also しにものぐる)
                          "謗る",
                          "そしる",
                          # alt kanji for slander
                          "謗る",
                          "譏る",
                          "誹る",
                          # to seethe/boil
                          "滾る",
                          "たぎる",
                          # alt kanji
                          "激る",
                          "たぎる",
                          # to be frightened
                          "魂消る",
                          "たまげる",
                          # to be absorbed in
                          "耽る",
                          "ふける",
                          # to twist/wring
                          "捻る",
                          "ひねる",
                          # to twist
                          "捻じる",
                          "ねじる",
                          # to pinch
                          "抓る",
                          "つねる",
                          # to undulate
                          "畝る",
                          "うねる",
                          # to grasp
                          "握る",
                          "にぎる",

                          # === Less common but important ===
                          # to be greasy
                          "脂ぎる",
                          "あぶらぎる",
                          # alt kanji
                          "油ぎる",
                          "あぶらぎる",
                          # to pluck/pick
                          "毟る",
                          "むしる",
                          # alt kanji
                          "挘る",
                          "むしる",
                          # to abuse verbally
                          "罵る",
                          "ののしる",
                          # to fall/sink
                          "陥る",
                          "おちいる",
                          # to feel depressed
                          "滅入る",
                          "めいる",
                          # to jeer at
                          "やじる",
                          # to grumble
                          "愚痴る",
                          "ぐちる",

                          # === Kana-only exceptions ===
                          # to be surprised/nervous
                          "びびる",
                          # to mess up
                          "どじる",
                          # to torment/roast (not 見る)
                          "いびる",
                          # to pester/extort
                          "せびる",
                          # to be crooked/wriggle
                          "くねる"
                        ])

  @godan_eru_exceptions MapSet.new([
                          # === Core/common (JLPT N5-N4) ===
                          # to kick
                          "蹴る",
                          "ける",
                          # to hide/lie in ambush
                          "伏せる",
                          "ふせる",
                          # to decrease
                          "減る",
                          "へる",
                          # to go/come (humble)
                          "参る",
                          "まいる",

                          # === JLPT N3-N2 level ===
                          # to roast/boil down
                          "煎る",
                          "いる",
                          # to stir-fry
                          "炒る",
                          "いる",
                          # to boil down
                          "熬る",
                          "いる",
                          # to soar
                          "翔ける",
                          "かける",
                          # to gnaw
                          "噛る",
                          "かじる",
                          # to knead (alt kanji)
                          "練る",
                          "ねる",
                          # to be slippery
                          "滑る",
                          "ぬめる",
                          # to flatter
                          "阿る",
                          "阿ねる",
                          "おもねる",
                          # to compete
                          "競る",
                          "糶る",
                          "せる",
                          # to pick/play with
                          "挵る",
                          "せせる",
                          # to pinch
                          "詰める",
                          "つめる",

                          # === Less common ===
                          # to fall forward
                          "のめる",
                          # to be crooked
                          "くねる"
                        ])

  # Classify verb type
  # 
  # Logic:
  # 1. Irregular verbs (くる/来る, する/為る) are checked first
  # 2. Godan exceptions (verbs ending in -iru/-eru that look like ichidan but are godan)
  # 3. For verbs ending in る: check the READING to determine type
  #    - If reading ends in -iru/-eru: ichidan (unless in exceptions)
  #    - If reading ends in -aru/-oru/-uru: godan
  # 4. Everything else -> godan
  #
  # The reading is crucial because kanji don't indicate pronunciation.
  # For example:
  #   撮る (とる) -> godan (toru ends in -oru sound)
  #   見る (みる) -> ichidan (miru ends in -iru sound)
  defp classify_verb(text, reading) do
    cond do
      # Irregular verbs
      text in ["くる", "来る"] ->
        :kuru

      text in ["する", "為る"] ->
        :suru

      # Godan exceptions: verbs ending in -iru/-eru that are NOT ichidan
      text in @godan_iru_exceptions ->
        :godan

      text in @godan_eru_exceptions ->
        :godan

      # For る-ending verbs, check the reading
      String.ends_with?(text, "る") ->
        if reading && ichidan_reading?(reading) do
          :ichidan
        else
          :godan
        end

      # Godan verbs: everything else (verbs not ending in る)
      true ->
        :godan
    end
  end

  # Check if the reading indicates an ichidan verb
  # Ichidan verbs have readings ending in -iru or -eru (い/え段 + る)
  defp ichidan_reading?(reading) do
    # Get the character before る in the reading
    stem = String.slice(reading, 0, max(0, String.length(reading) - 1))
    last_char = String.last(stem)

    # Check if it's in い or え column
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

  # Note: We removed ichidan_pattern?/1 because it only worked for hiragana verbs.
  # The new logic in classify_verb/1 is simpler and more accurate:
  # - If it ends in る and is NOT in the godan exceptions list -> ichidan
  # - Otherwise -> godan

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
    # Check for special case verbs first (hardcoded conjugations)
    case special_verb_conjugation(text, form_name) do
      nil ->
        # Fall through to regular conjugation logic
        case verb_type do
          :ichidan -> conjugate_ichidan(text, form_name)
          :godan -> conjugate_godan(text, form_name)
          :kuru -> conjugate_kuru(form_name)
          :suru -> conjugate_suru(form_name)
        end

      conjugated ->
        conjugated
    end
  end

  # Special case verbs with hardcoded conjugations
  # These override the normal conjugation logic
  defp special_verb_conjugation("いる", form_name) do
    # いる (居る) - to be (animate) - ichidan conjugations
    case form_name do
      "dictionary" -> "いる"
      "masu-form" -> "います"
      "te-form" -> "いて"
      "ta-form" -> "いた"
      "nai-form" -> "いない"
      "nakute-form" -> "いなくて"
      "nakatta-form" -> "いなかった"
      "potential" -> "いられる"
      "passive" -> "いられる"
      "causative" -> "いらせる"
      "imperative" -> "いろ"
      "volitional" -> "いよう"
      "conditional" -> "いれば"
      _ -> nil
    end
  end

  defp special_verb_conjugation(_text, _form_name), do: nil

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
        # Get stem without the final character (we'll add appropriate sound)
        base = String.slice(text, 0, String.length(text) - 1)

        cond do
          # う, つ, る → って
          last in ["う", "つ", "る"] -> base <> "って"
          # ぶ, む, ぬ → んで
          last in ["ぶ", "む", "ぬ"] -> base <> "んで"
          # く → いて (special: 行く→行って handled below)
          last == "く" -> base <> "いて"
          # ぐ → いで
          last == "ぐ" -> base <> "いで"
          # す → して
          last == "す" -> base <> "して"
          true -> base <> "て"
        end
        |> handle_iku_te_form(text)

      "ta-form" ->
        # Similar to te-form but with た/だ
        last = String.last(text)
        # Get stem without the final character
        base = String.slice(text, 0, String.length(text) - 1)

        result =
          cond do
            last in ["う", "つ", "る"] -> base <> "った"
            last in ["ぶ", "む", "ぬ"] -> base <> "んだ"
            last == "く" -> base <> "いた"
            last == "ぐ" -> base <> "いだ"
            last == "す" -> base <> "した"
            true -> base <> "た"
          end

        # Special case: 行く→行った (iku→itta), not 行いた
        handle_iku_ta_form(result, text)

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

  # Special case: 行く→行った (iku→itta), not 行いた
  defp handle_iku_ta_form(result, original) do
    if original in ["いく", "行く"] do
      String.replace_suffix(original, "く", "いた") |> String.replace("いた", "った")
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
  # Maps database form names to conjugations:
  #   dictionary-i -> 大きい (dictionary form)
  #   adverbial -> 大きく (ku-form, also used for negative base)
  #   te-form-adj -> 大きくて (kute-form)
  #   past-i -> 大きかった (katta-form)
  #   negative-i -> 大きくない (kunai-form)
  #
  # Returns: {conjugated_form, reading} or nil
  defp conjugate_i_adjective_full(text, reading, form_name) do
    stem = String.replace_suffix(text, "い", "")
    # Also get stem from reading (remove trailing い)
    base_reading =
      if reading && reading != "" do
        String.replace_suffix(reading, "い", "")
      else
        stem
      end

    case form_name do
      # New naming convention
      "dictionary-i" ->
        {text, reading}

      "adverbial" ->
        {stem <> "く", base_reading <> "く"}

      "te-form-adj" ->
        {stem <> "くて", base_reading <> "くて"}

      "past-i" ->
        {stem <> "かった", base_reading <> "かった"}

      "negative-i" ->
        {stem <> "くない", base_reading <> "くない"}

      # Legacy naming convention
      "dictionary" ->
        {text, reading}

      "ku-form" ->
        {stem <> "く", base_reading <> "く"}

      "kute-form" ->
        {stem <> "くて", base_reading <> "くて"}

      "katta-form" ->
        {stem <> "かった", base_reading <> "かった"}

      "kunai-form" ->
        {stem <> "くない", base_reading <> "くない"}

      "kunakatta-form" ->
        {stem <> "くなかった", base_reading <> "くなかった"}

      _ ->
        nil
    end
  end

  # な-adjective conjugation with full forms
  # Maps database form names to conjugations:
  #   dictionary-na -> 静かだ / ハンサムだ (dictionary form)
  #   na-form -> 静かな / ハンサムな (attributive form)
  #   adverbial -> 静かで / ハンサムで (de-form, also used for te-form)
  #   te-form-adj -> 静かで / ハンサムで (te-form - kept for compatibility)
  #   te-form-na -> 静かで / ハンサムで (te-form for な-adjectives)
  #   past-i -> 静かだった / ハンサムだった (past form)
  #   negative-na -> 静かではない / ハンサムではない (negative form)
  #
  # Returns: {conjugated_form, reading} or nil
  defp conjugate_na_adjective_full(text, reading, form_name) do
    # Remove trailing だ or な if present (for words like 静かだ, 元気な)
    # For loanwords like ハンサム, use as-is
    base =
      cond do
        String.ends_with?(text, "だ") -> String.replace_suffix(text, "だ", "")
        String.ends_with?(text, "な") -> String.replace_suffix(text, "な", "")
        true -> text
      end

    # Get base reading (remove trailing だ/な if present)
    base_reading =
      cond do
        reading && String.ends_with?(reading, "だ") -> String.replace_suffix(reading, "だ", "")
        reading && String.ends_with?(reading, "な") -> String.replace_suffix(reading, "な", "")
        reading && reading != "" -> reading
        true -> base
      end

    case form_name do
      "dictionary-na" ->
        {base <> "だ", base_reading <> "だ"}

      "na-form" ->
        {base <> "な", base_reading <> "な"}

      "adverbial" ->
        {base <> "で", base_reading <> "で"}

      "te-form-adj" ->
        {base <> "で", base_reading <> "で"}

      "te-form-na" ->
        {base <> "で", base_reading <> "で"}

      "past-i" ->
        {base <> "だった", base_reading <> "だった"}

      "negative-na" ->
        {base <> "ではない", base_reading <> "ではない"}

      _ ->
        nil
    end
  end

  # Ensures special verbs that are critical for the application exist in the database.
  # These are primarily hiragana forms of common verbs that might not be in the seed data.
  defp ensure_special_verbs do
    special_verbs = [
      %{
        text: "いる",
        meaning: "to be (of animate objects)",
        reading: "いる",
        word_type: :verb,
        difficulty: 3,
        usage_frequency: 100,
        example_sentence: "猫がいます",
        example_reading: "ねこがいます",
        example_meaning: "There is a cat",
        translations: %{
          "en" => %{"meaning" => "to be (animate)"},
          "bg" => %{"meaning" => "да бъда (за живи същества)"}
        }
      }
    ]

    Enum.each(special_verbs, fn verb_attrs ->
      # Check if verb already exists
      case Repo.get_by(Word, text: verb_attrs.text, word_type: :verb) do
        nil ->
          # Insert the verb
          %Word{}
          |> Word.changeset(Map.put(verb_attrs, :sort_score, 0))
          |> Repo.insert(on_conflict: :nothing)
          |> case do
            {:ok, word} ->
              IO.puts("  Added special verb: #{word.text}")

            {:error, changeset} ->
              IO.puts("  Warning: Failed to add #{verb_attrs.text}: #{inspect(changeset.errors)}")

            _ ->
              :ok
          end

        _existing ->
          # Verb already exists, no action needed
          :ok
      end
    end)
  end
end
