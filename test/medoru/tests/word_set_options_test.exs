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

  test "image_to_meaning steps are generated when enough words have images" do
    user = user_fixture()

    words =
      ["日本", "学校", "先生", "学生", "図書館"]
      |> Enum.map(fn text ->
        word_fixture(%{
          text: text,
          meaning: "meaning #{text}",
          reading: "てすと",
          image_path: "/uploads/word_images/#{text}.png"
        })
      end)

    word_set = word_set_fixture(%{user_id: user.id, name: "Image Set"})
    Enum.each(words, &WordSets.add_word_to_set(word_set, &1.id))

    {:ok, test} =
      WordSets.create_practice_test(word_set,
        step_types: [:image_to_meaning],
        max_steps_per_word: 1,
        distractor_count: 3
      )

    steps = Medoru.Repo.all(from s in TestStep, where: s.test_id == ^test.id)

    assert Enum.any?(steps, &(&1.question_data["type"] == "image_to_meaning"))
    assert Enum.all?(steps, &(&1.question_data["image_options"] != []))
  end

  test "image options align with option meanings by index" do
    user = user_fixture()

    words =
      ["日本", "学校", "先生", "学生", "図書館"]
      |> Enum.map(fn text ->
        word_fixture(%{
          text: text,
          meaning: "meaning #{text}",
          reading: "てすと",
          image_path: "/uploads/word_images/#{text}.png"
        })
      end)

    word_set = word_set_fixture(%{user_id: user.id, name: "Image Align Set"})
    Enum.each(words, &WordSets.add_word_to_set(word_set, &1.id))

    {:ok, test} =
      WordSets.create_practice_test(word_set,
        step_types: [:image_to_meaning],
        max_steps_per_word: 1,
        distractor_count: 3
      )

    steps = Medoru.Repo.all(from s in TestStep, where: s.test_id == ^test.id)
    image_steps = Enum.filter(steps, &(&1.question_data["type"] == "image_to_meaning"))

    assert length(image_steps) > 0

    for step <- image_steps do
      options = step.question_data["options"]
      image_options = step.question_data["image_options"]
      option_word_ids = step.question_data["option_word_ids"]

      assert length(image_options) == length(options)
      assert length(option_word_ids) == length(options)

      Enum.with_index(options, fn meaning, index ->
        image = Enum.at(image_options, index)
        word_id = Enum.at(option_word_ids, index)

        assert image["word_id"] == word_id,
               "image/word_id mismatch at index #{index} for step #{step.id}"

        word = Enum.find(words, &(&1.id == word_id))
        assert word.meaning == meaning, "meaning mismatch at index #{index} for step #{step.id}"
        assert image["image_path"] == word.image_path
      end)
    end
  end
end
