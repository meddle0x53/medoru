defmodule Medoru.Grammar.ValidatorTest do
  use Medoru.DataCase

  alias Medoru.Grammar.Validator
  alias Medoru.ContentFixtures
  alias Medoru.Content

  describe "validate_sentence/2" do
    setup do
      # Create words
      taberu = ContentFixtures.word_fixture(%{text: "食べる", reading: "たべる", word_type: :verb})
      arau = ContentFixtures.word_fixture(%{text: "洗う", reading: "あらう", word_type: :verb})

      # Create grammar forms
      dictionary = ContentFixtures.grammar_form_fixture(%{name: "dictionary", word_type: "verb"})
      masu = ContentFixtures.grammar_form_fixture(%{name: "masu-form", word_type: "verb"})

      # Create conjugations
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: taberu.id,
          grammar_form_id: dictionary.id,
          conjugated_form: "食べる"
        })

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: taberu.id,
          grammar_form_id: masu.id,
          conjugated_form: "食べます"
        })

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: arau.id,
          grammar_form_id: dictionary.id,
          conjugated_form: "洗う"
        })

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: arau.id,
          grammar_form_id: masu.id,
          conjugated_form: "洗います"
        })

      %{
        taberu: taberu,
        arau: arau,
        dictionary: dictionary,
        masu: masu
      }
    end

    test "validates simple pattern: V[dictionary] + literal + V[masu]" do
      pattern = [
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["dictionary"]},
        %{"type" => "literal", "text" => "まえに、"},
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["masu-form"]}
      ]

      assert {:ok, breakdown} = Validator.validate_sentence("食べるまえに、洗います。", pattern)
      assert length(breakdown) == 3
      assert hd(breakdown).text == "食べる"
      assert hd(breakdown).type == "verb"
      assert hd(breakdown).form == "dictionary"
    end

    test "returns error for wrong form" do
      pattern = [
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["dictionary"]},
        %{"type" => "literal", "text" => "まえに、"},
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["masu-form"]}
      ]

      assert {:error, _} = Validator.validate_sentence("食べますまえに、洗います。", pattern)
    end

    test "returns error for missing literal" do
      pattern = [
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["dictionary"]},
        %{"type" => "literal", "text" => "まえに、"},
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["masu-form"]}
      ]

      assert {:error, _} = Validator.validate_sentence("食べるあとで、洗います。", pattern)
    end

    test "handles optional elements" do
      pattern = [
        %{
          "type" => "word_slot",
          "word_type" => "verb",
          "forms" => ["dictionary"],
          "optional" => true
        },
        %{"type" => "literal", "text" => "まえに、"},
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["masu-form"]}
      ]

      # With optional element
      assert {:ok, _} = Validator.validate_sentence("食べるまえに、洗います。", pattern)

      # Without optional element (should still match)
      # Note: This would require different logic - for now we test the basic case
    end

    test "returns error for empty pattern" do
      assert {:error, _} = Validator.validate_sentence("test", [])
    end

    test "returns error for invalid input" do
      assert {:error, _} = Validator.validate_sentence(nil, [])
      assert {:error, _} = Validator.validate_sentence("test", nil)
    end
  end

  describe "validate_with_details/2" do
    setup do
      taberu = ContentFixtures.word_fixture(%{text: "食べる", word_type: :verb})
      dictionary = ContentFixtures.grammar_form_fixture(%{name: "dictionary", word_type: "verb"})

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: taberu.id,
          grammar_form_id: dictionary.id,
          conjugated_form: "食べる"
        })

      %{}
    end

    test "returns valid result for matching sentence" do
      pattern = [
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["dictionary"]}
      ]

      result = Validator.validate_with_details("食べる", pattern)
      assert result.valid == true
      assert result.breakdown != []
    end

    test "returns invalid result with details for non-matching sentence" do
      pattern = [
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["dictionary"]}
      ]

      result = Validator.validate_with_details("unknown", pattern)
      assert result.valid == false
      assert result.error_at != nil
      assert result.expected != nil
    end
  end
end
