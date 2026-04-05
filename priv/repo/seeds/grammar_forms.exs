# Seeder for grammar forms (conjugation patterns)
# Run with: mix run priv/repo/seeds/grammar_forms.exs

alias Medoru.Content

IO.puts("Seeding grammar forms...")

# Verb forms
verb_forms = [
  %{name: "dictionary", display_name: "辞書形 (る)", word_type: "verb", suffix_pattern: "る", description: "Dictionary form, plain form"},
  %{name: "masu-form", display_name: "ます", word_type: "verb", suffix_pattern: "ます", description: "Polite present/future"},
  %{name: "te-form", display_name: "て", word_type: "verb", suffix_pattern: "て", description: "Te-form for connecting verbs"},
  %{name: "ta-form", display_name: "た", word_type: "verb", suffix_pattern: "た", description: "Past plain form"},
  %{name: "nai-form", display_name: "ない", word_type: "verb", suffix_pattern: "ない", description: "Negative plain form"},
  %{name: "nakute-form", display_name: "なくて", word_type: "verb", suffix_pattern: "なくて", description: "Negative te-form"},
  %{name: "nakatta-form", display_name: "なかった", word_type: "verb", suffix_pattern: "なかった", description: "Negative past"},
  %{name: "potential", display_name: "られる", word_type: "verb", suffix_pattern: "られる", description: "Potential form (can do)"},
  %{name: "passive", display_name: "られる", word_type: "verb", suffix_pattern: "られる", description: "Passive form"},
  %{name: "causative", display_name: "させる", word_type: "verb", suffix_pattern: "させる", description: "Causative form (make/let do)"},
  %{name: "imperative", display_name: "ろ", word_type: "verb", suffix_pattern: "ろ", description: "Imperative/command form"},
  %{name: "volitional", display_name: "よう", word_type: "verb", suffix_pattern: "よう", description: "Volitional form (let's do)"},
  %{name: "conditional", display_name: "れば", word_type: "verb", suffix_pattern: "れば", description: "Conditional form (if)"},
]

# Adjective forms (い-adjectives)
ai_adjective_forms = [
  %{name: "dictionary", display_name: "い", word_type: "adjective", suffix_pattern: "い", description: "Dictionary form"},
  %{name: "ku-form", display_name: "く", word_type: "adjective", suffix_pattern: "く", description: "Ku-form for adverbs"},
  %{name: "kute-form", display_name: "くて", word_type: "adjective", suffix_pattern: "くて", description: "Te-form for connecting"},
  %{name: "katta-form", display_name: "かった", word_type: "adjective", suffix_pattern: "かった", description: "Past tense"},
  %{name: "kunai-form", display_name: "くない", word_type: "adjective", suffix_pattern: "くない", description: "Negative present"},
  %{name: "kunakatta-form", display_name: "くなかった", word_type: "adjective", suffix_pattern: "くなかった", description: "Negative past"},
]

# Adjective forms (な-adjectives)
na_adjective_forms = [
  %{name: "dictionary", display_name: "だ", word_type: "adjective", suffix_pattern: "だ", description: "Dictionary form with da"},
  %{name: "na-form", display_name: "な", word_type: "adjective", suffix_pattern: "な", description: "Attributive form (before noun)"},
  %{name: "de-form", display_name: "で", word_type: "adjective", suffix_pattern: "で", description: "Te-form for connecting"},
  %{name: "deshita-form", display_name: "でした", word_type: "adjective", suffix_pattern: "でした", description: "Polite past"},
  %{name: "dewa-nai-form", display_name: "ではない", word_type: "adjective", suffix_pattern: "ではない", description: "Negative plain"},
  %{name: "dewa-nakatta-form", display_name: "ではなかった", word_type: "adjective", suffix_pattern: "ではなかった", description: "Negative past"},
]

all_forms = verb_forms ++ ai_adjective_forms ++ na_adjective_forms

Enum.each(all_forms, fn form_attrs ->
  case Content.create_grammar_form(form_attrs) do
    {:ok, form} ->
      IO.puts("  ✓ Created: #{form.display_name} (#{form.word_type})")

    {:error, changeset} ->
      if changeset.errors[:name] && elem(changeset.errors[:name], 0) == "has already been taken" do
        IO.puts("  ⚠ Already exists: #{form_attrs.display_name}")
      else
        IO.puts("  ✗ Error creating #{form_attrs.display_name}: #{inspect(changeset.errors)}")
      end
  end
end)

IO.puts("\nGrammar forms seeding complete!")
IO.puts("Total forms: #{length(all_forms)}")
