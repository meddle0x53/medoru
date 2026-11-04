defmodule Medoru.Grammar.ReadingConverterTest do
  use Medoru.DataCase, async: true

  import Medoru.ContentFixtures

  alias Medoru.Grammar.ReadingConverter

  describe "to_kana/1" do
    test "passes hiragana through" do
      assert ReadingConverter.to_kana("これはぺんです") == "これはぺんです"
    end

    test "passes katakana through" do
      assert ReadingConverter.to_kana("テレビ") == "テレビ"
    end

    test "uses the word reading for known words" do
      word_fixture(%{text: "料理", reading: "りょうり", word_type: :noun})

      assert ReadingConverter.to_kana("料理") == "りょうり"
      assert ReadingConverter.normalize_for_comparison("料理ができますか。") == "りょうりができますか"
    end

    test "on'yomi compounds use the word reading, not per-kanji kun guesses" do
      word_fixture(%{text: "空港", reading: "くうこう", word_type: :noun})
      word_fixture(%{text: "行く", reading: "いく", word_type: :verb})
      word_fixture(%{text: "ホテル", reading: "ほてる", word_type: :noun})

      student = "ホテルからバスで空港へ行くことができますか。"

      assert ReadingConverter.normalize_for_comparison(student) ==
               ReadingConverter.normalize_for_comparison("ホテルからバスでくうこうへいくことができますか")
    end

    test "drops punctuation" do
      assert ReadingConverter.to_kana("これは、ペンです。") == "これはペンです"
    end

    test "falls back to per-kanji kun readings for unknown words" do
      kanji_with_readings_fixture(
        %{character: "鮗"},
        [
          %{reading_type: :on, reading: "テスト", romaji: "tesuto", position: 0},
          %{reading_type: :kun, reading: "てすと", romaji: "tesuto", position: 1}
        ]
      )

      assert ReadingConverter.to_kana("鮗") == "てすと"
    end

    test "falls back to on reading when no kun reading exists" do
      kanji_with_readings_fixture(
        %{character: "鮘"},
        [%{reading_type: :on, reading: "テスト", romaji: "tesuto", position: 0}]
      )

      assert ReadingConverter.to_kana("鮘") == "テスト"
    end

    test "keeps kanji without any reading as-is" do
      kanji_fixture(%{character: "鮙"})

      assert ReadingConverter.to_kana("鮙") == "鮙"
    end
  end

  describe "normalize_for_comparison/1" do
    test "strips Japanese and ASCII punctuation and whitespace" do
      assert ReadingConverter.normalize_for_comparison("あ、い う。え!お?か,き.く・け") ==
               "あいうえおかきくけ"
    end

    test "unifies katakana and hiragana so both scripts compare equal" do
      assert ReadingConverter.normalize_for_comparison("ホテル") ==
               ReadingConverter.normalize_for_comparison("ほてる")

      assert ReadingConverter.normalize_for_comparison("インターネットでホテルのよやくができますか") ==
               ReadingConverter.normalize_for_comparison("インターネットでほてるのよやくができますか。")
    end
  end
end
