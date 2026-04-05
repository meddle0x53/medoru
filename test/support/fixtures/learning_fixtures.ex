defmodule Medoru.LearningFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Medoru.Learning` context.
  """

  alias Medoru.Learning
  alias Medoru.Learning.WordSets

  @doc """
  Generate a user_progress for kanji.
  """
  def user_progress_fixture(attrs \\ %{}) do
    {:ok, user_progress} =
      attrs
      |> Enum.into(%{
        mastery_level: 0,
        times_reviewed: 0
      })
      |> then(fn attrs ->
        # Create through Learning context to ensure proper validation
        if attrs[:kanji_id] do
          Learning.track_kanji_learned(attrs[:user_id], attrs[:kanji_id])
        else
          Learning.track_word_learned(attrs[:user_id], attrs[:word_id])
        end
      end)

    user_progress
  end

  @doc """
  Generate a lesson_progress.
  """
  def lesson_progress_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        status: :started,
        progress_percentage: 0
      })

    # Use start_lesson which handles creation properly
    {:ok, lesson_progress} =
      Learning.start_lesson(attrs[:user_id], attrs[:lesson_id])

    # Update with additional attrs if provided
    if attrs[:status] != :started || attrs[:progress_percentage] != 0 do
      {:ok, lesson_progress} =
        Learning.update_lesson_progress(
          attrs[:user_id],
          attrs[:lesson_id],
          attrs[:progress_percentage]
        )

      if attrs[:status] == :completed do
        {:ok, lesson_progress} =
          Learning.complete_lesson(attrs[:user_id], attrs[:lesson_id])

        lesson_progress
      else
        lesson_progress
      end
    else
      lesson_progress
    end
  end

  @doc """
  Generate a word_set.
  """
  def word_set_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Test Word Set #{System.unique_integer([:positive])}",
        description: "A test word set",
        word_count: 0
      })

    {:ok, word_set} = WordSets.create_word_set(attrs)
    word_set
  end
end
