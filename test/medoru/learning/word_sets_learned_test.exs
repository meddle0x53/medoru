defmodule Medoru.Learning.WordSetsLearnedTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.UserProgress
  alias Medoru.Learning.WordSets
  alias Medoru.Repo

  defp track_at(user_id, word_id, seconds_ago) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    time = DateTime.add(now, -seconds_ago, :second)

    %UserProgress{}
    |> UserProgress.changeset(%{user_id: user_id, word_id: word_id})
    |> Repo.insert!()
    |> Ecto.Changeset.change(inserted_at: time, updated_at: time)
    |> Repo.update!()
  end

  setup do
    user = user_fixture()

    words = %{
      old_noun: word_fixture(%{word_type: :noun, difficulty: 5}),
      mid_verb: word_fixture(%{word_type: :verb, difficulty: 4}),
      new_verb: word_fixture(%{word_type: :verb, difficulty: 2}),
      new_adj: word_fixture(%{word_type: :adjective, difficulty: 2})
    }

    track_at(user.id, words.old_noun.id, 300)
    track_at(user.id, words.mid_verb.id, 200)
    track_at(user.id, words.new_verb.id, 100)
    track_at(user.id, words.new_adj.id, 10)

    %{user: user, words: words}
  end

  describe "list_latest_learned_words/4" do
    test "returns learned words most recent first", %{user: user, words: words} do
      result = WordSets.list_latest_learned_words(user.id, 10)

      assert Enum.map(result, & &1.id) == [
               words.new_adj.id,
               words.new_verb.id,
               words.mid_verb.id,
               words.old_noun.id
             ]
    end

    test "filters by word type", %{user: user, words: words} do
      result = WordSets.list_latest_learned_words(user.id, 10, ["verb"])

      assert Enum.map(result, & &1.id) == [words.new_verb.id, words.mid_verb.id]
    end

    test "filters by JLPT level", %{user: user, words: words} do
      result = WordSets.list_latest_learned_words(user.id, 10, [], [2])

      assert Enum.map(result, & &1.id) == [words.new_adj.id, words.new_verb.id]
    end

    test "filters first, then limits", %{user: user, words: words} do
      result = WordSets.list_latest_learned_words(user.id, 1, ["verb"])

      assert Enum.map(result, & &1.id) == [words.new_verb.id]
    end

    test "empty filters return all learned words", %{user: user} do
      assert length(WordSets.list_latest_learned_words(user.id, 100)) == 4
    end
  end

  describe "count_learned_words_matching/3" do
    test "counts all learned words with empty filters", %{user: user} do
      assert WordSets.count_learned_words_matching(user.id) == 4
    end

    test "counts with combined filters", %{user: user} do
      assert WordSets.count_learned_words_matching(user.id, ["verb"], [4]) == 1
      assert WordSets.count_learned_words_matching(user.id, ["verb"], [2]) == 1
      assert WordSets.count_learned_words_matching(user.id, ["noun"], [5]) == 1
    end

    test "ignores invalid filter values", %{user: user} do
      assert WordSets.count_learned_words_matching(user.id, ["bogus"], [9]) == 4
    end
  end

  describe "create_word_set_from_learned_words/2" do
    test "creates a set with the latest N matching words in order", %{
      user: user,
      words: words
    } do
      assert {:ok, set} =
               WordSets.create_word_set_from_learned_words(user, %{
                 n: 2,
                 word_types: ["verb"]
               })

      assert set.word_count == 2
      assert set.name =~ "Learned Words"

      {_set, %{words: set_words}} = WordSets.get_word_set_with_words_paginated(set.id)
      assert Enum.map(set_words, & &1.id) == [words.new_verb.id, words.mid_verb.id]
    end

    test "clamps n to the matching count", %{user: user} do
      assert {:ok, set} = WordSets.create_word_set_from_learned_words(user, %{n: 500})

      assert set.word_count == 4
    end

    test "uses the given name and empty name falls back to default", %{user: user} do
      assert {:ok, set1} =
               WordSets.create_word_set_from_learned_words(user, %{name: "My Set", n: 1})

      assert set1.name == "My Set"

      assert {:ok, set2} =
               WordSets.create_word_set_from_learned_words(user, %{name: "   ", n: 1})

      assert set2.name =~ "Learned Words"
    end

    test "caps the set at 55 words" do
      user = user_fixture()

      for _ <- 1..60 do
        word = word_fixture()
        user_progress_fixture(%{user_id: user.id, word_id: word.id})
      end

      assert {:ok, set} = WordSets.create_word_set_from_learned_words(user, %{n: 100})
      assert set.word_count == 55
    end

    test "returns error when no words match", %{user: user} do
      assert {:error, :no_matching_words} =
               WordSets.create_word_set_from_learned_words(user, %{
                 word_types: ["noun"],
                 levels: [1]
               })
    end
  end
end
