# Seeder for word conjugations
# Creates conjugated forms for verbs and adjectives in the database
# Run with: mix run priv/repo/seeds/word_conjugations.exs

import Ecto.Query
alias Medoru.Repo
alias Medoru.Content.{Word, WordConjugation, GrammarForm}

defmodule ConjugationHelper do
  @moduledoc "Helper functions for word conjugation"

  # Conjugate verbs (ichidan - る verbs)
  def conjugate_verb(dictionary_form, form_name) when is_binary(dictionary_form) do
    if String.ends_with?(dictionary_form, "る") do
      stem = String.replace_suffix(dictionary_form, "る", "")
      
      case form_name do
        "dictionary" -> dictionary_form
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
    else
      # Skip non-ichidan verbs (godan verbs need different conjugation rules)
      case form_name do
        "dictionary" -> dictionary_form
        _ -> nil
      end
    end
  end

  # Conjugate い-adjectives
  def conjugate_i_adjective(dictionary_form, form_name) when is_binary(dictionary_form) do
    stem = String.replace_suffix(dictionary_form, "い", "")
    
    case form_name do
      "dictionary" -> dictionary_form
      "ku-form" -> stem <> "く"
      "kute-form" -> stem <> "くて"
      "katta-form" -> stem <> "かった"
      "kunai-form" -> stem <> "くない"
      "kunakatta-form" -> stem <> "くなかった"
      _ -> nil
    end
  end

  # Conjugate な-adjectives
  def conjugate_na_adjective(dictionary_form, form_name) when is_binary(dictionary_form) do
    base = dictionary_form
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

IO.puts("Seeding word conjugations...")

# Get all grammar forms
forms = Repo.all(GrammarForm) |> Enum.group_by(& &1.word_type)

# Process verbs
IO.puts("\nProcessing verbs...")

verbs = Repo.all(from w in Word, where: w.word_type == :verb)
verb_forms = Map.get(forms, "verb", [])

{verb_count, verb_errors} = 
  Enum.reduce(verbs, {0, 0}, fn word, {count, errors} ->
    Enum.reduce(verb_forms, {count, errors}, fn form, {c, e} ->
      conjugated = ConjugationHelper.conjugate_verb(word.text, form.name)
      
      if conjugated do
        attrs = %{
          word_id: word.id,
          grammar_form_id: form.id,
          conjugated_form: conjugated,
          is_regular: true
        }
        
        case Repo.insert(WordConjugation.changeset(%WordConjugation{}, attrs),
               on_conflict: {:replace, [:conjugated_form, :updated_at]},
               conflict_target: [:word_id, :grammar_form_id]) do
          {:ok, _} -> {c + 1, e}
          {:error, _} -> {c, e + 1}
        end
      else
        {c, e}
      end
    end)
  end)

IO.puts("  Created #{verb_count} verb conjugations (#{verb_errors} errors)")

# Process い-adjectives (heuristic: ends with い)
IO.puts("\nProcessing い-adjectives...")

i_adjectives = Repo.all(from w in Word, 
  where: w.word_type == :adjective and like(w.text, "%い"))
adj_forms = Map.get(forms, "adjective", [])
i_adj_forms = Enum.filter(adj_forms, &String.starts_with?(&1.name, "k"))

{i_adj_count, i_adj_errors} = 
  Enum.reduce(i_adjectives, {0, 0}, fn word, {count, errors} ->
    Enum.reduce(i_adj_forms, {count, errors}, fn form, {c, e} ->
      conjugated = ConjugationHelper.conjugate_i_adjective(word.text, form.name)
      
      if conjugated do
        attrs = %{
          word_id: word.id,
          grammar_form_id: form.id,
          conjugated_form: conjugated,
          is_regular: true
        }
        
        case Repo.insert(WordConjugation.changeset(%WordConjugation{}, attrs),
               on_conflict: {:replace, [:conjugated_form, :updated_at]},
               conflict_target: [:word_id, :grammar_form_id]) do
          {:ok, _} -> {c + 1, e}
          {:error, _} -> {c, e + 1}
        end
      else
        {c, e}
      end
    end)
  end)

IO.puts("  Created #{i_adj_count} い-adjective conjugations (#{i_adj_errors} errors)")

# Process な-adjectives (heuristic: ends with だ or な)
IO.puts("\nProcessing な-adjectives...")

na_adjectives = Repo.all(from w in Word, 
  where: w.word_type == :adjective and (like(w.text, "%だ") or like(w.text, "%な")))
na_adj_forms = Enum.filter(adj_forms, &String.starts_with?(&1.name, "d") or &1.name in ["dictionary", "na-form"])

{na_adj_count, na_adj_errors} = 
  Enum.reduce(na_adjectives, {0, 0}, fn word, {count, errors} ->
    Enum.reduce(na_adj_forms, {count, errors}, fn form, {c, e} ->
      conjugated = ConjugationHelper.conjugate_na_adjective(word.text, form.name)
      
      if conjugated do
        attrs = %{
          word_id: word.id,
          grammar_form_id: form.id,
          conjugated_form: conjugated,
          is_regular: true
        }
        
        case Repo.insert(WordConjugation.changeset(%WordConjugation{}, attrs),
               on_conflict: {:replace, [:conjugated_form, :updated_at]},
               conflict_target: [:word_id, :grammar_form_id]) do
          {:ok, _} -> {c + 1, e}
          {:error, _} -> {c, e + 1}
        end
      else
        {c, e}
      end
    end)
  end)

IO.puts("  Created #{na_adj_count} な-adjective conjugations (#{na_adj_errors} errors)")

IO.puts("\nWord conjugations seeding complete!")
IO.puts("Total: #{verb_count + i_adj_count + na_adj_count} conjugations created")
