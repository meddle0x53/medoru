defmodule Medoru.Grammar.FormDetectorTest do
  use Medoru.DataCase

  alias Medoru.Grammar.FormDetector
  alias Medoru.ContentFixtures
  alias Medoru.Content

  describe "detect_form/1" do
    setup do
      word = ContentFixtures.word_fixture(%{text: "食べる", reading: "たべる", word_type: :verb})

      te_form =
        ContentFixtures.grammar_form_fixture(%{
          name: "te-form",
          display_name: "Te Form",
          word_type: "verb"
        })

      nai_form =
        ContentFixtures.grammar_form_fixture(%{
          name: "nai-form",
          display_name: "Nai Form",
          word_type: "verb"
        })

      masu_form =
        ContentFixtures.grammar_form_fixture(%{
          name: "masu-form",
          display_name: "Masu Form",
          word_type: "verb"
        })

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: word.id,
          grammar_form_id: te_form.id,
          conjugated_form: "食べて",
          reading: "たべて"
        })

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: word.id,
          grammar_form_id: nai_form.id,
          conjugated_form: "食べない",
          reading: "たべない"
        })

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: word.id,
          grammar_form_id: masu_form.id,
          conjugated_form: "食べます",
          reading: "たべます"
        })

      %{word: word, te_form: te_form, nai_form: nai_form, masu_form: masu_form}
    end

    test "detects te-form", %{te_form: te_form} do
      assert FormDetector.detect_form("食べて") == [te_form.name]
    end

    test "detects nai-form", %{nai_form: nai_form} do
      assert FormDetector.detect_form("食べない") == [nai_form.name]
    end

    test "detects masu-form", %{masu_form: masu_form} do
      assert FormDetector.detect_form("食べます") == [masu_form.name]
    end

    test "returns empty list for unknown form" do
      assert FormDetector.detect_form("unknown") == []
    end

    test "returns empty list for non-string input" do
      assert FormDetector.detect_form(nil) == []
      assert FormDetector.detect_form(123) == []
    end
  end

  describe "get_dictionary_form/1" do
    setup do
      word = ContentFixtures.word_fixture(%{text: "食べる", reading: "たべる", word_type: :verb})
      te_form = ContentFixtures.grammar_form_fixture(%{name: "te-form", word_type: "verb"})

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: word.id,
          grammar_form_id: te_form.id,
          conjugated_form: "食べて",
          reading: "たべて"
        })

      %{word: word}
    end

    test "returns dictionary form for conjugated word", %{word: word} do
      result = FormDetector.get_dictionary_form("食べて")
      assert result.text == word.text
      assert result.word_type == :verb
      assert result.word_id == word.id
    end

    test "returns nil for unknown form" do
      assert FormDetector.get_dictionary_form("unknown") == nil
    end
  end

  describe "matches_form?/2" do
    setup do
      word = ContentFixtures.word_fixture(%{text: "食べる", word_type: :verb})
      te_form = ContentFixtures.grammar_form_fixture(%{name: "te-form", word_type: "verb"})
      nai_form = ContentFixtures.grammar_form_fixture(%{name: "nai-form", word_type: "verb"})

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: word.id,
          grammar_form_id: te_form.id,
          conjugated_form: "食べて"
        })

      %{te_form: te_form, nai_form: nai_form}
    end

    test "returns true when form matches", %{te_form: te_form} do
      assert FormDetector.matches_form?("食べて", te_form.name) == true
    end

    test "returns false when form doesn't match", %{nai_form: nai_form} do
      assert FormDetector.matches_form?("食べて", nai_form.name) == false
    end
  end

  describe "matches_any_form?/2" do
    setup do
      word = ContentFixtures.word_fixture(%{text: "食べる", word_type: :verb})
      te_form = ContentFixtures.grammar_form_fixture(%{name: "te-form", word_type: "verb"})
      nai_form = ContentFixtures.grammar_form_fixture(%{name: "nai-form", word_type: "verb"})

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: word.id,
          grammar_form_id: te_form.id,
          conjugated_form: "食べて"
        })

      %{te_form: te_form, nai_form: nai_form}
    end

    test "returns true when any form matches", %{te_form: te_form, nai_form: nai_form} do
      assert FormDetector.matches_any_form?("食べて", [te_form.name, nai_form.name]) == true
    end

    test "returns false when no forms match", %{nai_form: nai_form} do
      assert FormDetector.matches_any_form?("食べて", [nai_form.name]) == false
    end
  end

  describe "list_conjugations/1" do
    setup do
      word = ContentFixtures.word_fixture(%{text: "食べる", word_type: :verb})

      te_form =
        ContentFixtures.grammar_form_fixture(%{
          name: "te-form",
          word_type: "verb",
          display_name: "Te Form"
        })

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: word.id,
          grammar_form_id: te_form.id,
          conjugated_form: "食べて",
          reading: "たべて"
        })

      %{word: word, te_form: te_form}
    end

    test "returns all conjugations for a word", %{word: word, te_form: te_form} do
      conjugations = FormDetector.list_conjugations(word.text)
      assert length(conjugations) == 1
      assert hd(conjugations).form == te_form.name
      assert hd(conjugations).text == "食べて"
    end

    test "returns empty list for unknown word" do
      assert FormDetector.list_conjugations("unknown") == []
    end
  end
end
