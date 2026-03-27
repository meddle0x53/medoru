# Seeds for default grammar forms (conjugations)

alias Medoru.Repo
alias Medoru.Content.GrammarForm

# Verb forms
verb_forms = [
  %{
    name: "dictionary",
    display_name: "Dictionary form (る/う form)",
    word_type: "verb",
    suffix_pattern: "る/う",
    description: "The basic form of the verb as found in dictionaries. For ichidan verbs ends in る, for godan verbs ends in various u-row kana.",
    examples: ["食べる", "行く", "買う", "読む"]
  },
  %{
    name: "masu-form",
    display_name: "Polite form (ます form)",
    word_type: "verb",
    suffix_pattern: "ます",
    description: "Polite present/future tense. Used in formal situations.",
    examples: ["食べます", "行きます", "買います", "読みます"]
  },
  %{
    name: "te-form",
    display_name: "Te form (て form)",
    word_type: "verb",
    suffix_pattern: "て/で",
    description: "Used for connecting verbs, requests, and progressive/perfect tenses.",
    examples: ["食べて", "行って", "買って", "読んで"]
  },
  %{
    name: "ta-form",
    display_name: "Past form (た form)",
    word_type: "verb",
    suffix_pattern: "た/だ",
    description: "Past tense of verbs.",
    examples: ["食べた", "行った", "買った", "読んだ"]
  },
  %{
    name: "nai-form",
    display_name: "Negative form (ない form)",
    word_type: "verb",
    suffix_pattern: "ない",
    description: "Plain negative form. Used for present/future negative.",
    examples: ["食べない", "行かない", "買わない", "読まない"]
  },
  %{
    name: "nakatta-form",
    display_name: "Negative past form (なかった form)",
    word_type: "verb",
    suffix_pattern: "なかった",
    description: "Past negative form.",
    examples: ["食べなかった", "行かなかった", "買わなかった", "読まなかった"]
  },
  %{
    name: "conditional-ba",
    display_name: "Conditional form (えば form)",
    word_type: "verb",
    suffix_pattern: "えば",
    description: "Conditional form using えば. Means 'if/when'.",
    examples: ["食べれば", "行けば", "買えば", "読めば"]
  },
  %{
    name: "conditional-tara",
    display_name: "Conditional form (たら form)",
    word_type: "verb",
    suffix_pattern: "たら",
    description: "Conditional form using たら. More conversational than えば.",
    examples: ["食べたら", "行ったら", "買ったら", "読んだら"]
  },
  %{
    name: "potential",
    display_name: "Potential form (られる/れる form)",
    word_type: "verb",
    suffix_pattern: "られる/れる",
    description: "Expresses ability or possibility. Means 'can do'.",
    examples: ["食べられる", "行ける", "買える", "読める"]
  },
  %{
    name: "imperative",
    display_name: "Imperative form (ろ/れ form)",
    word_type: "verb",
    suffix_pattern: "ろ/れ",
    description: "Command form. Used for giving orders.",
    examples: ["食べろ", "行け", "買え", "読め"]
  },
  %{
    name: "volitional",
    display_name: "Volitional form (よう form)",
    word_type: "verb",
    suffix_pattern: "よう",
    description: "Expresses intention or suggestion. Means 'let's do'.",
    examples: ["食べよう", "行こう", "買おう", "読もう"]
  },
  %{
    name: "passive",
    display_name: "Passive form (られる/れる form)",
    word_type: "verb",
    suffix_pattern: "られる/れる",
    description: "Passive voice. Means 'is done by'.",
    examples: ["食べられる", "行かれる", "買われる", "読まれる"]
  },
  %{
    name: "causative",
    display_name: "Causative form (させる form)",
    word_type: "verb",
    suffix_pattern: "させる",
    description: "Means 'make/let someone do'.",
    examples: ["食べさせる", "行かせる", "買わせる", "読ませる"]
  }
]

# Adjective forms
adjective_forms = [
  %{
    name: "dictionary-i",
    display_name: "Dictionary form (い adjective)",
    word_type: "adjective",
    suffix_pattern: "い",
    description: "Basic form of i-adjectives.",
    examples: ["大きい", "小さい", "高い", "安い"]
  },
  %{
    name: "dictionary-na",
    display_name: "Dictionary form (な adjective)",
    word_type: "adjective",
    suffix_pattern: "",
    description: "Basic form of na-adjectives.",
    examples: ["きれい", "静か", "有名", "便利"]
  },
  %{
    name: "adverbial",
    display_name: "Adverbial form (く form)",
    word_type: "adjective",
    suffix_pattern: "く",
    description: "Adverb form of i-adjectives. Used to modify verbs.",
    examples: ["大きく", "小さく", "高く", "安く"]
  },
  %{
    name: "te-form-adj",
    display_name: "Te form (くて form)",
    word_type: "adjective",
    suffix_pattern: "くて",
    description: "Te form for connecting adjectives.",
    examples: ["大きくて", "小さくて", "高くて", "安くて"]
  },
  %{
    name: "past-i",
    display_name: "Past form (かった form)",
    word_type: "adjective",
    suffix_pattern: "かった",
    description: "Past tense of i-adjectives.",
    examples: ["大きかった", "小さかった", "高かった", "安かった"]
  },
  %{
    name: "negative-i",
    display_name: "Negative form (くない form)",
    word_type: "adjective",
    suffix_pattern: "くない",
    description: "Negative form of i-adjectives.",
    examples: ["大きくない", "小さくない", "高くない", "安くない"]
  },
  %{
    name: "negative-na",
    display_name: "Negative form (ではない form)",
    word_type: "adjective",
    suffix_pattern: "ではない",
    description: "Negative form of na-adjectives.",
    examples: ["きれいではない", "静かではない", "有名ではない"]
  }
]

# Insert all forms
all_forms = verb_forms ++ adjective_forms

Enum.each(all_forms, fn form_attrs ->
  case Repo.get_by(GrammarForm, name: form_attrs.name, word_type: form_attrs.word_type) do
    nil ->
      %GrammarForm{}
      |> GrammarForm.changeset(form_attrs)
      |> Repo.insert!()
      IO.puts("Created grammar form: #{form_attrs.display_name}")

    existing ->
      existing
      |> GrammarForm.changeset(form_attrs)
      |> Repo.update!()
      IO.puts("Updated grammar form: #{form_attrs.display_name}")
  end
end)

IO.puts("\nSeeded #{length(all_forms)} grammar forms.")
