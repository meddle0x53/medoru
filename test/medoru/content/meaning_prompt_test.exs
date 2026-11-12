defmodule Medoru.Content.MeaningPromptTest do
  use Medoru.DataCase, async: true

  alias Medoru.Content
  import Medoru.ContentFixtures

  setup do
    word =
      word_fixture(%{
        meaning: "to eat/to consume",
        translations: %{"bg" => %{"meaning" => "ям/консумирам"}}
      })

    %{word: word}
  end

  describe "localized_meaning_prompt/3" do
    test "returns localized segment at the given index", %{word: word} do
      assert Content.localized_meaning_prompt(word.id, "bg", [1]) == "консумирам"
    end

    test "joins multiple indices with ' / '", %{word: word} do
      assert Content.localized_meaning_prompt(word.id, "bg", [0, 1]) ==
               "ям / консумирам"
    end

    test "out-of-range indices fall back to the full localized string", %{word: word} do
      assert Content.localized_meaning_prompt(word.id, "bg", [5]) == "ям/консумирам"
    end

    test "nil or empty indices return the full localized string", %{word: word} do
      assert Content.localized_meaning_prompt(word.id, "bg", nil) == "ям/консумирам"
      assert Content.localized_meaning_prompt(word.id, "bg", []) == "ям/консумирам"
    end

    test "non-translated locale falls back to base meaning segments", %{word: word} do
      assert Content.localized_meaning_prompt(word.id, "en", [0]) == "to eat"
      assert Content.localized_meaning_prompt(word.id, "en", [0, 1]) == "to eat / to consume"
    end

    test "returns nil for a missing word" do
      assert Content.localized_meaning_prompt(Ecto.UUID.generate(), "bg", [0]) == nil
    end
  end
end
