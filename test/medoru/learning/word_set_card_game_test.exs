defmodule Medoru.Learning.WordSetCardGameTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  alias Medoru.Learning.{WordSetCardGame, WordSets}

  defp set_with_words(user, n) do
    word_set = word_set_fixture(%{user_id: user.id})

    words =
      1..n
      |> Enum.map_reduce(word_set, fn i, set ->
        word = word_fixture(%{meaning: "meaning #{i}"})
        {:ok, updated_set} = WordSets.add_word_to_set(set, word.id)
        {word, updated_set}
      end)
      |> elem(0)

    {Repo.get!(Medoru.Learning.WordSet, word_set.id), words}
  end

  describe "create_card_game_for_set/2" do
    test "snapshots the words in the set's word order" do
      user = user_fixture()
      {word_set, words} = set_with_words(user, 5)

      assert {:ok, game} = WordSets.create_card_game_for_set(word_set, user)

      snapshot = WordSetCardGame.snapshot_words(game)

      assert Enum.map(snapshot, & &1.id) == Enum.map(words, & &1.id)
      assert Enum.map(snapshot, & &1.text) == Enum.map(words, & &1.text)

      Enum.each(Enum.zip(words, snapshot), fn {word, snap} ->
        assert snap.meaning == word.meaning
        assert snap.reading == word.reading
        assert snap.translations == word.translations
      end)
    end

    test "caps the snapshot at 10 words" do
      user = user_fixture()
      {word_set, words} = set_with_words(user, 12)

      assert {:ok, game} = WordSets.create_card_game_for_set(word_set, user)
      assert length(game.words) == 10

      assert Enum.map(WordSetCardGame.snapshot_words(game), & &1.id) ==
               words |> Enum.take(10) |> Enum.map(& &1.id)
    end

    test "returns :not_enough_words for sets with fewer than 4 words" do
      user = user_fixture()
      {word_set, _} = set_with_words(user, 3)

      assert {:error, :not_enough_words} = WordSets.create_card_game_for_set(word_set, user)
    end

    test "returns :already_exists when a game already exists for the set" do
      user = user_fixture()
      {word_set, _} = set_with_words(user, 4)

      assert {:ok, _game} = WordSets.create_card_game_for_set(word_set, user)
      assert {:error, :already_exists} = WordSets.create_card_game_for_set(word_set, user)
    end

    test "unique index prevents two games for the same set" do
      user = user_fixture()
      {word_set, _} = set_with_words(user, 4)

      assert {:ok, _game} = WordSets.create_card_game_for_set(word_set, user)

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%WordSetCardGame{
          word_set_id: word_set.id,
          user_id: user.id,
          words: []
        })
      end
    end

    test "snapshot does not change when the word set is edited afterwards" do
      user = user_fixture()
      {word_set, [first_word | _]} = set_with_words(user, 4)
      assert {:ok, game} = WordSets.create_card_game_for_set(word_set, user)

      assert {:ok, _} = WordSets.remove_word_from_set(word_set, first_word.id)

      reloaded = WordSets.get_card_game_for_set(word_set.id)
      assert reloaded.words == game.words
    end
  end

  describe "get_card_game_for_set/1" do
    test "returns nil when no game exists" do
      user = user_fixture()
      word_set = word_set_fixture(%{user_id: user.id})

      assert WordSets.get_card_game_for_set(word_set.id) == nil
    end

    test "returns the game when it exists" do
      user = user_fixture()
      {word_set, _} = set_with_words(user, 4)

      assert {:ok, game} = WordSets.create_card_game_for_set(word_set, user)
      assert WordSets.get_card_game_for_set(word_set.id).id == game.id
    end
  end

  describe "delete_card_game/2" do
    test "owner can delete the game" do
      user = user_fixture()
      {word_set, _} = set_with_words(user, 4)
      assert {:ok, game} = WordSets.create_card_game_for_set(word_set, user)

      assert {:ok, _} = WordSets.delete_card_game(game, user)
      assert WordSets.get_card_game_for_set(word_set.id) == nil
    end

    test "non-owner cannot delete the game" do
      owner = user_fixture()
      other = user_fixture()
      {word_set, _} = set_with_words(owner, 4)
      assert {:ok, game} = WordSets.create_card_game_for_set(word_set, owner)

      assert {:error, :not_authorized} = WordSets.delete_card_game(game, other)
      assert WordSets.get_card_game_for_set(word_set.id) != nil
    end
  end
end
