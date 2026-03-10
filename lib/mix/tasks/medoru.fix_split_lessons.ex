defmodule Mix.Tasks.Medoru.FixSplitLessons do
  @moduledoc """
  Fixes split lessons by:
  1. Removing duplicates (keeping only one copy of each)
  2. Renaming from 0-based to 1-based indexing (e.g., "Lesson (0)" -> "Lesson (1)")

  ## Examples

      mix medoru.fix_split_lessons

  """
  use Mix.Task
  require Logger

  alias Medoru.Repo
  alias Medoru.Content.{Lesson, LessonWord}
  alias Medoru.Tests.{Test, TestStep, TestStepAnswer}
  alias Medoru.Learning.LessonProgress

  import Ecto.Query

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    Logger.info("Starting: Fixing split lessons")

    # Step 1: Remove duplicates
    Logger.info("Step 1: Removing duplicate lessons...")
    removed_count = remove_duplicates()
    Logger.info("  Removed #{removed_count} duplicate lessons")

    # Step 2: Rename from 0-based to 1-based
    Logger.info("Step 2: Renaming to 1-based indexing...")
    renamed_count = rename_to_one_based()
    Logger.info("  Renamed #{renamed_count} lessons")

    Logger.info("Fix complete!")
    Logger.info("Summary:")
    Logger.info("  - Removed #{removed_count} duplicates")
    Logger.info("  - Renamed #{renamed_count} lessons to 1-based indexing")
  end

  defp remove_duplicates do
    # Find all duplicate titles
    duplicates = Repo.all(from l in Lesson,
      where: ilike(l.title, "%(%)%"),
      group_by: l.title,
      having: count(l.id) > 1,
      select: {l.title, count(l.id)}
    )

    total_removed = Enum.reduce(duplicates, 0, fn {title, count}, acc ->
      # Get all lessons with this title, ordered by inserted_at
      lessons = Repo.all(from l in Lesson,
        where: l.title == ^title,
        order_by: l.inserted_at,
        select: {l.id, l.test_id}
      )

      # Keep the first one, delete the rest
      to_delete = Enum.drop(lessons, 1)
      delete_lessons(to_delete)

      acc + length(to_delete)
    end)

    total_removed
  end

  defp delete_lessons(lessons_to_delete) do
    lesson_ids = Enum.map(lessons_to_delete, fn {id, _} -> id end)
    test_ids = Enum.filter(lessons_to_delete, fn {_, test_id} -> test_id end) |> Enum.map(fn {_, test_id} -> test_id end)

    Repo.transaction(fn ->
      # Delete test data if any
      if length(test_ids) > 0 do
        test_step_ids = Repo.all(from ts in TestStep, where: ts.test_id in ^test_ids, select: ts.id)
        if length(test_step_ids) > 0 do
          Repo.delete_all(from tsa in TestStepAnswer, where: tsa.test_step_id in ^test_step_ids)
          Repo.delete_all(from ts in TestStep, where: ts.id in ^test_step_ids)
        end
        Repo.delete_all(from t in Test, where: t.id in ^test_ids)
      end

      # Delete lesson progress entries
      Repo.delete_all(from lp in LessonProgress, where: lp.lesson_id in ^lesson_ids)

      # Delete lesson word links
      Repo.delete_all(from lw in LessonWord, where: lw.lesson_id in ^lesson_ids)

      # Delete the lessons
      Repo.delete_all(from l in Lesson, where: l.id in ^lesson_ids)
    end)
  end

  defp rename_to_one_based do
    # Find all lessons that have numbered parts (e.g., "Lesson (0)", "Lesson (1)")
    # Get unique base names first
    all_numbered = Repo.all(from l in Lesson, where: like(l.title, "% (%)"))

    # Group by base name
    grouped = Enum.group_by(all_numbered, fn lesson ->
      String.replace(lesson.title, ~r/ \\([0-9]+\\)$/, "")
    end)

    # For each group, rename from 0-based to 1-based
    Enum.each(grouped, fn {_base_name, lessons} ->
      # Sort by current number
      sorted = Enum.sort_by(lessons, fn l ->
        case Regex.run(~r/\\((\\d+)\\)$/, l.title) do
          [_, num] -> String.to_integer(num)
          _ -> 0
        end
      end)

      # Rename each to 1-based index
      Enum.with_index(sorted, 1)
      |> Enum.each(fn {lesson, new_index} ->
        old_number = case Regex.run(~r/\\((\\d+)\\)$/, lesson.title) do
          [_, num] -> num
          _ -> "0"
        end

        new_title = String.replace(lesson.title, " (#{old_number})", " (#{new_index})")

        if new_title != lesson.title do
          Repo.update!(Ecto.Changeset.change(lesson, title: new_title))
        end
      end)
    end)

    # Count groups that had (0) lessons (were 0-based)
    Enum.count(grouped, fn {_, lessons} ->
      Enum.any?(lessons, fn l -> String.ends_with?(l.title, " (0)") end)
    end)
  end
end
