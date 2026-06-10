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

    test "upgrades previously created kana word to kanji version when available", %{teacher: teacher} do
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

    test "stores image form and notes as custom_meaning", %{teacher: teacher} do
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
      assert lesson_word.custom_meaning == "消します (Group I verb)"
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
               ImageLessonBuilder.build_lesson_from_extracted_words(extracted_words, %{}, teacher.id)

      assert lesson.title == "Vocabulary lesson from image — change the name"
    end
  end
end
