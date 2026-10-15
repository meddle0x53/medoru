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

  describe "record_anonymous_score/1" do
    test "creates an anonymous n5 entry with a nil user" do
      assert {:ok, %KanjiMasterScore{} = score} =
               Challenges.record_anonymous_score(%{score: 77, anonymous_name: "wanderer"})

      assert score.user_id == nil
      assert score.mode == "n5"
      assert score.display_mode == "anonymous"
      assert score.anonymous_name == "wanderer"
    end

    test "trims the name and upserts by (mode, anonymous_name) keeping the higher score" do
      {:ok, _} = Challenges.record_anonymous_score(%{score: 50, anonymous_name: "  rookie  "})

      assert Challenges.leaderboard_entry_count("n5") == 1
      assert [%{score: 50, anonymous_name: "rookie"}] = Challenges.get_leaderboard("n5")

      {:ok, _} = Challenges.record_anonymous_score(%{score: 90, anonymous_name: "rookie"})

      assert Challenges.leaderboard_entry_count("n5") == 1
      assert [%{score: 90}] = Challenges.get_leaderboard("n5")

      # Lower replay keeps the higher stored score.
      {:ok, _} = Challenges.record_anonymous_score(%{score: 10, anonymous_name: "rookie"})

      assert [%{score: 90}] = Challenges.get_leaderboard("n5")
    end

    test "refuses blank and over-12-character names" do
      assert {:error, %Ecto.Changeset{} = cs} =
               Challenges.record_anonymous_score(%{score: 50, anonymous_name: "   "})

      assert %{anonymous_name: [_]} = errors_on(cs)

      assert {:error, %Ecto.Changeset{} = cs} =
               Challenges.record_anonymous_score(%{score: 50, anonymous_name: "thirteenchars"})

      assert %{anonymous_name: [_]} = errors_on(cs)
      assert Challenges.leaderboard_entry_count("n5") == 0
    end
  end

  describe "kanji_master_n5_pool/0" do
    test "includes only N5 kanji with stroke data, regardless of user" do
      n5_kanji =
        kanji_fixture(%{
          stroke_count: 4,
          jlpt_level: 5,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      _n1_kanji =
        kanji_fixture(%{
          stroke_count: 4,
          jlpt_level: 1,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      _no_strokes = kanji_fixture(%{jlpt_level: 5, stroke_data: %{"strokes" => []}})

      pool = Challenges.kanji_master_n5_pool()

      assert Enum.any?(pool, &(&1.character == n5_kanji.character))
      refute Enum.any?(pool, &(&1.character == _n1_kanji.character))
      refute Enum.any?(pool, &(&1.character == _no_strokes.character))
    end

    test "word is the rarest word with usage_frequency < 1000 using the kanji" do
      kanji =
        kanji_with_readings_fixture(%{
          jlpt_level: 5,
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

      assert [entry] =
               Challenges.kanji_master_n5_pool()
               |> Enum.filter(&(&1.character == kanji.character))

      assert entry.word.text == rare.text
      assert entry.word.text != common.text
    end

    test "word is nil when no word under the frequency cap uses the kanji" do
      kanji =
        kanji_with_readings_fixture(%{
          jlpt_level: 5,
          stroke_count: 4,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      reading = hd(kanji.kanji_readings)

      {:ok, _too_frequent} =
        Medoru.Content.create_word_with_kanji(
          %{
            text: "超頻出語",
            meaning: "too frequent",
            reading: "ちょう",
            difficulty: 5,
            usage_frequency: 1000,
            word_type: :noun
          },
          [%{position: 0, kanji_id: kanji.id, kanji_reading_id: reading.id}]
        )

      assert [entry] =
               Challenges.kanji_master_n5_pool()
               |> Enum.filter(&(&1.character == kanji.character))

      assert entry.word == nil
    end
  end

  describe "kanji_master_n4_pool/0" do
    test "includes N4 and N5 kanji with stroke data, excluding other levels" do
      n4_kanji =
        kanji_fixture(%{
          stroke_count: 8,
          jlpt_level: 4,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      n5_kanji =
        kanji_fixture(%{
          stroke_count: 4,
          jlpt_level: 5,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      n3_kanji =
        kanji_fixture(%{
          stroke_count: 10,
          jlpt_level: 3,
          stroke_data: %{"strokes" => [%{"path" => "M0 0"}]}
        })

      pool = Challenges.kanji_master_n4_pool()
      characters = Enum.map(pool, & &1.character)

      assert n4_kanji.character in characters
      assert n5_kanji.character in characters
      refute n3_kanji.character in characters
    end
  end
end
