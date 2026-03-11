defmodule Mix.Tasks.Medoru.SplitLargeLessons do
  @moduledoc """
  Splits lessons with more than 10 words into smaller lessons of 5 words each.

  For example, a lesson with 15 words will be split into 3 lessons:
  - "Lesson Title (1)" - words 1-5
  - "Lesson Title (2)" - words 6-10  
  - "Lesson Title (3)" - words 11-15

  ## Examples

      mix medoru.split_large_lessons

  """

  use Mix.Task

  require Logger

  import Ecto.Query

  alias Medoru.Repo
  alias Medoru.Content.{Lesson, LessonWord}
  alias Medoru.Tests

  @split_threshold 10
  @words_per_lesson 5

  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("Starting: Splitting large lessons into chunks of #{@words_per_lesson} words")

    # Find all lessons with more than threshold words
    large_lessons = find_large_lessons()

    # Filter out already archived lessons
    large_lessons =
      Enum.filter(large_lessons, fn {lesson, _} ->
        not String.contains?(lesson.title, "[ARCHIVED")
      end)

    Logger.info("Found #{length(large_lessons)} lessons with more than #{@split_threshold} words")

    if large_lessons == [] do
      Logger.info("No lessons to split. Exiting.")
    else
      # Process each large lesson
      Enum.each(large_lessons, fn {lesson, word_count} ->
        Logger.info("Processing '#{lesson.title}' with #{word_count} words...")
        split_lesson(lesson, word_count)
      end)

      Logger.info("✅ Migration complete!")

      Logger.info(
        "Note: Old lessons have been kept for reference. Run 'mix medoru.delete_split_lessons' to remove them after verifying the new lessons."
      )
    end
  end

  defp find_large_lessons do
    Lesson
    |> join(:inner, [l], lw in LessonWord, on: lw.lesson_id == l.id)
    |> group_by([l], l.id)
    |> having([_, lw], count(lw.id) > ^@split_threshold)
    |> select([l, lw], {l, count(lw.id)})
    |> Repo.all()
    |> Enum.sort_by(fn {_, count} -> -count end)
  end

  defp split_lesson(lesson, word_count) do
    # Get lesson words ordered by position
    lesson_words =
      LessonWord
      |> where([lw], lw.lesson_id == ^lesson.id)
      |> preload(:word)
      |> order_by([lw], lw.position)
      |> Repo.all()

    # Archive existing test if present
    if lesson.test_id do
      old_test = Tests.get_test!(lesson.test_id)
      {:ok, _} = Tests.archive_test(old_test)
      Logger.info("  Archived old test")
    end

    # Calculate how many new lessons we need
    num_chunks = calculate_chunks(word_count)
    Logger.info("  Splitting into #{num_chunks} lessons of ~#{@words_per_lesson} words each")

    # Create new lessons
    Enum.with_index(1..num_chunks, fn _chunk_index, i ->
      # Get words for this chunk
      start_idx = (i - 1) * @words_per_lesson
      end_idx = min(i * @words_per_lesson - 1, word_count - 1)
      chunk_words = Enum.slice(lesson_words, start_idx..end_idx)

      # Create new lesson
      new_title = "#{lesson.title} (#{i})"

      # Determine difficulty based on original
      difficulty = lesson.difficulty || 5

      # Create the new lesson - use a large offset for order_index to ensure proper ordering
      # This ensures split lessons appear after the original lesson's position
      lesson_attrs = %{
        title: new_title,
        description: "Part #{i} of #{num_chunks}: #{lesson.description}",
        difficulty: difficulty,
        order_index: lesson.order_index * 1000 + i,
        lesson_type: lesson.lesson_type || :system
      }

      word_links =
        Enum.with_index(chunk_words, fn lw, idx ->
          %{
            word_id: lw.word_id,
            position: idx
          }
        end)

      case Medoru.Content.create_lesson_with_words(lesson_attrs, word_links) do
        {:ok, new_lesson} ->
          Logger.info("  Created '#{new_lesson.title}' with #{length(chunk_words)} words")

          # Generate test for the new lesson
          case Tests.generate_lesson_test(new_lesson.id) do
            {:ok, _test} ->
              Logger.info("    Generated test for '#{new_lesson.title}'")

            {:error, reason} ->
              Logger.warning("    Could not generate test: #{inspect(reason)}")
          end

          new_lesson

        {:error, changeset} ->
          Logger.error("  Failed to create lesson '#{new_title}': #{inspect(changeset.errors)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    # Mark original lesson as archived
    lesson
    |> Ecto.Changeset.change(%{
      title: "#{lesson.title} [ARCHIVED - SPLIT]"
    })
    |> Repo.update!()

    Logger.info("  Marked original lesson as archived")
  end

  defp calculate_chunks(n) when is_integer(n) do
    div(n + @words_per_lesson - 1, @words_per_lesson)
  end
end
