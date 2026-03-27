# Seeds for default word classes (semantic categories)

alias Medoru.Repo
alias Medoru.Content.WordClass

word_classes = [
  %{
    name: "time",
    display_name: "Time expressions",
    description: "Words related to time, dates, and temporal concepts.",
    examples: ["今日", "明日", "朝", "夜", "今", "前", "後"]
  },
  %{
    name: "place",
    display_name: "Place expressions",
    description: "Words related to locations and places.",
    examples: ["ここ", "そこ", "あそこ", "家", "学校", "町"]
  },
  %{
    name: "person",
    display_name: "People expressions",
    description: "Words related to people and relationships.",
    examples: ["私", "あなた", "彼", "彼女", "友達", "先生"]
  },
  %{
    name: "object",
    display_name: "Object expressions",
    description: "Words related to physical objects and things.",
    examples: ["本", "机", "椅子", "電話", "車", "本"]
  }
]

Enum.each(word_classes, fn class_attrs ->
  case Repo.get_by(WordClass, name: class_attrs.name) do
    nil ->
      %WordClass{}
      |> WordClass.changeset(class_attrs)
      |> Repo.insert!()
      IO.puts("Created word class: #{class_attrs.display_name}")

    existing ->
      existing
      |> WordClass.changeset(class_attrs)
      |> Repo.update!()
      IO.puts("Updated word class: #{class_attrs.display_name}")
  end
end)

IO.puts("\nSeeded #{length(word_classes)} word classes.")
