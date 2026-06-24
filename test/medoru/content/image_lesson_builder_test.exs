defmodule Medoru.Content.ImageLessonBuilderTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Content
  alias Medoru.Content.ImageLessonBuilder

  describe "build_lesson_from_extracted_words/3" do
    setup do
      teacher = user_fixture(%{type: "teacher"})
      %{teacher: teacher}
    end

    test "creates a draft lesson with new words when none exist", %{teacher: teacher} do
      extracted_words = [
        %{
          "text" => "消す",
          "image_text" => "消します",
          "reading" => "けす",
          "meaning" => "turn off",
          "word_type" => "verb",
          "verb_group" => "I",
          "notes" => "Group I verb"
        },
        %{
          "text" => "電気",
          "image_text" => "電気",
          "reading" => "でんき",
          "meaning" => "electricity, light",
          "word_type" => "noun",
          "verb_group" => nil,
          "notes" => ""
        }
      ]

      lesson_attrs = %{title: "Test Lesson", description: "From image"}

      assert {:ok, lesson} =
               ImageLessonBuilder.build_lesson_from_extracted_words(
                 extracted_words,
                 lesson_attrs,
                 teacher.id
               )

      assert lesson.title == "Test Lesson"
      assert lesson.description == "From image"
      assert lesson.status == "draft"
      assert lesson.lesson_subtype == "vocabulary"
      assert lesson.creator_id == teacher.id

      lesson_words = Content.list_lesson_words(lesson.id)
      assert length(lesson_words) == 2

      assert Content.get_word_by_text("消す") != nil
      assert Content.get_word_by_text("電気") != nil
    end

    test "links existing words instead of creating duplicates", %{teacher: teacher} do
      existing_word = word_fixture(%{text: "電気", reading: "でんき", meaning: "electricity"})

      extracted_words = [
        %{
          "text" => "電気",
          "image_text" => "電気",
          "reading" => "でんき",
          "meaning" => "electricity, light",
          "word_type" => "noun",
          "verb_group" => nil,
          "notes" => ""
        }
      ]

      lesson_attrs = %{title: "Existing Words Lesson"}

      assert {:ok, lesson} =
               ImageLessonBuilder.build_lesson_from_extracted_words(
                 extracted_words,
                 lesson_attrs,
                 teacher.id
               )

      lesson_words = Content.list_lesson_words(lesson.id)
      assert length(lesson_words) == 1
      assert hd(lesson_words).word_id == existing_word.id
    end

    test "falls back to DB kanji version when AI returns kana-only text", %{teacher: teacher} do
      # Pre-create a word with kanji that matches by reading
      word_fixture(%{text: "消す", reading: "けす", meaning: "turn off"})

      # AI returns kana-only text
      extracted_words = [
        %{
          "text" => "けす",
          "image_text" => "けします",
          "reading" => "けす",
          "meaning" => "turn off",
          "word_type" => "verb",
          "verb_group" => "I",
          "notes" => "Group I verb"
        }
      ]

      assert {:ok, lesson} =
               ImageLessonBuilder.build_lesson_from_extracted_words(
                 extracted_words,
                 %{},
                 teacher.id
               )

      [lesson_word] = Content.list_lesson_words(lesson.id)
      # Should link to the existing "消す" word, not create "けす"
      assert lesson_word.word.text == "消す"
    end

    test "upgrades previously created kana word to kanji version when available", %{
      teacher: teacher
    } do
      # First, a kana-only word was created from a previous upload
      kana_word = word_fixture(%{text: "けす", reading: "けす", meaning: "turn off"})

      # Later, a kanji version was added to the DB
      kanji_word = word_fixture(%{text: "消す", reading: "けす", meaning: "turn off"})

      # AI returns kana-only text again
      extracted_words = [
        %{
          "text" => "けす",
          "image_text" => "けします",
          "reading" => "けす",
          "meaning" => "turn off",
          "word_type" => "verb",
          "verb_group" => "I",
          "notes" => "Group I verb"
        }
      ]

      assert {:ok, lesson} =
               ImageLessonBuilder.build_lesson_from_extracted_words(
                 extracted_words,
                 %{},
                 teacher.id
               )

      [lesson_word] = Content.list_lesson_words(lesson.id)
      # Should link to the kanji "消す" word, not the kana "けす" word
      assert lesson_word.word_id == kanji_word.id
      refute lesson_word.word_id == kana_word.id
    end

    test "stores image form and notes as examples and uses DB meaning", %{teacher: teacher} do
      extracted_words = [
        %{
          "text" => "消す",
          "image_text" => "消します",
          "reading" => "けす",
          "meaning" => "turn off",
          "word_type" => "verb",
          "verb_group" => "I",
          "notes" => "Group I verb"
        }
      ]

      assert {:ok, lesson} =
               ImageLessonBuilder.build_lesson_from_extracted_words(
                 extracted_words,
                 %{},
                 teacher.id
               )

      [lesson_word] = Content.list_lesson_words(lesson.id)
      assert lesson_word.custom_meaning == nil
      assert lesson_word.examples == ["消します (Group I verb)"]
      assert lesson_word.word.meaning == "turn off"
    end

    test "returns error when no words are provided", %{teacher: teacher} do
      assert {:error, _} =
               ImageLessonBuilder.build_lesson_from_extracted_words([], %{}, teacher.id)
    end

    test "uses default title when not provided", %{teacher: teacher} do
      extracted_words = [
        %{
          "text" => "テスト",
          "image_text" => "テスト",
          "reading" => "てすと",
          "meaning" => "test",
          "word_type" => "noun",
          "verb_group" => nil,
          "notes" => ""
        }
      ]

      assert {:ok, lesson} =
               ImageLessonBuilder.build_lesson_from_extracted_words(
                 extracted_words,
                 %{},
                 teacher.id
               )

      assert lesson.title == "Vocabulary lesson from image — change the name"
    end

    test "creates katakana and expression words not present in DB", %{teacher: teacher} do
      extracted_words = [
        %{
          "text" => "アイスクリーム",
          "image_text" => "アイスクリーム",
          "reading" => "アイスクリーム",
          "meaning" => "ice cream",
          "word_type" => "noun",
          "verb_group" => nil,
          "notes" => ""
        },
        %{
          "text" => "どうぞよろしくございます",
          "image_text" => "どうぞよろしくございます",
          "reading" => "どうぞよろしくございます",
          "meaning" => "please be kind to me",
          "word_type" => "expression",
          "verb_group" => nil,
          "notes" => "[どうぞ]よろしく[ございます]"
        }
      ]

      assert {:ok, lesson} =
               ImageLessonBuilder.build_lesson_from_extracted_words(
                 extracted_words,
                 %{},
                 teacher.id
               )

      lesson_words = Content.list_lesson_words(lesson.id)
      assert length(lesson_words) == 2

      assert Content.get_word_by_text("アイスクリーム") != nil
      expression_word = Content.get_word_by_text("どうぞよろしくございます")
      assert expression_word != nil
      assert expression_word.word_type == :expression

      expression_lesson_word = Enum.find(lesson_words, &(&1.word_id == expression_word.id))

      assert expression_lesson_word.examples == [
               "どうぞよろしくございます ([どうぞ]よろしく[ございます])"
             ]
    end

    test "slices lesson title and description to safe lengths", %{teacher: teacher} do
      long_title = String.duplicate("あ", 150)
      long_description = String.duplicate("い", 600)

      extracted_words = [
        %{
          "text" => "テスト",
          "image_text" => "テスト",
          "reading" => "てすと",
          "meaning" => "test",
          "word_type" => "noun",
          "verb_group" => nil,
          "notes" => ""
        }
      ]

      assert {:ok, lesson} =
               ImageLessonBuilder.build_lesson_from_extracted_words(
                 extracted_words,
                 %{title: long_title, description: long_description},
                 teacher.id
               )

      assert String.length(lesson.title) == 100
      assert String.length(lesson.description) == 500
    end

    test "normalizes readings with punctuation and whitespace", %{teacher: teacher} do
      extracted_words = [
        %{
          "text" => "あれ",
          "image_text" => "あれ？",
          "reading" => "あれ？",
          "meaning" => "huh",
          "word_type" => "expression",
          "verb_group" => nil,
          "notes" => ""
        },
        %{
          "text" => "テスト",
          "image_text" => "テスト",
          "reading" => "てすと 、てすと",
          "meaning" => "test",
          "word_type" => "noun",
          "verb_group" => nil,
          "notes" => ""
        }
      ]

      assert {:ok, lesson} =
               ImageLessonBuilder.build_lesson_from_extracted_words(
                 extracted_words,
                 %{},
                 teacher.id
               )

      [first, second] = Content.list_lesson_words(lesson.id)
      assert first.word.reading == "あれ"
      assert second.word.reading == "てすと/てすと"
    end
  end
end
