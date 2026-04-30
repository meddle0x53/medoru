defmodule Medoru.Tests.WordSetOptionsTest do
  use Medoru.DataCase, async: true

  import Medoru.{AccountsFixtures, ContentFixtures, LearningFixtures}

  alias Medoru.Learning.WordSets
  alias Medoru.Tests.TestStep

  test "word set test generates multiple options per question" do
    user = user_fixture()

    # Create 3 words with distinct meanings
    word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
    word2 = word_fixture(%{text: "一", meaning: "one", reading: "いち"})
    word3 = word_fixture(%{text: "飲む", meaning: "to drink", reading: "のむ"})

    word_set = word_set_fixture(%{user_id: user.id, name: "Test Set"})
    {:ok, _} = WordSets.add_word_to_set(word_set, word1.id)
    {:ok, _} = WordSets.add_word_to_set(word_set, word2.id)
    {:ok, _} = WordSets.add_word_to_set(word_set, word3.id)

    {:ok, test} =
      WordSets.create_practice_test(word_set,
        step_types: [:word_to_meaning],
        max_steps_per_word: 1,
        distractor_count: 3
      )

    steps = Medoru.Repo.all(from s in TestStep, where: s.test_id == ^test.id)

    for step <- steps do
      assert length(step.options) >= 2,
             "Expected at least 2 options for step #{step.id} (question: #{step.question}), got #{length(step.options)}: #{inspect(step.options)}"
    end
  end

  test "word set test with duplicate meanings still has options" do
    user = user_fixture()

    # Create 3 words where 2 have the SAME meaning
    word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
    word2 = word_fixture(%{text: "にほん", meaning: "Japan", reading: "にほん"})
    word3 = word_fixture(%{text: "飲む", meaning: "to drink", reading: "のむ"})

    word_set = word_set_fixture(%{user_id: user.id, name: "Test Set"})
    {:ok, _} = WordSets.add_word_to_set(word_set, word1.id)
    {:ok, _} = WordSets.add_word_to_set(word_set, word2.id)
    {:ok, _} = WordSets.add_word_to_set(word_set, word3.id)

    {:ok, test} =
      WordSets.create_practice_test(word_set,
        step_types: [:word_to_meaning],
        max_steps_per_word: 1,
        distractor_count: 3
      )

    steps = Medoru.Repo.all(from s in TestStep, where: s.test_id == ^test.id)

    for step <- steps do
      assert length(step.options) >= 2,
             "Expected at least 2 options for step #{step.id}, got #{length(step.options)}: #{inspect(step.options)}"
    end
  end
end
