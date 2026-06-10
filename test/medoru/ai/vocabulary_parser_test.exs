defmodule Medoru.AI.VocabularyParserTest do
  use ExUnit.Case, async: true

  alias Medoru.AI.VocabularyParser

  describe "parse_extracted_words/1" do
    test "returns empty list for non-list input" do
      assert VocabularyParser.parse_extracted_words(nil) == []
      assert VocabularyParser.parse_extracted_words("not a list") == []
    end

    test "parses a noun correctly" do
      words = [
        %{
          "text" => "電気",
          "reading" => "でんき",
          "meaning" => "electricity",
          "word_type" => "noun",
          "verb_group" => nil,
          "image_text" => "電気"
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["text"] == "電気"
      assert result["reading"] == "でんき"
      assert result["meaning"] == "electricity"
      assert result["word_type"] == "noun"
      assert result["verb_group"] == nil
      assert result["notes"] == ""
    end

    test "parses a Group II verb in dictionary form" do
      words = [
        %{
          "text" => "食べる",
          "reading" => "たべる",
          "meaning" => "to eat",
          "word_type" => "verb",
          "verb_group" => "II",
          "image_text" => "食べます"
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["text"] == "食べる"
      assert result["reading"] == "たべる"
      assert result["verb_group"] == "II"
      assert result["notes"] == "Group II verb (from: 食べます)"
    end

    test "safety net: converts masu-form to dictionary form if AI didn't" do
      words = [
        %{
          "text" => "食べます",
          "reading" => "たべます",
          "meaning" => "to eat",
          "word_type" => "verb",
          "verb_group" => "II",
          "notes" => ""
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["text"] == "食べる"
      assert result["reading"] == "たべる"
    end

    test "safety net: converts Group I godan verbs" do
      words = [
        %{
          "text" => "書きます",
          "reading" => "かきます",
          "meaning" => "to write",
          "word_type" => "verb",
          "verb_group" => "I"
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["text"] == "書く"
      assert result["reading"] == "かく"
    end

    test "safety net: converts Group III suru verb" do
      words = [
        %{
          "text" => "勉強します",
          "reading" => "べんきょうします",
          "meaning" => "to study",
          "word_type" => "verb",
          "verb_group" => "III"
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["text"] == "勉強する"
      assert result["reading"] == "べんきょうする"
    end

    test "safety net: converts Group III kuru verb" do
      words = [
        %{
          "text" => "来ます",
          "reading" => "きます",
          "meaning" => "to come",
          "word_type" => "verb",
          "verb_group" => "III"
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["text"] == "来る"
      assert result["reading"] == "くる"
    end

    test "preserves already-dictionary forms" do
      words = [
        %{
          "text" => "消す",
          "reading" => "けす",
          "meaning" => "to turn off",
          "word_type" => "verb",
          "verb_group" => "I",
          "image_text" => "消します"
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["text"] == "消す"
      assert result["reading"] == "けす"
    end

    test "builds notes from verb_group when AI notes are empty" do
      words = [
        %{
          "text" => "読む",
          "reading" => "よむ",
          "meaning" => "to read",
          "word_type" => "verb",
          "verb_group" => "I",
          "image_text" => "読みます",
          "notes" => ""
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["notes"] == "Group I verb (from: 読みます)"
    end

    test "uses existing notes when AI provides them" do
      words = [
        %{
          "text" => "消す",
          "reading" => "けす",
          "meaning" => "to turn off",
          "word_type" => "verb",
          "verb_group" => "I",
          "image_text" => "消します",
          "notes" => "Group I verb (from: 消します)"
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["notes"] == "Group I verb (from: 消します)"
    end

    test "normalizes word types" do
      words = [
        %{"text" => "a", "reading" => "a", "word_type" => "Verb"},
        %{"text" => "a", "reading" => "a", "word_type" => "NOUN"},
        %{"text" => "a", "reading" => "a", "word_type" => "  adjective  "},
        %{"text" => "a", "reading" => "a", "word_type" => "invalid"}
      ]

      results = VocabularyParser.parse_extracted_words(words)
      assert Enum.at(results, 0)["word_type"] == "verb"
      assert Enum.at(results, 1)["word_type"] == "noun"
      assert Enum.at(results, 2)["word_type"] == "adjective"
      assert Enum.at(results, 3)["word_type"] == "other"
    end

    test "normalizes verb groups" do
      words = [
        %{"text" => "a", "reading" => "a", "verb_group" => "I"},
        %{"text" => "a", "reading" => "a", "verb_group" => "  II  "},
        %{"text" => "a", "reading" => "a", "verb_group" => "invalid"},
        %{"text" => "a", "reading" => "a", "verb_group" => nil}
      ]

      results = VocabularyParser.parse_extracted_words(words)
      assert Enum.at(results, 0)["verb_group"] == "I"
      assert Enum.at(results, 1)["verb_group"] == "II"
      assert Enum.at(results, 2)["verb_group"] == nil
      assert Enum.at(results, 3)["verb_group"] == nil
    end

    test "handles empty verb_group for non-verbs" do
      words = [
        %{
          "text" => "学校",
          "reading" => "がっこう",
          "meaning" => "school",
          "word_type" => "noun",
          "verb_group" => nil
        }
      ]

      [result] = VocabularyParser.parse_extracted_words(words)
      assert result["verb_group"] == nil
      assert result["notes"] == ""
    end

    test "handles multiple words" do
      words = [
        %{
          "text" => "消す",
          "reading" => "けす",
          "meaning" => "to turn off",
          "word_type" => "verb",
          "verb_group" => "I",
          "image_text" => "消します"
        },
        %{
          "text" => "電気",
          "reading" => "でんき",
          "meaning" => "electricity",
          "word_type" => "noun",
          "verb_group" => nil,
          "image_text" => "電気"
        }
      ]

      [verb, noun] = VocabularyParser.parse_extracted_words(words)
      assert verb["text"] == "消す"
      assert verb["notes"] == "Group I verb (from: 消します)"
      assert noun["text"] == "電気"
      assert noun["notes"] == ""
    end

    test "filters out invalid entries" do
      words = [
        nil,
        %{
          "text" => "有効",
          "reading" => "ゆうこう",
          "meaning" => "valid",
          "word_type" => "adjective"
        }
      ]

      results = VocabularyParser.parse_extracted_words(words)
      assert length(results) == 1
      assert hd(results)["text"] == "有効"
    end
  end
end
