defmodule Mix.Tasks.Medoru.MoveNumbersToLesson do
  @moduledoc """
  Moves number words from "Basic Words & Pronouns" to "Numbers 1-10" lesson.

  This task:
  1. Identifies number words (一-六 and their つ versions) from Basic Words & Pronouns
  2. Moves them to the Numbers 1-10 lesson
  3. Reorders positions in both lessons
  4. Archives old tests and regenerates new ones for affected lessons

  ## Examples

      mix medoru.move_numbers_to_lesson

  """

  use Mix.Task

  require Logger

  import Ecto.Query

  alias Medoru.Repo
  alias Medoru.Content.{Lesson, LessonWord}
  alias Medoru.Tests

  @number_texts ["一", "二", "三", "四", "五", "六", "一つ", "二つ", "三つ", "四つ", "五つ", "六つ"]
  @number_meanings ["one", "two", "three", "four", "five", "six"]

  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("Starting migration: Moving numbers to Numbers 1-10 lesson")

    # Find the lessons
    basic_lesson = find_lesson("Basic Words & Pronouns")
    numbers_lesson = find_lesson("Numbers 1-10")

    if is_nil(basic_lesson) do
      Logger.error("Could not find 'Basic Words & Pronouns' lesson")
      exit({:shutdown, 1})
    end

    if is_nil(numbers_lesson) do
      Logger.error("Could not find 'Numbers 1-10' lesson")
      exit({:shutdown, 1})
    end

    Logger.info("Found lessons:")
    Logger.info("  Basic Words & Pronouns: #{basic_lesson.id}")
    Logger.info("  Numbers 1-10: #{numbers_lesson.id}")

    # Get current lesson words
    basic_words = get_lesson_words(basic_lesson.id)
    numbers_words = get_lesson_words(numbers_lesson.id)

    Logger.info("Current word counts:")
    Logger.info("  Basic Words & Pronouns: #{length(basic_words)} words")
    Logger.info("  Numbers 1-10: #{length(numbers_words)} words")

    # Identify number words to move
    number_word_ids = identify_number_words(basic_words)

    Logger.info("Found #{length(number_word_ids)} number words to move:")

    Enum.each(number_word_ids, fn word_id ->
      word = Enum.find(basic_words, &(&1.word_id == word_id))
      Logger.info("  - #{word.word.text} (#{word.word.meaning}) at position #{word.position}")
    end)

    if number_word_ids == [] do
      Logger.info("No number words found to move. Exiting.")
      :ok
    else
      # Archive existing tests for both lessons
      Logger.info("Archiving existing tests...")
      archive_lesson_tests(basic_lesson.id)
      archive_lesson_tests(numbers_lesson.id)

      # Move number words
      Logger.info("Moving number words...")
      move_number_words(number_word_ids, basic_lesson.id, numbers_lesson.id)

      # Reorder positions in both lessons
      Logger.info("Reordering positions...")
      reorder_lesson_positions(basic_lesson.id)
      reorder_lesson_positions(numbers_lesson.id)

      # Verify the move
      new_basic_words = get_lesson_words(basic_lesson.id)
      new_numbers_words = get_lesson_words(numbers_lesson.id)

      Logger.info("Migration complete!")
      Logger.info("New word counts:")
      Logger.info("  Basic Words & Pronouns: #{length(new_basic_words)} words")
      Logger.info("  Numbers 1-10: #{length(new_numbers_words)} words")

      # Show what remains in Basic Words
      Logger.info("Words remaining in Basic Words & Pronouns:")

      Enum.each(new_basic_words, fn lw ->
        Logger.info("  - #{lw.word.text} (#{lw.word.meaning})")
      end)

      # Show what's now in Numbers 1-10
      Logger.info("Words now in Numbers 1-10:")

      Enum.each(new_numbers_words, fn lw ->
        Logger.info("  - #{lw.word.text} (#{lw.word.meaning}) at position #{lw.position}")
      end)

      Logger.info("✅ Migration completed successfully!")
      Logger.info("Note: New tests will be auto-generated when users access these lessons.")
    end
  end

  defp find_lesson(title_pattern) do
    Lesson
    |> where([l], ilike(l.title, ^"%#{title_pattern}%"))
    |> Repo.one()
  end

  defp get_lesson_words(lesson_id) do
    LessonWord
    |> where([lw], lw.lesson_id == ^lesson_id)
    |> preload(:word)
    |> order_by([lw], lw.position)
    |> Repo.all()
  end

  defp identify_number_words(lesson_words) do
    lesson_words
    |> Enum.filter(fn lw ->
      word = lw.word
      word.text in @number_texts or word.meaning in @number_meanings
    end)
    |> Enum.map(& &1.word_id)
  end

  defp archive_lesson_tests(lesson_id) do
    lesson = Repo.get(Lesson, lesson_id) |> Repo.preload(:test)

    if lesson.test_id do
      test = Tests.get_test!(lesson.test_id)
      {:ok, _} = Tests.archive_test(test)
      Logger.info("  Archived test for lesson #{lesson_id}")
    end
  end

  defp move_number_words(word_ids, from_lesson_id, to_lesson_id) do
    # Get current max position in target lesson
    max_position =
      LessonWord
      |> where([lw], lw.lesson_id == ^to_lesson_id)
      |> select([lw], max(lw.position))
      |> Repo.one() || -1

    # Move each word
    Enum.with_index(word_ids, fn word_id, index ->
      lesson_word =
        LessonWord
        |> where([lw], lw.lesson_id == ^from_lesson_id and lw.word_id == ^word_id)
        |> Repo.one()

      if lesson_word do
        new_position = max_position + index + 1

        lesson_word
        |> Ecto.Changeset.change(%{
          lesson_id: to_lesson_id,
          position: new_position
        })
        |> Repo.update!()

        Logger.info("  Moved word #{word_id} to position #{new_position}")
      end
    end)
  end

  defp reorder_lesson_positions(lesson_id) do
    lesson_words =
      LessonWord
      |> where([lw], lw.lesson_id == ^lesson_id)
      |> order_by([lw], lw.position)
      |> Repo.all()

    Enum.with_index(lesson_words, fn lesson_word, index ->
      lesson_word
      |> Ecto.Changeset.change(%{position: index})
      |> Repo.update!()
    end)

    Logger.info("  Reordered #{length(lesson_words)} words in lesson #{lesson_id}")
  end
end
