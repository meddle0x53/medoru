defmodule Mix.Tasks.Medoru.DeleteArchivedLessons do
  @moduledoc """
  Deletes all lessons marked as [ARCHIVED - SPLIT] and their associated data.

  This includes:
  - Test step answers (for test sessions referencing these tests)
  - Test steps
  - Tests
  - Lesson word links
  - The archived lessons themselves

  ## Examples

      mix medoru.delete_archived_lessons

  """
  use Mix.Task
  require Logger

  alias Medoru.Repo
  alias Medoru.Content.{Lesson, LessonWord}
  alias Medoru.Tests.{Test, TestStep, TestStepAnswer}

  import Ecto.Query

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    Logger.info("Starting: Deleting archived lessons")

    # Find all archived lessons
    archived_lessons = Repo.all(from l in Lesson, where: ilike(l.title, "%[ARCHIVED - SPLIT]%"))
    lesson_count = length(archived_lessons)

    if lesson_count == 0 do
      Logger.info("No archived lessons found. Exiting.")
      :ok
    else
      Logger.info("Found #{lesson_count} archived lessons to delete")

      lesson_ids = Enum.map(archived_lessons, & &1.id)

      # Get test IDs from archived lessons
      test_ids = Enum.filter(archived_lessons, & &1.test_id) |> Enum.map(& &1.test_id)
      Logger.info("Found #{length(test_ids)} associated tests")

      Repo.transaction(fn ->
        # Step 1: If there are tests, delete their related data first
        if length(test_ids) > 0 do
          # Get test step IDs
          test_step_ids = Repo.all(from ts in TestStep, where: ts.test_id in ^test_ids, select: ts.id)
          Logger.info("Found #{length(test_step_ids)} test steps to delete")

          # Delete test step answers for these test steps
          if length(test_step_ids) > 0 do
            {deleted_answers, _} = Repo.delete_all(from tsa in TestStepAnswer, where: tsa.test_step_id in ^test_step_ids)
            Logger.info("  Deleted #{deleted_answers} test step answers")
          end

          # Delete test steps
          {deleted_steps, _} = Repo.delete_all(from ts in TestStep, where: ts.test_id in ^test_ids)
          Logger.info("  Deleted #{deleted_steps} test steps")

          # Delete tests
          {deleted_tests, _} = Repo.delete_all(from t in Test, where: t.id in ^test_ids)
          Logger.info("  Deleted #{deleted_tests} tests")
        else
          Logger.info("  No tests to delete")
        end

        # Step 2: Delete lesson word links
        {deleted_links, _} = Repo.delete_all(from lw in LessonWord, where: lw.lesson_id in ^lesson_ids)
        Logger.info("  Deleted #{deleted_links} lesson word links")

        # Step 3: Delete the archived lessons
        {deleted_lessons, _} = Repo.delete_all(from l in Lesson, where: l.id in ^lesson_ids)
        Logger.info("  Deleted #{deleted_lessons} archived lessons")

        deleted_lessons
      end)

      Logger.info("Migration complete!")
      Logger.info("Summary:")
      Logger.info("  - Deleted #{lesson_count} archived lessons")
    end
  end
end
