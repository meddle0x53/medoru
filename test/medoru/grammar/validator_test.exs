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

  describe "word_class matching with patterns" do
    setup do
      # Create a word class with both pattern AND word list
      {:ok, time_class} =
        Content.create_word_class(%{
          name: "time",
          display_name: "Time expressions",
          pattern: "[0-9０-９一二三四五六七八九十]+(時|分|秒)",
          examples: []
        })

      # Add a word to the class (for testing word list fallback)
      kyou = ContentFixtures.word_fixture(%{text: "今日", reading: "きょう", word_type: :noun})
      Content.add_word_to_class(kyou.id, time_class.id)

      %{time_class: time_class, kyou: kyou}
    end

    test "matches pattern-based time expressions (数字+時)", %{time_class: time_class} do
      pattern = [
        %{"type" => "word_class", "word_class_id" => time_class.id}
      ]

      # Should match arabic numerals
      assert {:ok, breakdown} = Validator.validate_sentence("5時", pattern)
      assert hd(breakdown).text == "5時"

      # Should match kanji numerals
      assert {:ok, breakdown} = Validator.validate_sentence("四時", pattern)
      assert hd(breakdown).text == "四時"

      # Should match 分 (minutes)
      assert {:ok, breakdown} = Validator.validate_sentence("10分", pattern)
      assert hd(breakdown).text == "10分"
    end

    test "falls back to word list when pattern doesn't match", %{
      time_class: time_class,
      kyou: kyou
    } do
      pattern = [
        %{"type" => "word_class", "word_class_id" => time_class.id}
      ]

      # "今日" is in the word list but doesn't match the pattern [0-9]+時
      assert {:ok, breakdown} = Validator.validate_sentence("今日", pattern)
      assert hd(breakdown).text == "今日"
      assert hd(breakdown).word_id == kyou.id
    end

    test "pattern takes priority when both could match (longest match)", %{
      time_class: time_class
    } do
      pattern = [
        %{"type" => "word_class", "word_class_id" => time_class.id}
      ]

      # Should still match the pattern
      assert {:ok, breakdown} = Validator.validate_sentence("12時", pattern)
      assert hd(breakdown).text == "12時"
    end

    test "returns error when neither pattern nor word list matches", %{
      time_class: time_class
    } do
      pattern = [
        %{"type" => "word_class", "word_class_id" => time_class.id}
      ]

      assert {:error, _} = Validator.validate_sentence("食べる", pattern)
    end

    test "matches pattern anywhere in sentence", %{time_class: time_class} do
      pattern = [
        %{"type" => "literal", "text" => "毎日"},
        %{"type" => "word_class", "word_class_id" => time_class.id}
      ]

      assert {:ok, breakdown} = Validator.validate_sentence("毎日5時", pattern)
      assert length(breakdown) == 2
      assert Enum.at(breakdown, 1).text == "5時"
    end
  end

  describe "word_class with only word list (no pattern)" do
    setup do
      # Create a word class with only word list (no pattern)
      {:ok, place_class} =
        Content.create_word_class(%{
          name: "place",
          display_name: "Places",
          pattern: nil,
          examples: []
        })

      tokyo = ContentFixtures.word_fixture(%{text: "東京", reading: "とうきょう", word_type: :noun})
      osaka = ContentFixtures.word_fixture(%{text: "大阪", reading: "おおさか", word_type: :noun})
      Content.add_word_to_class(tokyo.id, place_class.id)
      Content.add_word_to_class(osaka.id, place_class.id)

      %{place_class: place_class, tokyo: tokyo, osaka: osaka}
    end

    test "matches words from the word list", %{place_class: place_class} do
      pattern = [
        %{"type" => "word_class", "word_class_id" => place_class.id}
      ]

      assert {:ok, breakdown} = Validator.validate_sentence("東京", pattern)
      assert hd(breakdown).text == "東京"

      assert {:ok, breakdown} = Validator.validate_sentence("大阪", pattern)
      assert hd(breakdown).text == "大阪"
    end

    test "returns error for words not in the list", %{place_class: place_class} do
      pattern = [
        %{"type" => "word_class", "word_class_id" => place_class.id}
      ]

      assert {:error, _} = Validator.validate_sentence("京都", pattern)
    end
  end

  describe "complex patterns with optional slots and word classes" do
    setup do
      # Create a time word class with pattern and words
      {:ok, time_class} =
        Content.create_word_class(%{
          name: "time_expressions",
          display_name: "Time",
          pattern: "[0-9０-９一二三四五六七八九十]+(時|分|秒|日|月|年)",
          examples: []
        })

      # Add 土曜日 to the time class (as a time word, not a noun)
      doyoubi =
        ContentFixtures.word_fixture(%{
          text: "土曜日",
          reading: "どようび",
          # Note: word_type is :expression (not :noun) so optional NOUN slot won't match it
          word_type: :expression
        })

      Content.add_word_to_class(doyoubi.id, time_class.id)

      # Create a verb (返す - to return)
      {:ok, dictionary} =
        Content.create_grammar_form(%{
          name: "dictionary",
          display_name: "辞書形",
          word_type: "verb"
        })

      {:ok, nai_form} =
        Content.create_grammar_form(%{
          name: "nai-form",
          display_name: "ない形",
          word_type: "verb"
        })

      kaesu =
        ContentFixtures.word_fixture(%{
          text: "返す",
          reading: "かえす",
          word_type: :verb
        })

      # Create dictionary form conjugation
      Content.create_word_conjugation(%{
        word_id: kaesu.id,
        grammar_form_id: dictionary.id,
        conjugated_form: "返す"
      })

      # Create nai-form conjugation (返さない -> 返さ for contraction)
      Content.create_word_conjugation(%{
        word_id: kaesu.id,
        grammar_form_id: nai_form.id,
        conjugated_form: "返さない",
        reading: "かえさない"
      })

      # Create noun (本 - book)
      hon =
        ContentFixtures.word_fixture(%{
          text: "本",
          reading: "ほん",
          word_type: :noun
        })

      %{
        time_class: time_class,
        doyoubi: doyoubi,
        kaesu: kaesu,
        hon: hon,
        nai_form: nai_form
      }
    end

    test "matches pattern with optional noun, time class, literal, and verb", %{
      time_class: time_class
    } do
      # Pattern: [NOUN (optional)] [CLASS Time] [TEXT "までに"] [VERB in nai-form]
      pattern = [
        %{"type" => "word_slot", "word_type" => "noun", "optional" => true},
        %{"type" => "word_class", "word_class_id" => time_class.id},
        %{"type" => "literal", "text" => "までに"},
        %{"type" => "word_slot", "word_type" => "verb"}
      ]

      # Sentence: 土曜日までに本を返さなければなりません
      # Should match: [土曜日 (time)] [までに (literal)] [返さ (nai-form verb)]
      # The 本を should be handled by the object marker logic
      sentence = "土曜日までに本を返さなければなりません"

      result = Validator.validate_with_details(sentence, pattern)

      unless result.valid do
        flunk(
          "Expected valid but got error at #{result.error_at}: expected '#{result.expected}' but got '#{result.got}'"
        )
      end

      # Check breakdown structure
      assert length(result.breakdown) >= 3

      # First should be 土曜日 (time class)
      time_element = Enum.find(result.breakdown, fn e -> e.text == "土曜日" end)
      assert time_element != nil

      # Should have までに as literal
      made_element = Enum.find(result.breakdown, fn e -> e.text == "までに" end)
      assert made_element != nil

      # Should have the verb 返さ
      verb_element = Enum.find(result.breakdown, fn e -> String.contains?(e.text, "返さ") end)
      assert verb_element != nil
    end

    test "matches pattern with time class starting immediately (no optional noun)", %{
      time_class: time_class
    } do
      # Pattern: [CLASS Time] [TEXT "までに"] [VERB]
      pattern = [
        %{"type" => "word_class", "word_class_id" => time_class.id},
        %{"type" => "literal", "text" => "までに"},
        %{"type" => "word_slot", "word_type" => "verb", "form" => "nai-form"}
      ]

      # Sentence without leading noun: 土曜日までに...
      sentence = "土曜日までに本を返さなければなりません"

      result = Validator.validate_with_details(sentence, pattern)

      unless result.valid do
        flunk(
          "Expected valid but got error at #{result.error_at}: expected '#{result.expected}' but got '#{result.got}'"
        )
      end
    end
  end
end
