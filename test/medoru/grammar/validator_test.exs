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

  describe "validation with prefix text before pattern" do
    setup do
      # Create grammar forms
      {:ok, te_form} =
        Content.create_grammar_form(%{
          name: "te-form",
          display_name: "て形",
          word_type: "verb"
        })

      {:ok, nai_form} =
        Content.create_grammar_form(%{
          name: "nai-form",
          display_name: "ない形",
          word_type: "verb"
        })

      # Create verb (来る - to come)
      kuru =
        ContentFixtures.word_fixture(%{
          text: "来る",
          reading: "くる",
          word_type: :verb
        })

      # Create te-form conjugation (来て - positive)
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: kuru.id,
          grammar_form_id: te_form.id,
          conjugated_form: "来て"
        })

      # Create nai-form conjugation (来ない) with alternative form (来な)
      # The alternative form is used for combining with suffixes like くて, ければ
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: kuru.id,
          grammar_form_id: nai_form.id,
          conjugated_form: "来ない",
          alternative_forms: ["来な"]
        })

      %{te_form: te_form, nai_form: nai_form, kuru: kuru}
    end

    test "validates sentence with nai-form + くて pattern and prefix text", %{nai_form: _nai_form} do
      # Pattern from screenshot: [Verb (nai-form)] + [くてもいいです]
      # The nai-form (来ない) combines with くて to form 来なくて
      pattern = [
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["nai-form"]},
        %{"type" => "literal", "text" => "くてもいいです"}
      ]

      # Sentence with time word before the verb: あした来なくてもいいです。
      # Should match: 来ない (nai-form) + くてもいいです = 来なくてもいいです
      sentence = "あした来なくてもいいです。"

      result = Validator.validate_with_details(sentence, pattern)

      unless result.valid do
        flunk(
          "Expected valid but got error: #{inspect(result)}"
        )
      end

      # Check breakdown has the verb and literal
      assert length(result.breakdown) >= 2

      # Should have skipped text (あした) and the verb
      verb_element = Enum.find(result.breakdown, fn e -> String.contains?(e.text, "来") end)
      assert verb_element != nil, "Expected to find verb '来' in breakdown"
      assert verb_element.form == "nai-form", "Expected nai-form for verb"
    end

    test "validates nai-form + くて pattern without prefix", %{nai_form: _nai_form} do
      # Same pattern but without prefix text
      pattern = [
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["nai-form"]},
        %{"type" => "literal", "text" => "くてもいいです"}
      ]

      sentence = "来なくてもいいです"

      result = Validator.validate_with_details(sentence, pattern)
      
      unless result.valid do
        flunk("Expected valid but got: #{inspect(result)}")
      end

      # Verify the breakdown
      verb_element = Enum.find(result.breakdown, fn e -> e.type == "verb" end)
      assert verb_element != nil
      assert verb_element.form == "nai-form"
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

  describe "unknown noun handling (names)" do
    setup do
      # Create noun: 髪 (hair) - will be in DB
      kami =
        ContentFixtures.word_fixture(%{
          text: "髪",
          reading: "かみ",
          word_type: :noun
        })

      # Create adjective: 長い (long) - will be in DB
      nagai =
        ContentFixtures.word_fixture(%{
          text: "長い",
          reading: "ながい",
          word_type: :adjective
        })

      # Create grammar form for i-adjective dictionary form
      {:ok, dictionary_i} =
        Content.create_grammar_form(%{
          name: "dictionary-i",
          display_name: "辞書形（い形容詞）",
          word_type: "adjective"
        })

      # Create conjugation for 長い in dictionary-i form
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: nagai.id,
          grammar_form_id: dictionary_i.id,
          conjugated_form: "長い",
          reading: "ながい"
        })

      %{
        kami: kami,
        nagai: nagai,
        dictionary_i: dictionary_i
      }
    end

    test "validates sentence with unknown noun (name) at start: NはNがAdj pattern", %{
      dictionary_i: _dictionary_i
    } do
      # Pattern: [Noun][Particle-は][Noun][Particle-が][Adjective in dictionary-i form]
      # Particles use word_slot with word_type: "particle" and forms for allowed particles
      pattern = [
        %{"type" => "word_slot", "word_type" => "noun"},
        %{"type" => "word_slot", "word_type" => "particle", "forms" => ["は"]},
        %{"type" => "word_slot", "word_type" => "noun"},
        %{"type" => "word_slot", "word_type" => "particle", "forms" => ["が"]},
        %{"type" => "word_slot", "word_type" => "adjective", "forms" => ["dictionary-i"]}
      ]

      # Example: マリアさんは髪が長いです。
      # Note: マリアさん is NOT in the DB - should be accepted as unknown name/noun
      sentence = "マリアさんは髪が長いです"

      result = Validator.validate_with_details(sentence, pattern)

      unless result.valid do
        flunk(
          "Expected valid but got error at #{result.error_at}: expected '#{result.expected}' but got '#{result.got}'"
        )
      end

      # Verify breakdown structure
      assert length(result.breakdown) == 5

      # First element should be the unknown noun マリアさん
      first_element = hd(result.breakdown)
      assert first_element.text == "マリアさん"
      assert first_element.type == "noun"
      # Unknown nouns have nil word_id
      assert first_element.word_id == nil

      # Second element should be particle は
      second_element = Enum.at(result.breakdown, 1)
      assert second_element.text == "は"
      assert second_element.type == "particle"

      # Third element should be the known noun 髪
      third_element = Enum.at(result.breakdown, 2)
      assert third_element.text == "髪"
      assert third_element.type == "noun"

      # Fourth element should be particle が
      fourth_element = Enum.at(result.breakdown, 3)
      assert fourth_element.text == "が"
      assert fourth_element.type == "particle"

      # Fifth element should be the adjective 長い
      fifth_element = Enum.at(result.breakdown, 4)
      assert fifth_element.text == "長い"
      assert fifth_element.type == "adjective"
      assert fifth_element.form == "dictionary-i"
    end

    test "validates sentence with unknown noun using other particles (を, に)", %{
      dictionary_i: _dictionary_i
    } do
      # Pattern: [Noun][Particle-を][Verb] - but using adjective slot for simplicity
      pattern = [
        %{"type" => "word_slot", "word_type" => "noun"},
        %{"type" => "word_slot", "word_type" => "particle", "forms" => ["を"]},
        %{"type" => "word_slot", "word_type" => "adjective", "forms" => ["dictionary-i"]}
      ]

      # Example: 田中さんを長い (unnatural but tests particle を)
      # Note: 田中さん is NOT in the DB
      sentence = "田中さんを長い"

      result = Validator.validate_with_details(sentence, pattern)

      unless result.valid do
        flunk(
          "Expected valid but got error at #{result.error_at}: expected '#{result.expected}' but got '#{result.got}'"
        )
      end

      # Verify the unknown noun was recognized
      first_element = hd(result.breakdown)
      assert first_element.text == "田中さん"
      assert first_element.type == "noun"
    end

    test "validates sentence with unknown noun followed by が particle", %{
      dictionary_i: _dictionary_i
    } do
      # Pattern: [Noun][Particle-が][Adjective]
      pattern = [
        %{"type" => "word_slot", "word_type" => "noun"},
        %{"type" => "word_slot", "word_type" => "particle", "forms" => ["が"]},
        %{"type" => "word_slot", "word_type" => "adjective", "forms" => ["dictionary-i"]}
      ]

      # Example: 太郎が長い (unnatural but tests particle が)
      sentence = "太郎が長い"

      result = Validator.validate_with_details(sentence, pattern)

      unless result.valid do
        flunk(
          "Expected valid but got error at #{result.error_at}: expected '#{result.expected}' but got '#{result.got}'"
        )
      end

      # Verify the unknown noun was recognized
      first_element = hd(result.breakdown)
      assert first_element.text == "太郎"
      assert first_element.type == "noun"
    end

    test "returns error when no particle follows unknown text", %{dictionary_i: _dictionary_i} do
      # Pattern that expects a noun but the sentence has no particle after unknown text
      pattern = [
        %{"type" => "word_slot", "word_type" => "noun"},
        %{"type" => "word_slot", "word_type" => "particle", "forms" => ["は"]},
        %{"type" => "word_slot", "word_type" => "adjective", "forms" => ["dictionary-i"]}
      ]

      # Sentence without particle after unknown noun - should fail
      sentence = "マリアさん髪が長いです"

      result = Validator.validate_with_details(sentence, pattern)

      # This should fail because マリアさん is not followed by は
      assert result.valid == false
    end
  end

  describe "literal matching anywhere in sentence" do
    setup do
      # Create a verb for testing patterns with verbs after literals
      iku =
        ContentFixtures.word_fixture(%{
          text: "行く",
          reading: "いく",
          word_type: :verb
        })

      {:ok, masu_form} =
        Content.create_grammar_form(%{
          name: "masu-form",
          display_name: "ます形",
          word_type: "verb"
        })

      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: iku.id,
          grammar_form_id: masu_form.id,
          conjugated_form: "行きます",
          reading: "いきます"
        })

      %{iku: iku, masu_form: masu_form}
    end

    test "validates sentence when literal appears anywhere (not just at start)", %{
      masu_form: _masu_form
    } do
      # Pattern: [TEXT "どうやって"] [VERB in masu-form]
      # The literal "どうやって" should match anywhere in the sentence
      pattern = [
        %{"type" => "literal", "text" => "どうやって"},
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["masu-form"]}
      ]

      # Sentence with prefix before the literal: 大学までどうやって行きますか
      # Should match: "どうやって" (literal) + "行きます" (verb)
      sentence = "大学までどうやって行きますか"

      result = Validator.validate_with_details(sentence, pattern)

      unless result.valid do
        flunk(
          "Expected valid but got error at #{result.error_at}: expected '#{result.expected}' but got '#{result.got}'"
        )
      end

      # Verify breakdown has the literal and verb
      assert length(result.breakdown) >= 2

      # Should have skipped text (大学まで) and the literal (どうやって)
      skipped_element = Enum.find(result.breakdown, fn e -> e.type == "skipped" end)
      assert skipped_element != nil, "Expected to find skipped text in breakdown"
      assert skipped_element.text == "大学まで"

      literal_element = Enum.find(result.breakdown, fn e -> e.text == "どうやって" end)
      assert literal_element != nil, "Expected to find literal 'どうやって' in breakdown"
      assert literal_element.type == "literal"

      verb_element = Enum.find(result.breakdown, fn e -> e.type == "verb" end)
      assert verb_element != nil, "Expected to find verb in breakdown"
      assert verb_element.text == "行きます"
      assert verb_element.form == "masu-form"
    end

    test "validates sentence when literal is at the start (no prefix)", %{
      masu_form: _masu_form
    } do
      # Same pattern but literal is at the start
      pattern = [
        %{"type" => "literal", "text" => "どうやって"},
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["masu-form"]}
      ]

      sentence = "どうやって行きますか"

      result = Validator.validate_with_details(sentence, pattern)

      unless result.valid do
        flunk(
          "Expected valid but got error at #{result.error_at}: expected '#{result.expected}' but got '#{result.got}'"
        )
      end

      # Should not have skipped text
      skipped_element = Enum.find(result.breakdown, fn e -> e.type == "skipped" end)
      assert skipped_element == nil, "Expected no skipped text when literal is at start"

      literal_element = Enum.find(result.breakdown, fn e -> e.text == "どうやって" end)
      assert literal_element != nil
    end

    test "returns error when literal is not found in sentence", %{masu_form: _masu_form} do
      pattern = [
        %{"type" => "literal", "text" => "どうやって"},
        %{"type" => "word_slot", "word_type" => "verb", "forms" => ["masu-form"]}
      ]

      # Sentence without the literal
      sentence = "大学まで行きますか"

      result = Validator.validate_with_details(sentence, pattern)

      assert result.valid == false
      assert result.error_at != nil
    end

    test "validates multiple literals with text between them" do
      # Pattern with two literals: [TEXT "どうやって"] [TEXT "行きますか"]
      pattern = [
        %{"type" => "literal", "text" => "どうやって"},
        %{"type" => "literal", "text" => "行きますか"}
      ]

      # Sentence with text between the two literals
      sentence = "大学までどうやってここから行きますか"

      result = Validator.validate_with_details(sentence, pattern)

      unless result.valid do
        flunk(
          "Expected valid but got error at #{result.error_at}: expected '#{result.expected}' but got '#{result.got}'"
        )
      end

      # Should find both literals
      first_literal = Enum.find(result.breakdown, fn e -> e.text == "どうやって" end)
      assert first_literal != nil

      second_literal = Enum.find(result.breakdown, fn e -> e.text == "行きますか" end)
      assert second_literal != nil
    end
  end
end
