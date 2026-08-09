defmodule Medoru.Maintenance.ConjugationsTest do
  use Medoru.DataCase, async: false

  alias Medoru.ContentFixtures
  alias Medoru.Grammar.FormDetector
  alias Medoru.Maintenance.Conjugations

  defp conjugation_map(word_text) do
    word_text
    |> FormDetector.list_conjugations()
    |> Map.new(&{&1.form, &1})
  end

  describe "generate_for_type(:verb)" do
    test "compound suru-verbs conjugate with the する paradigm" do
      ContentFixtures.word_fixture(%{
        text: "勉強する",
        reading: "べんきょうする",
        word_type: :verb
      })

      Conjugations.seed_grammar_forms()
      Conjugations.generate_for_type(:verb)

      conjs = conjugation_map("勉強する")

      # Regression: compounds used to be classified as godan, producing
      # 勉強すります / 勉強すった / 勉強すって etc.
      assert conjs["dictionary"].text == "勉強する"
      assert conjs["masu-form"].text == "勉強します"
      assert conjs["te-form"].text == "勉強して"
      assert conjs["ta-form"].text == "勉強した"
      assert conjs["nai-form"].text == "勉強しない"
      assert conjs["potential"].text == "勉強できる"
      assert conjs["passive"].text == "勉強される"
      assert conjs["conditional"].text == "勉強すれば"

      # Readings follow the same paradigm
      assert conjs["masu-form"].reading == "べんきょうします"
    end

    test "all verb kinds get the polite past/negative forms" do
      ContentFixtures.word_fixture(%{text: "勉強する", reading: "べんきょうする", word_type: :verb})
      ContentFixtures.word_fixture(%{text: "食べる", reading: "たべる", word_type: :verb})
      ContentFixtures.word_fixture(%{text: "書く", reading: "かく", word_type: :verb})
      ContentFixtures.word_fixture(%{text: "来る", reading: "くる", word_type: :verb})

      Conjugations.seed_grammar_forms()
      Conjugations.generate_for_type(:verb)

      for {word, past, negative, negative_past} <- [
            {"勉強する", "勉強しました", "勉強しません", "勉強しませんでした"},
            {"食べる", "食べました", "食べません", "食べませんでした"},
            {"書く", "書きました", "書きません", "書きませんでした"},
            {"来る", "来ました", "来ません", "来ませんでした"}
          ] do
        conjs = conjugation_map(word)

        assert conjs["masu-past"].text == past
        assert conjs["masu-negative"].text == negative
        assert conjs["masu-negative-past"].text == negative_past
      end
    end
  end
end
