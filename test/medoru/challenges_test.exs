defmodule Medoru.ChallengesTest do
  use Medoru.DataCase

  alias Medoru.Challenges
  alias Medoru.Challenges.KanjiMasterScore

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.LearningFixtures

  defp record(user, attrs) do
    Challenges.record_score(user, Enum.into(attrs, %{}))
  end

  describe "record_score/2" do
    test "inserts a new linked score" do
      user = user_fixture()

      assert {:ok, %KanjiMasterScore{} = score} =
               record(user, %{score: 100, display_mode: "linked"})

      assert score.score == 100
      assert score.display_mode == "linked"
      assert score.user_id == user.id
    end

    test "inserts an anonymous score with a name" do
      user = user_fixture()

      assert {:ok, %KanjiMasterScore{} = score} =
               record(user, %{score: 50, display_mode: "anonymous", anonymous_name: "shadow"})

      assert score.anonymous_name == "shadow"
    end

    test "rejects anonymous score with blank name" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{} = cs} =
               record(user, %{score: 50, display_mode: "anonymous", anonymous_name: ""})

      assert %{anonymous_name: [_]} = errors_on(cs)
    end

    test "rejects unknown display_mode" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{} = cs} =
               record(user, %{score: 50, display_mode: "whatever"})

      assert %{display_mode: [_]} = errors_on(cs)
    end

    test "higher score overrides own previous score" do
      user = user_fixture()
      {:ok, _} = record(user, %{score: 100, display_mode: "linked"})

      assert {:ok, %KanjiMasterScore{} = score} =
               record(user, %{score: 150, display_mode: "linked"})

      assert score.score == 150
      assert Challenges.get_rank_and_score(user.id).score == 150
    end

    test "lower score does not override but identity can change" do
      user = user_fixture()
      {:ok, _} = record(user, %{score: 100, display_mode: "linked"})

      assert {:ok, %KanjiMasterScore{} = score} =
               record(user, %{
                 score: 40,
                 display_mode: "anonymous",
                 anonymous_name: "newname"
               })

      assert score.score == 100
      assert score.display_mode == "anonymous"
      assert score.anonymous_name == "newname"
      assert Challenges.leaderboard_entry_count() == 1
    end
  end

  describe "get_leaderboard/0" do
    test "returns top 5 ordered by score desc" do
      users = for _ <- 1..6, do: user_fixture()

      users
      |> Enum.with_index(1)
      |> Enum.each(fn {user, i} ->
        {:ok, _} = record(user, %{score: i * 10, display_mode: "linked"})
      end)

      leaderboard = Challenges.get_leaderboard()

      assert length(leaderboard) == 5
      assert Enum.map(leaderboard, & &1.score) == [60, 50, 40, 30, 20]
      assert Enum.all?(leaderboard, &Ecto.assoc_loaded?(&1.user))
    end
  end

  describe "get_rank_and_score/1" do
    test "returns rank 1 for the top score" do
      user = user_fixture()
      {:ok, _} = record(user, %{score: 100, display_mode: "linked"})
      other = user_fixture()
      {:ok, _} = record(other, %{score: 50, display_mode: "linked"})

      assert %{rank: 1, score: 100} = Challenges.get_rank_and_score(user.id)
      assert %{rank: 2, score: 50} = Challenges.get_rank_and_score(other.id)
    end

    test "returns nil for user without score" do
      user = user_fixture()
      assert Challenges.get_rank_and_score(user.id) == nil
    end
  end

  describe "learned_kanji_count/1 and eligibility" do
    test "49 learned kanji is not eligible, 50 is" do
      user = user_fixture()

      # unique_kanji_character/0 only has 100 possible values, so generate
      # our own unique characters for the 50-kanji boundary test.
      unique_char = fn ->
        index = System.unique_integer([:positive]) |> rem(5000)
        <<0x3400 + index::utf8>>
      end

      for _ <- 1..49 do
        kanji = kanji_fixture(%{character: unique_char.()})
        user_progress_fixture(%{user_id: user.id, kanji_id: kanji.id})
      end

      assert Challenges.learned_kanji_count(user) == 49
      refute Challenges.eligible?(user)

      kanji = kanji_fixture(%{character: unique_char.()})
      user_progress_fixture(%{user_id: user.id, kanji_id: kanji.id})

      assert Challenges.learned_kanji_count(user) == 50
      assert Challenges.eligible?(user)
    end
  end

  describe "kanji_master_pool/1" do
    test "returns drawable learned kanji with question data" do
      user = user_fixture()

      drawable =
        kanji_with_readings_fixture(%{
          stroke_count: 5,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      empty_data = kanji_fixture(%{stroke_count: 3, stroke_data: %{}})

      user_progress_fixture(%{user_id: user.id, kanji_id: drawable.id})
      user_progress_fixture(%{user_id: user.id, kanji_id: empty_data.id})

      pool = Challenges.kanji_master_pool(user)

      assert [entry] = pool
      assert entry.character == drawable.character
      assert entry.stroke_data["strokes"] != []
      assert entry.stroke_count == 5
      assert Map.has_key?(entry, :word)
      assert Map.has_key?(entry, :kun)
      assert Map.has_key?(entry, :on)
      assert Map.has_key?(entry, :meanings)
      assert length(entry.meanings) <= 2
    end

    test "word is the most frequent word using the kanji" do
      user = user_fixture()

      kanji =
        kanji_with_readings_fixture(%{
          stroke_count: 4,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      reading = hd(kanji.kanji_readings)

      {:ok, common} =
        Medoru.Content.create_word_with_kanji(
          %{
            text: "常用語",
            meaning: "common meaning",
            reading: "こもん",
            difficulty: 5,
            usage_frequency: 10,
            word_type: :noun
          },
          [%{position: 0, kanji_id: kanji.id, kanji_reading_id: reading.id}]
        )

      {:ok, rare} =
        Medoru.Content.create_word_with_kanji(
          %{
            text: "希少語",
            meaning: "rare meaning",
            reading: "れあ",
            difficulty: 5,
            usage_frequency: 900,
            word_type: :noun
          },
          [%{position: 0, kanji_id: kanji.id, kanji_reading_id: reading.id}]
        )

      user_progress_fixture(%{user_id: user.id, kanji_id: kanji.id})

      assert [entry] = Challenges.kanji_master_pool(user)
      assert entry.word.text == common.text
      assert entry.word.text != rare.text
    end

    test "excludes kanji without stroke_data" do
      user = user_fixture()
      kanji = kanji_fixture(%{stroke_data: %{"strokes" => []}})
      user_progress_fixture(%{user_id: user.id, kanji_id: kanji.id})

      assert Challenges.kanji_master_pool(user) == []
    end
  end
end
