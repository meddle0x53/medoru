defmodule Medoru.Grammar.ValidatorTimeoutTest do
  @moduledoc """
  Tests for complex patterns that may cause timeout issues.
  
  Pattern: [Verb-て-form][Expression-optional][Verb-て-form-optional][Expression-optional][Verb]
  
  This pattern tests the scenario where:
  1. We have multiple optional word slots
  2. Each slot can match at various positions in the sentence
  3. The combination of optional elements + anywhere-matching can cause
     exponential backtracking behavior
  """
  
  use Medoru.DataCase
  
  alias Medoru.Grammar.Validator
  alias Medoru.ContentFixtures
  alias Medoru.Content
  
  # Set a short timeout to catch hanging tests quickly
  @tag timeout: 5000
  describe "complex pattern with multiple optional elements - timeout test" do
    setup do
      # Create grammar forms
      {:ok, te_form} =
        Content.create_grammar_form(%{
          name: "te-form",
          display_name: "て形",
          word_type: "verb"
        })
      
      {:ok, masu_form} =
        Content.create_grammar_form(%{
          name: "masu-form",
          display_name: "ます形",
          word_type: "verb"
        })
      
      {:ok, dictionary_form} =
        Content.create_grammar_form(%{
          name: "dictionary",
          display_name: "辞書形",
          word_type: "verb"
        })
      
      # === Verb 1: 行く (iku) - to go ===
      iku = ContentFixtures.word_fixture(%{
        text: "行く",
        reading: "いく",
        word_type: :verb
      })
      
      # 行く te-form: 行って
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: iku.id,
          grammar_form_id: te_form.id,
          conjugated_form: "行って",
          reading: "いって"
        })
      
      # 行く dictionary form
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: iku.id,
          grammar_form_id: dictionary_form.id,
          conjugated_form: "行く",
          reading: "いく"
        })
      
      # === Verb 2: 見る (miru) - to see/watch ===
      miru = ContentFixtures.word_fixture(%{
        text: "見る",
        reading: "みる",
        word_type: :verb
      })
      
      # 見る te-form: 見て
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: miru.id,
          grammar_form_id: te_form.id,
          conjugated_form: "見て",
          reading: "みて"
        })
      
      # 見る dictionary form
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: miru.id,
          grammar_form_id: dictionary_form.id,
          conjugated_form: "見る",
          reading: "みる"
        })
      
      # === Verb 3: 飲む (nomu) - to drink ===
      nomu = ContentFixtures.word_fixture(%{
        text: "飲む",
        reading: "のむ",
        word_type: :verb
      })
      
      # 飲む masu-form past: 飲みました
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: nomu.id,
          grammar_form_id: masu_form.id,
          conjugated_form: "飲みました",
          reading: "のみました"
        })
      
      # 飲む te-form: 飲んで (not used in this sentence but good to have)
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: nomu.id,
          grammar_form_id: te_form.id,
          conjugated_form: "飲んで",
          reading: "のんで"
        })
      
      # 飲む dictionary form
      {:ok, _} =
        Content.create_word_conjugation(%{
          word_id: nomu.id,
          grammar_form_id: dictionary_form.id,
          conjugated_form: "飲む",
          reading: "のむ"
        })
      
      # === Nouns ===
      # 神戸 (Kobe)
      kobe = ContentFixtures.word_fixture(%{
        text: "神戸",
        reading: "こうべ",
        word_type: :noun
      })
      
      # 映画 (movie)
      eiga = ContentFixtures.word_fixture(%{
        text: "映画",
        reading: "えいが",
        word_type: :noun
      })
      
      # お茶 (tea)
      ocha = ContentFixtures.word_fixture(%{
        text: "お茶",
        reading: "おちゃ",
        word_type: :noun
      })
      
      %{
        te_form: te_form,
        masu_form: masu_form,
        dictionary_form: dictionary_form,
        iku: iku,
        miru: miru,
        nomu: nomu,
        kobe: kobe,
        eiga: eiga,
        ocha: ocha
      }
    end
    
    test "validates complex sentence with multiple optional elements - SHOULD TIMEOUT", %{te_form: te_form} do
      # Pattern: [Verb-て-form][Expression-optional][Verb-て-form-optional][Expression-optional][Verb]
      # The last verb can be in any form (empty forms list)
      # 
      # This pattern is problematic because:
      # 1. "Expression" word_type is very broad (matches many things)
      # 2. Optional elements cause combinatorial explosion
      # 3. find_matching_word_anywhere searches at EACH position
      #
      # For a sentence like "神戸へ行って、映画を見て、お茶を飲みました。":
      # - First te-form verb could match at multiple positions
      # - Optional expression can match almost anywhere
      # - Second optional te-form verb also has many positions
      # - The combinations explode exponentially
      
      pattern = [
        # First: Verb in te-form (required)
        %{
          "type" => "word_slot",
          "word_type" => "verb",
          "forms" => ["te-form"]
        },
        # Second: Expression (optional)
        %{
          "type" => "word_slot",
          "word_type" => "expression",
          "optional" => true
        },
        # Third: Verb in te-form (optional)
        %{
          "type" => "word_slot",
          "word_type" => "verb",
          "forms" => ["te-form"],
          "optional" => true
        },
        # Fourth: Expression (optional)
        %{
          "type" => "word_slot",
          "word_type" => "expression",
          "optional" => true
        },
        # Fifth: Verb in any form (required)
        %{
          "type" => "word_slot",
          "word_type" => "verb",
          "forms" => []  # Any form
        }
      ]
      
      # Sentence: "Went to Kobe, watched a movie, drank tea."
      # Breakdown:
      # - 神戸へ (to Kobe) - prefix before pattern
      # - 行って (itte) - te-form of 行く - matches first slot
      # - 、映画を (, eiga o) - expression - matches second slot (optional)
      # - 見て (mite) - te-form of 見る - matches third slot (optional)
      # - 、お茶を (, ocha o) - expression - matches fourth slot (optional)
      # - 飲みました (nomimashita) - masu-form past of 飲む - matches fifth slot
      sentence = "神戸へ行って、映画を見て、お茶を飲みました。"
      
      # This call should timeout due to exponential backtracking
      # in find_matching_word_anywhere when combined with optional elements
      result = Validator.validate_with_details(sentence, pattern)
      
      # If we get here without timeout, the test should verify the result
      # But we expect this to timeout first
      assert result.valid == true,
        "Expected valid match but got: #{inspect(result)}"
      
      # Verify breakdown has all expected elements
      assert length(result.breakdown) >= 3, 
        "Expected at least 3 matched elements (2 te-verbs + 1 final verb)"
    end
    
    test "simpler pattern without optional elements should work" do
      # Same sentence but simpler pattern without optional elements
      # This should work fine and serve as a control test
      
      pattern = [
        %{
          "type" => "word_slot",
          "word_type" => "verb",
          "forms" => ["te-form"]
        },
        %{
          "type" => "word_slot",
          "word_type" => "verb",
          "forms" => ["te-form"]
        },
        %{
          "type" => "word_slot",
          "word_type" => "verb",
          "forms" => ["masu-form"]
        }
      ]
      
      sentence = "神戸へ行って、映画を見て、お茶を飲みました。"
      
      result = Validator.validate_with_details(sentence, pattern)
      
      assert result.valid == true,
        "Expected valid match but got: #{inspect(result)}"
    end
  end
end
