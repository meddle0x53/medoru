defmodule Medoru.WordDifficultyAdjustmentTest do
  use Medoru.DataCase

  alias Medoru.Repo
  alias Medoru.Content.{Word, WordKanji, Kanji}
  import Ecto.Query

  describe "word difficulty adjustment logic" do
    setup do
      # Create kanji with different JLPT levels
      n1_kanji = create_kanji!("級", 1)  # N1 - most difficult
      n2_kanji = create_kanji!("例", 2)  # N2
      n3_kanji = create_kanji!("食", 3)  # N3
      n4_kanji = create_kanji!("学", 4)  # N4
      n5_kanji = create_kanji!("日", 5)  # N5 - easiest

      {:ok,
       n1_kanji: n1_kanji,
       n2_kanji: n2_kanji,
       n3_kanji: n3_kanji,
       n4_kanji: n4_kanji,
       n5_kanji: n5_kanji}
    end

    test "N2 word with N1 kanji should become N1", %{n1_kanji: n1, n3_kanji: n3} do
      # Create N2 word that contains N1 kanji
      word = create_word!("上級", 2)  # Currently N2
      create_word_kanji!(word, n1, 0)  # Contains N1 kanji
      create_word_kanji!(word, n3, 1)  # And N3 kanji

      # Apply adjustment logic
      adjust_difficulty!()

      # Reload and check
      updated = Repo.get!(Word, word.id)
      assert updated.difficulty == 1  # Should be N1 now
    end

    test "N3 word with N1 kanji should become N1", %{n1_kanji: n1, n4_kanji: n4} do
      word = create_word!("最高級", 3)  # Currently N3
      create_word_kanji!(word, n1, 0)  # Contains N1 kanji
      create_word_kanji!(word, n4, 1)  # And N4 kanji

      adjust_difficulty!()

      updated = Repo.get!(Word, word.id)
      assert updated.difficulty == 1  # Should be N1 now
    end

    test "N3 word with N2 kanji (but no N1) should become N2", %{n2_kanji: n2, n4_kanji: n4} do
      word = create_word!("例外", 3)  # Currently N3
      create_word_kanji!(word, n2, 0)  # Contains N2 kanji
      create_word_kanji!(word, n4, 1)  # And N4 kanji (but no N1)

      adjust_difficulty!()

      updated = Repo.get!(Word, word.id)
      assert updated.difficulty == 2  # Should be N2 now
    end

    test "N3 word with only N3/N4/N5 kanji stays N3", %{n3_kanji: n3, n4_kanji: n4} do
      word = create_word!("学生", 3)  # Currently N3
      create_word_kanji!(word, n3, 0)  # N3 kanji
      create_word_kanji!(word, n4, 1)  # N4 kanji

      adjust_difficulty!()

      updated = Repo.get!(Word, word.id)
      assert updated.difficulty == 3  # Should stay N3
    end

    test "N2 word with only N2/N3/N4/N5 kanji stays N2", %{n2_kanji: n2, n3_kanji: n3} do
      word = create_word!("比例", 2)  # Currently N2
      create_word_kanji!(word, n2, 0)  # N2 kanji
      create_word_kanji!(word, n3, 1)  # N3 kanji (but no N1)

      adjust_difficulty!()

      updated = Repo.get!(Word, word.id)
      assert updated.difficulty == 2  # Should stay N2
    end

    test "multiple words are adjusted correctly", %{
      n1_kanji: n1,
      n2_kanji: n2,
      n3_kanji: n3,
      n4_kanji: n4
    } do
      # N2 -> N1
      word1 = create_word!("上級", 2)
      create_word_kanji!(word1, n1, 0)

      # N3 -> N1
      word2 = create_word!("最高級", 3)
      create_word_kanji!(word2, n1, 0)

      # N3 -> N2
      word3 = create_word!("例外", 3)
      create_word_kanji!(word3, n2, 0)

      # Stays N3
      word4 = create_word!("学生", 3)
      create_word_kanji!(word4, n3, 0)
      create_word_kanji!(word4, n4, 1)

      # Apply adjustments
      adjust_difficulty!()

      assert Repo.get!(Word, word1.id).difficulty == 1
      assert Repo.get!(Word, word2.id).difficulty == 1
      assert Repo.get!(Word, word3.id).difficulty == 2
      assert Repo.get!(Word, word4.id).difficulty == 3
    end
  end

  # Helper functions

  defp create_kanji!(character, jlpt_level) do
    %Kanji{
      character: character,
      meanings: ["test"],
      stroke_count: 5,
      jlpt_level: jlpt_level,
      frequency: 100
    }
    |> Repo.insert!()
  end

  defp create_word!(text, difficulty) do
    %Word{
      text: text,
      reading: text,
      meaning: "test meaning",
      difficulty: difficulty,
      usage_frequency: 100,
      word_type: :noun
    }
    |> Repo.insert!()
  end

  defp create_word_kanji!(word, kanji, position) do
    %WordKanji{
      word_id: word.id,
      kanji_id: kanji.id,
      kanji_reading_id: nil,
      position: position
    }
    |> Repo.insert!()
  end

  # The actual adjustment logic (same as in the script)
  defp adjust_difficulty! do
    words_with_kanji =
      from(w in Word,
        join: wk in WordKanji, on: wk.word_id == w.id,
        join: k in Kanji, on: wk.kanji_id == k.id,
        where: w.difficulty in [2, 3],
        select: %{
          word_id: w.id,
          word_difficulty: w.difficulty,
          kanji_level: k.jlpt_level
        }
      )
      |> Repo.all()

    words_by_id = Enum.group_by(words_with_kanji, & &1.word_id)

    # Collect word IDs for each adjustment category
    {n1_from_n2, n1_from_n3, n2_from_n3} =
      Enum.reduce(words_by_id, {[], [], []}, fn {word_id, kanji_list}, {n2to1, n3to1, n3to2} ->
        word_difficulty = hd(kanji_list).word_difficulty
        max_kanji_difficulty = Enum.min_by(kanji_list, & &1.kanji_level).kanji_level

        cond do
          max_kanji_difficulty == 1 and word_difficulty == 2 ->
            {[word_id | n2to1], n3to1, n3to2}

          max_kanji_difficulty == 1 and word_difficulty == 3 ->
            {n2to1, [word_id | n3to1], n3to2}

          max_kanji_difficulty == 2 and word_difficulty == 3 ->
            {n2to1, n3to1, [word_id | n3to2]}

          true ->
            {n2to1, n3to1, n3to2}
        end
      end)

    # Apply updates
    if n1_from_n2 != [] do
      from(w in Word, where: w.id in ^n1_from_n2)
      |> Repo.update_all(set: [difficulty: 1])
    end

    if n1_from_n3 != [] do
      from(w in Word, where: w.id in ^n1_from_n3)
      |> Repo.update_all(set: [difficulty: 1])
    end

    if n2_from_n3 != [] do
      from(w in Word, where: w.id in ^n2_from_n3)
      |> Repo.update_all(set: [difficulty: 2])
    end

    :ok
  end
end
