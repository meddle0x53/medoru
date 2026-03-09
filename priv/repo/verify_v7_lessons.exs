#!/usr/bin/env elixir
# Verify v7 lessons were created correctly

alias Medoru.Repo
import Ecto.Query
alias Medoru.Content.Lesson

IO.puts("=" |> String.duplicate(60))
IO.puts("v7 Lesson Verification")
IO.puts("=" |> String.duplicate(60))

# Count by difficulty
n5 = Repo.aggregate(from(l in Lesson, where: l.difficulty == 5), :count)
n4 = Repo.aggregate(from(l in Lesson, where: l.difficulty == 4), :count)
n3 = Repo.aggregate(from(l in Lesson, where: l.difficulty == 3), :count)

IO.puts("\nLessons by Difficulty:")
IO.puts("  N5 (difficulty 5): #{n5}")
IO.puts("  N4 (difficulty 4): #{n4}")
IO.puts("  N3 (difficulty 3): #{n3}")
IO.puts("  Total: #{n5 + n4 + n3}")

# Lesson type distribution
IO.puts("\nLesson Type Distribution:")
Repo.all(from l in Lesson, where: l.difficulty in [3,4,5], group_by: [l.difficulty, l.lesson_type], select: {l.difficulty, l.lesson_type, count(l.id)})
|> Enum.each(fn {diff, type, count} ->
  level = "N#{diff}"
  IO.puts("  #{level} #{type}: #{count}")
end)

# Sample N5 lessons
IO.puts("\nSample N5 Lessons (first 10):")
Repo.all(from l in Lesson, where: l.difficulty == 5, order_by: l.order_index, limit: 10)
|> Repo.preload(:lesson_words)
|> Enum.each(fn l ->
  type = Atom.to_string(l.lesson_type)
  word_count = length(l.lesson_words)
  IO.puts("  #{l.order_index + 1}. #{l.title} (#{type}, #{word_count} words)")
end)

# Total word links
word_count = Repo.aggregate(from(lw in "lesson_words", join: l in Lesson, on: lw.lesson_id == l.id, where: l.difficulty in [3,4,5]), :count)
IO.puts("\nTotal word-lesson links: #{word_count}")

IO.puts("\n" <> "=" |> String.duplicate(60))
IO.puts("✅ Verification complete!")
IO.puts("=" |> String.duplicate(60))
