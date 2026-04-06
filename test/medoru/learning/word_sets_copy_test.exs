defmodule Medoru.Learning.WordSetsCopyTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.WordSets

  describe "search_word_sets_for_copy/3" do
    setup do
      user = user_fixture()

      # Create word sets for searching
      set1 = word_set_fixture(%{user_id: user.id, name: "Japanese Basics"})
      set2 = word_set_fixture(%{user_id: user.id, name: "Japanese Advanced"})
      set3 = word_set_fixture(%{user_id: user.id, name: "Numbers"})
      set4 = word_set_fixture(%{user_id: user.id, name: "Colors"})

      %{user: user, sets: [set1, set2, set3, set4]}
    end

    test "returns exact matches first", %{user: user, sets: [_set1, set2, _set3, _set4]} do
      # Searching "Japanese" should return both Japanese sets, exact match first
      results = WordSets.search_word_sets_for_copy(user.id, set2.id, "Japanese")

      assert length(results) == 1
      assert hd(results).name == "Japanese Basics"
    end

    test "excludes the specified word set", %{user: user, sets: [set1, _set2, _set3, _set4]} do
      results = WordSets.search_word_sets_for_copy(user.id, set1.id, "Japanese")

      # Should not include set1 (the excluded one)
      refute Enum.any?(results, &(&1.id == set1.id))
    end

    test "returns partial matches when no exact matches", %{user: user, sets: sets} do
      [set1 | _] = sets
      results = WordSets.search_word_sets_for_copy(user.id, set1.id, "Num")

      assert length(results) == 1
      assert hd(results).name == "Numbers"
    end

    test "returns max 5 results", %{user: user, sets: [set1 | _]} do
      # Create more word sets to test limit
      for i <- 1..6 do
        word_set_fixture(%{user_id: user.id, name: "Test Set #{i}"})
      end

      results = WordSets.search_word_sets_for_copy(user.id, set1.id, "Test")
      assert length(results) == 5
    end

    test "only returns user's own word sets", %{user: user, sets: [set1 | _]} do
      other_user = user_fixture(%{email: "other@example.com"})
      word_set_fixture(%{user_id: other_user.id, name: "Other User Set"})

      results = WordSets.search_word_sets_for_copy(user.id, set1.id, "Other")
      assert results == []
    end
  end

  describe "copy_words_to_word_set/2" do
    setup do
      user = user_fixture()

      # Create source word set with words
      source = word_set_fixture(%{user_id: user.id, name: "Source Set"})
      word1 = word_fixture(%{text: "日本", meaning: "Japan"})
      word2 = word_fixture(%{text: "一", meaning: "one"})
      word3 = word_fixture(%{text: "二", meaning: "two"})

      WordSets.add_word_to_set(source, word1.id)
      WordSets.add_word_to_set(source, word2.id)
      WordSets.add_word_to_set(source, word3.id)

      # Create target word set
      target = word_set_fixture(%{user_id: user.id, name: "Target Set"})

      %{user: user, source: source, target: target, words: [word1, word2, word3]}
    end

    test "copies all words from source to target", %{source: source, target: target} do
      assert target.word_count == 0

      {:ok, updated_target} = WordSets.copy_words_to_word_set(source.id, target.id)

      assert updated_target.word_count == 3

      # Verify words are in target
      target_word_ids = get_word_set_word_ids(target.id)
      assert length(target_word_ids) == 3
    end

    test "skips duplicate words (already in target)", %{
      source: source,
      target: target,
      words: [word1 | _]
    } do
      # Add one word to target first
      WordSets.add_word_to_set(target, word1.id)
      target = WordSets.get_word_set!(target.id)
      assert target.word_count == 1

      # Copy from source (which also has word1)
      {:ok, updated_target} = WordSets.copy_words_to_word_set(source.id, target.id)

      # Should only add 2 new words (word2 and word3)
      assert updated_target.word_count == 3
    end

    test "returns error when would exceed max words", %{
      user: _user,
      source: source,
      target: target,
      words: words
    } do
      # Target already has 0 words, source has 3
      # Create 98 words in target to reach the limit (use reduce to maintain updated state)
      target =
        Enum.reduce(1..98, target, fn _, acc ->
          word = word_fixture()
          {:ok, updated} = WordSets.add_word_to_set(acc, word.id)
          updated
        end)

      # Verify we have 98 words in target
      assert target.word_count == 98

      # Try to copy 3 more words (would be 101 total)
      assert {:error, :would_overflow} = WordSets.copy_words_to_word_set(source.id, target.id)

      # Verify no words were added (still 98)
      target = WordSets.get_word_set!(target.id)
      assert target.word_count == 98

      # Verify source words are not in target
      target_word_ids = get_word_set_word_ids(target.id)

      for word <- words do
        refute word.id in target_word_ids
      end
    end

    test "allows copy when duplicates keep total under limit", %{
      source: source,
      target: target,
      words: [word1, word2, _word3]
    } do
      # Add 2 words that are also in source (duplicates)
      {:ok, target} = WordSets.add_word_to_set(target, word1.id)
      {:ok, target} = WordSets.add_word_to_set(target, word2.id)

      # Add 93 more unique words to target (use reduce to maintain updated state)
      target =
        Enum.reduce(1..93, target, fn _, acc ->
          word = word_fixture()
          {:ok, updated} = WordSets.add_word_to_set(acc, word.id)
          updated
        end)

      # Target has 95 words (word1, word2 + 93 unique)
      # Source has 3 words (word1, word2, word3)
      # Combined unique: 96 words (95 + 1 new word3)
      assert target.word_count == 95

      # This should succeed (96 <= 100)
      {:ok, updated_target} = WordSets.copy_words_to_word_set(source.id, target.id)
      assert updated_target.word_count == 96
    end

    test "preserves positions in target", %{source: source, target: target} do
      # Add words to target first
      existing_word = word_fixture(%{text: "元", meaning: "existing"})
      WordSets.add_word_to_set(target, existing_word.id)

      # Copy from source
      {:ok, _} = WordSets.copy_words_to_word_set(source.id, target.id)

      # Check that new words have positions continuing from target
      {_word_set, _metadata} = WordSets.get_word_set_with_words_paginated(target.id)

      # Get positions from word_set_words association
      positions = get_word_set_word_positions(target.id)

      # Should have positions 1, 2, 3, 4 (existing at 1, 3 new words at 2, 3, 4)
      # Position 1-based to match add_word_to_set behavior
      assert Enum.sort(positions) == [1, 2, 3, 4]
    end

    test "returns ok when source has no words", %{user: user, target: target} do
      empty_source = word_set_fixture(%{user_id: user.id, name: "Empty Set"})

      {:ok, updated_target} = WordSets.copy_words_to_word_set(empty_source.id, target.id)
      assert updated_target.word_count == 0
    end

    test "returns ok when all words are duplicates", %{
      source: source,
      target: target,
      words: words
    } do
      # Add all source words to target first
      target =
        Enum.reduce(words, target, fn word, acc ->
          {:ok, updated} = WordSets.add_word_to_set(acc, word.id)
          updated
        end)

      assert target.word_count == 3

      # Copy should succeed but add nothing
      {:ok, _updated_target} = WordSets.copy_words_to_word_set(source.id, target.id)

      final_count = length(get_word_set_word_ids(target.id))
      assert final_count == 3
    end
  end

  # Helper function to get word IDs from word set
  defp get_word_set_word_ids(word_set_id) do
    import Ecto.Query
    alias Medoru.Repo
    alias Medoru.Learning.WordSetWord

    from(wsw in WordSetWord,
      where: wsw.word_set_id == ^word_set_id,
      select: wsw.word_id
    )
    |> Repo.all()
  end

  # Helper function to get positions from word set words
  defp get_word_set_word_positions(word_set_id) do
    import Ecto.Query
    alias Medoru.Repo
    alias Medoru.Learning.WordSetWord

    from(wsw in WordSetWord,
      where: wsw.word_set_id == ^word_set_id,
      select: wsw.position
    )
    |> Repo.all()
  end
end
