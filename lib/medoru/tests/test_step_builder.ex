defmodule Medoru.Tests.TestStepBuilder do
  @moduledoc """
  Shared functions for building test steps across different test generators.

  Extracted from WordSetTestGenerator to provide reusable distractor handling,
  kanji extraction, and other step-building utilities.
  """

  alias Medoru.Content

  @doc """
  Adds distractor options to a multichoice step using pair-based shuffling.

  ## Options
    * `:field` - The field to extract from distractor words (:meaning, :reading, :text)
    * `:deduplicate` - Whether to deduplicate distractors by field value (default: true)

  Returns the step with `:options` and `:question_data` updated.
  """
  def add_distractors(step, correct_word, count, distractor_pool, opts \\ []) do
    field = Keyword.get(opts, :field, :meaning)
    deduplicate = Keyword.get(opts, :deduplicate, true)

    distractors =
      distractor_pool
      |> Enum.reject(&(&1.id == correct_word.id))
      |> then(fn pool ->
        if deduplicate, do: Enum.uniq_by(pool, &Map.get(&1, field)), else: pool
      end)
      |> Enum.take_random(count)
      |> Enum.map(&Map.get(&1, field))
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == step.correct_answer))

    # Create pairs and shuffle together so word IDs always match options
    pairs = [
      {step.correct_answer, correct_word.id}
      | Enum.zip(distractors, List.duplicate(nil, length(distractors)))
    ]

    shuffled = Enum.shuffle(pairs)
    {options, option_word_ids} = Enum.unzip(shuffled)

    question_data = Map.get(step, :question_data) || %{}

    step
    |> Map.put(:options, options)
    |> Map.put(
      :question_data,
      Map.merge(question_data, %{
        option_word_ids: option_word_ids,
        options: options
      })
    )
  end

  @doc """
  Extracts unique kanji from a word, loading word_kanjis if needed.
  """
  def extract_kanji_from_word(word) do
    case word.word_kanjis do
      %Ecto.Association.NotLoaded{} ->
        word_with_kanji = Content.get_word_with_kanji!(word.id)
        Enum.map(word_with_kanji.word_kanjis, & &1.kanji) |> Enum.reject(&is_nil/1)

      word_kanjis ->
        Enum.map(word_kanjis, & &1.kanji) |> Enum.reject(&is_nil/1)
    end
    |> Enum.uniq_by(& &1.id)
  end
end
