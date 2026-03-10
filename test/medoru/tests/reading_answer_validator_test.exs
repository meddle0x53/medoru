defmodule Medoru.Tests.ReadingAnswerValidatorTest do
  use Medoru.DataCase

  alias Medoru.Tests.ReadingAnswerValidator

  describe "validate_meaning/2" do
    test "accepts exact match" do
      assert ReadingAnswerValidator.validate_meaning("to eat", "to eat") == true
    end

    test "accepts case insensitive match" do
      assert ReadingAnswerValidator.validate_meaning("to eat", "TO EAT") == true
      assert ReadingAnswerValidator.validate_meaning("to eat", "To Eat") == true
    end

    test "accepts partial match when answer is in correct meaning" do
      assert ReadingAnswerValidator.validate_meaning("to eat", "eat") == true
    end

    test "accepts when correct meaning is contained in answer" do
      assert ReadingAnswerValidator.validate_meaning("book", "notebook") == true
    end

    test "accepts with stripped prefixes" do
      assert ReadingAnswerValidator.validate_meaning("to eat", "eat") == true
      assert ReadingAnswerValidator.validate_meaning("a book", "book") == true
      assert ReadingAnswerValidator.validate_meaning("the house", "house") == true
    end

    test "rejects incorrect meanings" do
      assert ReadingAnswerValidator.validate_meaning("to eat", "to drink") == false
      assert ReadingAnswerValidator.validate_meaning("book", "pen") == false
    end

    test "accepts word overlap" do
      assert ReadingAnswerValidator.validate_meaning("to go somewhere", "to go") == true
    end
  end

  describe "validate_reading/2" do
    test "accepts exact match" do
      assert ReadingAnswerValidator.validate_reading("たべる", "たべる") == true
    end

    test "accepts katakana to hiragana conversion" do
      assert ReadingAnswerValidator.validate_reading("タベル", "たべる") == true
    end

    test "accepts ou/oo long vowel variation" do
      assert ReadingAnswerValidator.validate_reading("とうきょう", "とおきょう") == true
      assert ReadingAnswerValidator.validate_reading("とおきょう", "とうきょう") == true
    end

    test "accepts ei/ee long vowel variation" do
      assert ReadingAnswerValidator.validate_reading("せんせい", "せんせえ") == true
      assert ReadingAnswerValidator.validate_reading("せんせえ", "せんせい") == true
    end

    test "rejects different readings" do
      assert ReadingAnswerValidator.validate_reading("たべる", "のむ") == false
      assert ReadingAnswerValidator.validate_reading("ほん", "ざっし") == false
    end

    test "rejects kanji input" do
      assert ReadingAnswerValidator.validate_reading("たべる", "食べる") == false
    end
  end

  describe "validate_answer/3" do
    test "returns both correct when both match" do
      word = %{meaning: "to eat", reading: "たべる"}

      {:ok, result} = ReadingAnswerValidator.validate_answer(word, "to eat", "たべる")

      assert result.meaning_correct == true
      assert result.reading_correct == true
      assert result.both_correct == true
    end

    test "returns meaning incorrect when meaning is wrong" do
      word = %{meaning: "to eat", reading: "たべる"}

      {:ok, result} = ReadingAnswerValidator.validate_answer(word, "to drink", "たべる")

      assert result.meaning_correct == false
      assert result.reading_correct == true
      assert result.both_correct == false
    end

    test "returns reading incorrect when reading is wrong" do
      word = %{meaning: "to eat", reading: "たべる"}

      {:ok, result} = ReadingAnswerValidator.validate_answer(word, "to eat", "のむ")

      assert result.meaning_correct == true
      assert result.reading_correct == false
      assert result.both_correct == false
    end

    test "returns both incorrect when both are wrong" do
      word = %{meaning: "to eat", reading: "たべる"}

      {:ok, result} = ReadingAnswerValidator.validate_answer(word, "to drink", "のむ")

      assert result.meaning_correct == false
      assert result.reading_correct == false
      assert result.both_correct == false
    end

    test "accepts fuzzy meaning match" do
      word = %{meaning: "to eat", reading: "たべる"}

      {:ok, result} = ReadingAnswerValidator.validate_answer(word, "eat", "たべる")

      assert result.meaning_correct == true
      assert result.reading_correct == true
      assert result.both_correct == true
    end

    test "accepts kana variation" do
      word = %{meaning: "Tokyo", reading: "とうきょう"}

      {:ok, result} = ReadingAnswerValidator.validate_answer(word, "Tokyo", "とおきょう")

      assert result.meaning_correct == true
      assert result.reading_correct == true
      assert result.both_correct == true
    end
  end

  describe "meaning_hint/1" do
    test "returns first letter with ellipsis" do
      assert ReadingAnswerValidator.meaning_hint("to eat") == "t..."
      assert ReadingAnswerValidator.meaning_hint("book") == "b..."
    end

    test "handles empty string" do
      assert ReadingAnswerValidator.meaning_hint("") == "..."
    end
  end

  describe "reading_hint/1" do
    test "returns first kana with ellipsis" do
      assert ReadingAnswerValidator.reading_hint("たべる") == "た..."
      assert ReadingAnswerValidator.reading_hint("ほん") == "ほ..."
    end

    test "handles empty string" do
      assert ReadingAnswerValidator.reading_hint("") == "..."
    end
  end
end
