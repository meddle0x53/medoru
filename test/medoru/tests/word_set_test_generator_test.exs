defmodule Medoru.Tests.WordSetTestGeneratorTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.WordSets
  alias Medoru.Tests

  defp word_set_with_words(user, words, name \\ "Generator Set") do
    word_set = word_set_fixture(%{user_id: user.id, name: name})
    Enum.each(words, &WordSets.add_word_to_set(word_set, &1.id))
    word_set
  end

  describe "meaning_only steps" do
    test "produces single-field reading_text steps with text_mode meaning" do
      user = user_fixture()
      word = word_fixture(%{text: "食べる", meaning: "to eat", reading: "たべる"})
      word_set = word_set_with_words(user, [word])

      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:meaning_only],
          max_steps_per_word: 1
        )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 1
      step = hd(test.test_steps)

      assert step.question_type == :reading_text
      assert step.question == "食べる"
      assert step.correct_answer == "to eat"
      refute step.correct_answer =~ "|"

      data = step.question_data
      assert data["text_mode"] == "meaning"
      assert data["question_label"] == "meaning_only"
      assert data["word_text"] == "食べる"
      assert data["word_reading"] == "たべる"
      assert data["is_kana_only"] == false
    end

    test "is generated for kana-only words" do
      user = user_fixture()
      word = word_fixture(%{text: "テスト", meaning: "test", reading: "てすと"})
      word_set = word_set_with_words(user, [word])

      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:meaning_only],
          max_steps_per_word: 1
        )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 1
      assert hd(test.test_steps).question_data["is_kana_only"] == true
    end
  end

  describe "reading_only steps" do
    test "produces single-field reading_text steps with text_mode reading" do
      user = user_fixture()
      word = word_fixture(%{text: "食べる", meaning: "to eat", reading: "たべる"})
      word_set = word_set_with_words(user, [word])

      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_only],
          max_steps_per_word: 1
        )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 1
      step = hd(test.test_steps)

      assert step.question_type == :reading_text
      assert step.correct_answer == "たべる"
      refute step.correct_answer =~ "|"
      assert step.question_data["text_mode"] == "reading"
      assert step.question_data["question_label"] == "reading_only"
    end

    test "is never generated for kana-only words" do
      user = user_fixture()
      kana_word = word_fixture(%{text: "テスト", meaning: "test", reading: "てすと"})
      kanji_word = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word_set = word_set_with_words(user, [kana_word, kanji_word])

      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_only],
          max_steps_per_word: 1
        )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 1
      step = hd(test.test_steps)
      assert step.word_id == kanji_word.id
      refute step.word_id == kana_word.id
    end
  end

  describe "reading_text steps" do
    test "keep the dual meaning|reading correct answer format" do
      user = user_fixture()
      word = word_fixture(%{text: "食べる", meaning: "to eat", reading: "たべる"})
      word_set = word_set_with_words(user, [word])

      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:reading_text],
          max_steps_per_word: 1
        )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      step = hd(test.test_steps)

      assert step.question_type == :reading_text
      assert step.correct_answer == "to eat|たべる"
      assert step.question_data["text_mode"] == nil
    end
  end

  describe "meaning_to_word steps" do
    test "produces multichoice steps asking for the Japanese word" do
      user = user_fixture()

      words = [
        word_fixture(%{text: "食べる", meaning: "to eat", reading: "たべる"}),
        word_fixture(%{text: "飲む", meaning: "to drink", reading: "のむ"}),
        word_fixture(%{text: "走る", meaning: "to run", reading: "はしる"}),
        word_fixture(%{text: "見る", meaning: "to see", reading: "みる"})
      ]

      word_set = word_set_with_words(user, words)

      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:meaning_to_word],
          max_steps_per_word: 1
        )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 4

      Enum.each(test.test_steps, fn step ->
        assert step.question_type == :multichoice
        assert step.points == 0

        word = Enum.find(words, &(&1.id == step.word_id))
        assert step.correct_answer == "#{word.text} / #{word.reading}"

        data = step.question_data
        assert data["type"] == "meaning_to_word"
        assert data["word_text"] == word.text
        assert data["word_reading"] == word.reading
        assert data["question_label"] == "word"
        assert is_list(data["meaning_indices"])

        assert step.question ==
                 Medoru.Tests.MeaningSegments.pick_indices(word.meaning, data["meaning_indices"])
                 |> Medoru.Tests.MeaningSegments.join()

        assert is_list(step.options)
        assert length(step.options) == 4
        assert step.correct_answer in step.options

        # option_word_ids is index-aligned with options and carries the correct word id
        assert length(data["option_word_ids"]) == length(step.options)
        correct_index = Enum.find_index(step.options, &(&1 == step.correct_answer))
        assert Enum.at(data["option_word_ids"], correct_index) == word.id
      end)
    end
  end

  describe "meaning_to_text steps" do
    test "produces typed steps with word_or_reading text mode and no options" do
      user = user_fixture()

      words = [
        word_fixture(%{text: "食べる", meaning: "to eat", reading: "たべる"}),
        word_fixture(%{text: "飲む", meaning: "to drink", reading: "のむ"})
      ]

      word_set = word_set_with_words(user, words)

      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:meaning_to_text],
          max_steps_per_word: 1
        )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 2

      Enum.each(test.test_steps, fn step ->
        assert step.question_type == :reading_text
        assert step.points == 0

        word = Enum.find(words, &(&1.id == step.word_id))
        assert step.correct_answer == "#{word.text} / #{word.reading}"

        data = step.question_data
        assert data["type"] == "meaning_to_text"
        assert data["word_text"] == word.text
        assert data["word_reading"] == word.reading
        assert data["question_label"] == "word"
        assert data["text_mode"] == "word_or_reading"
        assert is_list(data["meaning_indices"])

        assert step.question ==
                 Medoru.Tests.MeaningSegments.pick_indices(word.meaning, data["meaning_indices"])
                 |> Medoru.Tests.MeaningSegments.join()

        assert step.options == []
      end)
    end
  end

  describe "validate_step_types" do
    test "unknown step types are rejected" do
      user = user_fixture()
      word = word_fixture(%{text: "食べる", meaning: "to eat", reading: "たべる"})
      word_set = word_set_with_words(user, [word])

      {:ok, test} =
        WordSets.create_practice_test(word_set,
          step_types: [:bogus_type],
          max_steps_per_word: 1
        )

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert test.metadata["step_types"] == []
      assert test.test_steps == []
    end
  end
end
