defmodule Medoru.ContentTest do
  use Medoru.DataCase

  alias Medoru.Content
  alias Medoru.Content.{Kanji, KanjiReading, Word, WordKanji}

  describe "kanji" do
    import Medoru.ContentFixtures

    @invalid_attrs %{character: nil, meanings: nil, stroke_count: nil, jlpt_level: nil}

    test "list_kanji/0 returns all kanji" do
      kanji = kanji_fixture()
      assert Content.list_kanji() |> Enum.map(& &1.id) |> Enum.member?(kanji.id)
    end

    test "list_kanji_by_level/1 returns kanji filtered by JLPT level" do
      n5_kanji = kanji_fixture(%{jlpt_level: 5, character: unique_kanji_char()})
      n4_kanji = kanji_fixture(%{jlpt_level: 4, character: unique_kanji_char()})

      n5_list = Content.list_kanji_by_level(5)
      n4_list = Content.list_kanji_by_level(4)

      assert Enum.map(n5_list, & &1.id) |> Enum.member?(n5_kanji.id)
      assert Enum.map(n4_list, & &1.id) |> Enum.member?(n4_kanji.id)
      refute Enum.map(n5_list, & &1.id) |> Enum.member?(n4_kanji.id)
    end

    test "list_kanji_by_level/1 orders by frequency" do
      kanji_high = kanji_fixture(%{frequency: 1, character: unique_kanji_char()})
      kanji_low = kanji_fixture(%{frequency: 100, character: unique_kanji_char()})

      list = Content.list_kanji_by_level(5)
      high_index = Enum.find_index(list, &(&1.id == kanji_high.id))
      low_index = Enum.find_index(list, &(&1.id == kanji_low.id))

      assert high_index < low_index
    end

    test "get_kanji!/1 returns the kanji with given id" do
      kanji = kanji_fixture()
      assert Content.get_kanji!(kanji.id).id == kanji.id
    end

    test "get_kanji!/1 raises if kanji does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Content.get_kanji!(Ecto.UUID.generate())
      end
    end

    test "get_kanji_by_character/1 returns the kanji with given character" do
      kanji = kanji_fixture()
      assert Content.get_kanji_by_character(kanji.character).id == kanji.id
    end

    test "get_kanji_by_character/1 returns nil if kanji does not exist" do
      assert Content.get_kanji_by_character("非") == nil
    end

    test "get_kanji_with_readings!/1 returns kanji with preloaded readings" do
      kanji = kanji_with_readings_fixture()
      loaded = Content.get_kanji_with_readings!(kanji.id)

      assert loaded.id == kanji.id
      assert is_list(loaded.kanji_readings)
      assert length(loaded.kanji_readings) == 2
    end

    test "create_kanji/1 with valid data creates a kanji" do
      valid_attrs = %{
        character: unique_kanji_char(),
        meanings: ["sun", "day"],
        stroke_count: 4,
        jlpt_level: 5,
        frequency: 1,
        radicals: ["日"],
        stroke_data: %{}
      }

      assert {:ok, %Kanji{} = kanji} = Content.create_kanji(valid_attrs)
      assert kanji.character == valid_attrs.character
      assert kanji.meanings == ["sun", "day"]
      assert kanji.stroke_count == 4
      assert kanji.jlpt_level == 5
      assert kanji.frequency == 1
    end

    test "create_kanji/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_kanji(@invalid_attrs)
    end

    test "create_kanji/1 validates kanji character is in CJK range" do
      attrs = %{
        # Not a kanji
        character: "a",
        meanings: ["test"],
        stroke_count: 4,
        jlpt_level: 5
      }

      assert {:error, changeset} = Content.create_kanji(attrs)

      assert "must be a valid kanji character (CJK Unified Ideographs)" in errors_on(changeset).character
    end

    test "create_kanji/1 validates character uniqueness" do
      kanji = kanji_fixture()

      attrs = %{
        character: kanji.character,
        meanings: ["duplicate"],
        stroke_count: 4,
        jlpt_level: 5
      }

      assert {:error, changeset} = Content.create_kanji(attrs)
      assert "has already been taken" in errors_on(changeset).character
    end

    test "create_kanji/1 validates jlpt_level range" do
      attrs = %{
        character: unique_kanji_char(),
        meanings: ["test"],
        stroke_count: 4,
        # Invalid - max is 5
        jlpt_level: 6
      }

      assert {:error, changeset} = Content.create_kanji(attrs)
      assert "must be less than or equal to 5" in errors_on(changeset).jlpt_level
    end

    test "create_kanji_with_readings/2 creates kanji and readings in transaction" do
      kanji_attrs = %{
        character: unique_kanji_char(),
        meanings: ["test"],
        stroke_count: 4,
        jlpt_level: 5
      }

      readings_attrs = [
        %{reading_type: :on, reading: "テスト", romaji: "tesuto"},
        %{reading_type: :kun, reading: "てすと", romaji: "tesuto"}
      ]

      assert {:ok, %Kanji{} = kanji} =
               Content.create_kanji_with_readings(kanji_attrs, readings_attrs)

      assert kanji.character == kanji_attrs.character
      assert length(kanji.kanji_readings) == 2

      # Verify readings were created
      readings = Content.list_readings_for_kanji(kanji.id)
      assert length(readings) == 2
    end

    test "create_kanji_with_readings/2 rolls back on invalid reading" do
      kanji_attrs = %{
        character: unique_kanji_char(),
        meanings: ["test"],
        stroke_count: 4,
        jlpt_level: 5
      }

      # Invalid reading - wrong katakana for on reading
      readings_attrs = [
        # Should be katakana
        %{reading_type: :on, reading: "てすと", romaji: "tesuto"}
      ]

      assert {:error, %Ecto.Changeset{} = changeset} =
               Content.create_kanji_with_readings(kanji_attrs, readings_attrs)

      # The changeset will be from the reading validation failure
      assert changeset.errors[:reading] || changeset.errors[:character]

      # Verify kanji was not created
      assert Content.get_kanji_by_character(kanji_attrs.character) == nil
    end

    test "update_kanji/2 with valid data updates the kanji" do
      kanji = kanji_fixture()
      update_attrs = %{meanings: ["updated meaning"], stroke_count: 5}

      assert {:ok, %Kanji{} = kanji} = Content.update_kanji(kanji, update_attrs)
      assert kanji.meanings == ["updated meaning"]
      assert kanji.stroke_count == 5
    end

    test "update_kanji/2 with invalid data returns error changeset" do
      kanji = kanji_fixture()
      assert {:error, %Ecto.Changeset{}} = Content.update_kanji(kanji, @invalid_attrs)
      assert kanji.id == Content.get_kanji!(kanji.id).id
    end

    test "delete_kanji/1 deletes the kanji and associated readings" do
      kanji = kanji_with_readings_fixture()
      reading_ids = Enum.map(kanji.kanji_readings, & &1.id)

      assert {:ok, %Kanji{}} = Content.delete_kanji(kanji)

      assert_raise Ecto.NoResultsError, fn ->
        Content.get_kanji!(kanji.id)
      end

      # Verify readings were also deleted
      for reading_id <- reading_ids do
        assert_raise Ecto.NoResultsError, fn ->
          Content.get_kanji_reading!(reading_id)
        end
      end
    end

    test "change_kanji/1 returns a kanji changeset" do
      kanji = kanji_fixture()
      assert %Ecto.Changeset{} = Content.change_kanji(kanji)
    end
  end

  describe "kanji_readings" do
    import Medoru.ContentFixtures

    @invalid_attrs %{reading_type: nil, reading: nil, romaji: nil}

    test "list_kanji_readings/0 returns all readings" do
      kanji = kanji_fixture()
      reading = kanji_reading_fixture(kanji.id)

      assert Content.list_kanji_readings() |> Enum.map(& &1.id) |> Enum.member?(reading.id)
    end

    test "list_readings_for_kanji/1 returns readings for specific kanji" do
      kanji1 = kanji_fixture(%{character: unique_kanji_char()})
      kanji2 = kanji_fixture(%{character: unique_kanji_char()})

      reading1 = kanji_reading_fixture(kanji1.id, %{reading: "テストイチ"})
      _reading2 = kanji_reading_fixture(kanji2.id, %{reading: "テストニ"})

      readings = Content.list_readings_for_kanji(kanji1.id)
      assert length(readings) == 1
      assert hd(readings).id == reading1.id
    end

    test "get_kanji_reading!/1 returns the reading with given id" do
      kanji = kanji_fixture()
      reading = kanji_reading_fixture(kanji.id)

      assert Content.get_kanji_reading!(reading.id).id == reading.id
    end

    test "create_kanji_reading/1 with valid data creates a reading" do
      kanji = kanji_fixture()

      valid_attrs = %{
        reading_type: :on,
        reading: "ニチ",
        romaji: "nichi",
        usage_notes: "Used in compound words",
        kanji_id: kanji.id
      }

      assert {:ok, %KanjiReading{} = reading} = Content.create_kanji_reading(valid_attrs)
      assert reading.reading_type == :on
      assert reading.reading == "ニチ"
      assert reading.romaji == "nichi"
      assert reading.kanji_id == kanji.id
    end

    test "create_kanji_reading/1 validates on readings use katakana" do
      kanji = kanji_fixture()

      attrs = %{
        reading_type: :on,
        # Hiragana - should be katakana for on reading
        reading: "ひ",
        romaji: "hi",
        kanji_id: kanji.id
      }

      assert {:error, changeset} = Content.create_kanji_reading(attrs)

      assert "must be valid kana (katakana for on, hiragana for kun)" in errors_on(changeset).reading
    end

    test "create_kanji_reading/1 validates kun readings use hiragana" do
      kanji = kanji_fixture()

      attrs = %{
        reading_type: :kun,
        # Katakana - should be hiragana for kun reading
        reading: "ヒ",
        romaji: "hi",
        kanji_id: kanji.id
      }

      assert {:error, changeset} = Content.create_kanji_reading(attrs)

      assert "must be valid kana (katakana for on, hiragana for kun)" in errors_on(changeset).reading
    end

    test "create_kanji_reading/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_kanji_reading(@invalid_attrs)
    end

    test "update_kanji_reading/2 with valid data updates the reading" do
      kanji = kanji_fixture()
      reading = kanji_reading_fixture(kanji.id)

      update_attrs = %{romaji: "updated", usage_notes: "New notes"}

      assert {:ok, %KanjiReading{} = reading} =
               Content.update_kanji_reading(reading, update_attrs)

      assert reading.romaji == "updated"
      assert reading.usage_notes == "New notes"
    end

    test "delete_kanji_reading/1 deletes the reading" do
      kanji = kanji_fixture()
      reading = kanji_reading_fixture(kanji.id)

      assert {:ok, %KanjiReading{}} = Content.delete_kanji_reading(reading)

      assert_raise Ecto.NoResultsError, fn ->
        Content.get_kanji_reading!(reading.id)
      end
    end

    test "change_kanji_reading/1 returns a reading changeset" do
      kanji = kanji_fixture()
      reading = kanji_reading_fixture(kanji.id)

      assert %Ecto.Changeset{} = Content.change_kanji_reading(reading)
    end
  end

  describe "words" do
    import Medoru.ContentFixtures

    @invalid_attrs %{text: nil, meaning: nil, reading: nil, difficulty: nil}

    test "list_words/0 returns all words ordered by sort_score" do
      word1 = word_fixture(%{sort_score: 10, text: unique_word_text()})
      word2 = word_fixture(%{sort_score: 5, text: unique_word_text()})

      list = Content.list_words()
      score_5_index = Enum.find_index(list, &(&1.id == word2.id))
      score_10_index = Enum.find_index(list, &(&1.id == word1.id))

      assert score_5_index < score_10_index
    end

    test "list_words_by_difficulty/1 returns words filtered by difficulty" do
      n5_word = word_fixture(%{difficulty: 5, text: unique_word_text()})
      n4_word = word_fixture(%{difficulty: 4, text: unique_word_text()})

      n5_list = Content.list_words_by_difficulty(5)
      n4_list = Content.list_words_by_difficulty(4)

      assert Enum.map(n5_list, & &1.id) |> Enum.member?(n5_word.id)
      assert Enum.map(n4_list, & &1.id) |> Enum.member?(n4_word.id)
      refute Enum.map(n5_list, & &1.id) |> Enum.member?(n4_word.id)
    end

    test "list_words_by_kanji/1 returns words containing specific kanji" do
      word_with_kanji = word_with_kanji_fixture()
      kanji_id = List.first(word_with_kanji.word_kanjis).kanji_id

      words = Content.list_words_by_kanji(kanji_id)
      assert Enum.map(words, & &1.id) |> Enum.member?(word_with_kanji.id)
    end

    test "search_words/2 returns exact match 'blue' before phrases containing 'blue'" do
      # Create the exact match word "blue" (青い) - HIGH frequency
      blue_exact =
        word_fixture(%{text: "青い", meaning: "blue", reading: "あおい", usage_frequency: 5000})

      # Create phrases containing "blue" that should rank lower - but with even HIGHER frequency
      # This simulates the real-world scenario where common phrases might outrank the base word
      _navy_blue =
        word_fixture(%{text: "紺碧", meaning: "navy blue", reading: "こんぺき", usage_frequency: 10000})

      _dark_blue =
        word_fixture(%{text: "紺色", meaning: "dark blue", reading: "こんいろ", usage_frequency: 8000})

      _blue_sky =
        word_fixture(%{text: "青空", meaning: "blue sky", reading: "あおぞら", usage_frequency: 9000})

      # Search for "blue" with limit: 10 like the LiveView does
      results = Content.search_words("blue", limit: 10)

      # The exact match "blue" should be first, even though phrases have higher usage_frequency
      assert length(results) >= 4
      first_result = hd(results)

      # The exact match "blue" should be first
      assert first_result.id == blue_exact.id,
             "Expected exact match 'blue' to be first, but got '#{first_result.meaning}'"

      assert first_result.meaning == "blue"
    end

    test "search_words/2 with limit 10 returns exact match even when DB has many words" do
      # Create many words with "blue" in their meaning but with higher frequencies
      # This simulates a populated database
      variants = [
        {"紺青", "dark blue", "こんじょう"},
        {"水色", "light blue", "みずいろ"},
        {"空色", "sky blue", "そらいろ"},
        {"藍色", "indigo blue", "あいいろ"},
        {"蔚", "azure blue", "あお"},
        {"碧", "blue green", "あお"},
        {"蒼", "pale blue", "あお"},
        {"藍", "indigo", "あい"},
        {"瑠璃", "lapis lazuli blue", "るり"},
        {"紺", "navy blue", "こん"},
        {"群青", "ultramarine", "ぐんじょう"},
        {"青白", "pale blue white", "あおじろ"},
        {"浅葱", "light blue green", "あさぎ"},
        {"藍白", "indigo white", "あいじろ"},
        {"天藍", "sky blue", "てんらん"}
      ]

      for {text, meaning, reading} <- variants do
        word_fixture(%{
          text: text,
          meaning: meaning,
          reading: reading,
          usage_frequency: 10000
        })
      end

      # Create the exact match with lower frequency
      blue_exact =
        word_fixture(%{text: "青い", meaning: "blue", reading: "あおい", usage_frequency: 100})

      # Search with limit 10
      results = Content.search_words("blue", limit: 10)

      # The exact match should still appear in results and be first
      assert length(results) <= 10
      first_result = hd(results)

      assert first_result.id == blue_exact.id,
             "Expected exact match 'blue' to be first even with many high-frequency variants"
    end

    test "search_words/2 exact match appears before partial matches for common words" do
      # Create words similar to the "one" scenario mentioned in requirements
      one_exact = word_fixture(%{text: "一", meaning: "one", reading: "いち", usage_frequency: 2000})

      _one_person =
        word_fixture(%{text: "一人", meaning: "one person", reading: "ひとり", usage_frequency: 500})

      _one_day =
        word_fixture(%{text: "一日", meaning: "one day", reading: "いちにち", usage_frequency: 800})

      results = Content.search_words("one", limit: 10)

      # Exact match should be first
      assert length(results) >= 3
      first_result = hd(results)
      assert first_result.id == one_exact.id
      assert first_result.meaning == "one"
    end

    test "search_words/2 exact kanji match appears first when searching by kanji character" do
      # Create the kanji word "一" (one)
      ichi_exact = word_fixture(%{text: "一", meaning: "one", reading: "いち", usage_frequency: 100})

      # Create compound words containing "一" with higher frequencies
      _one_person =
        word_fixture(%{text: "一人", meaning: "one person", reading: "ひとり", usage_frequency: 500})

      _one_day =
        word_fixture(%{text: "一日", meaning: "one day", reading: "いちにち", usage_frequency: 800})

      _first_month =
        word_fixture(%{text: "一月", meaning: "January", reading: "いちがつ", usage_frequency: 600})

      # Search for the kanji "一"
      results = Content.search_words("一", limit: 10)

      # The exact kanji match "一" should be first
      assert length(results) >= 3
      first_result = hd(results)

      assert first_result.id == ichi_exact.id,
             "Expected exact kanji match '一' to be first, but got '#{first_result.text}'"

      assert first_result.text == "一"
    end

    test "search_words/2 exact reading match appears first when searching by reading" do
      # Create the kanji word "一" (one)
      ichi_exact = word_fixture(%{text: "一", meaning: "one", reading: "いち", usage_frequency: 100})

      # Create words with similar readings (containing "いち") with higher frequencies
      _one_day =
        word_fixture(%{text: "一日", meaning: "one day", reading: "いちにち", usage_frequency: 800})

      _first_month =
        word_fixture(%{text: "一月", meaning: "January", reading: "いちがつ", usage_frequency: 600})

      _market =
        word_fixture(%{text: "市場", meaning: "market", reading: "いちば", usage_frequency: 500})

      # Search for the reading "いち"
      results = Content.search_words("いち", limit: 10)

      # The exact reading match "一" (いち) should be first
      assert length(results) >= 3
      first_result = hd(results)

      assert first_result.id == ichi_exact.id,
             "Expected exact reading match '一' (いち) to be first, but got '#{first_result.text}' (#{first_result.reading})"

      assert first_result.reading == "いち"
    end

    test "get_word!/1 returns the word with given id" do
      word = word_fixture()
      assert Content.get_word!(word.id).id == word.id
    end

    test "get_word!/1 raises if word does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Content.get_word!(Ecto.UUID.generate())
      end
    end

    test "get_word_by_text/1 returns the word with given text" do
      word = word_fixture()
      assert Content.get_word_by_text(word.text).id == word.id
    end

    test "get_word_by_text/1 returns nil if word does not exist" do
      assert Content.get_word_by_text("不存在") == nil
    end

    test "get_word_with_kanji!/1 returns word with preloaded kanji and readings" do
      word = word_with_kanji_fixture()
      loaded = Content.get_word_with_kanji!(word.id)

      assert loaded.id == word.id
      assert is_list(loaded.word_kanjis)
      assert length(loaded.word_kanjis) == 2

      # Check that kanji and readings are preloaded
      first_wk = List.first(loaded.word_kanjis)
      assert %Kanji{} = first_wk.kanji
    end

    test "create_word/1 with valid data creates a word" do
      valid_attrs = %{
        text: unique_word_text(),
        meaning: "test meaning",
        reading: "てすと",
        difficulty: 5,
        usage_frequency: 100
      }

      assert {:ok, %Word{} = word} = Content.create_word(valid_attrs)
      assert word.text == valid_attrs.text
      assert word.meaning == "test meaning"
      assert word.reading == "てすと"
      assert word.difficulty == 5
      assert word.usage_frequency == 100
    end

    test "create_word/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_word(@invalid_attrs)
    end

    test "create_word/1 validates difficulty range" do
      attrs = %{
        text: unique_word_text(),
        meaning: "test",
        reading: "てすと",
        difficulty: 6
      }

      assert {:error, changeset} = Content.create_word(attrs)
      assert "must be less than or equal to 5" in errors_on(changeset).difficulty
    end

    test "create_word/1 validates text contains Japanese characters" do
      attrs = %{
        text: "hello",
        meaning: "test",
        reading: "てすと",
        difficulty: 5
      }

      assert {:error, changeset} = Content.create_word(attrs)
      assert "must contain valid Japanese characters" in errors_on(changeset).text
    end

    test "create_word/1 validates reading contains only kana" do
      attrs = %{
        text: unique_word_text(),
        meaning: "test",
        reading: "testテスト",
        difficulty: 5
      }

      assert {:error, changeset} = Content.create_word(attrs)
      assert "must contain only hiragana or katakana" in errors_on(changeset).reading
    end

    test "create_word/1 validates text uniqueness" do
      word = word_fixture()

      attrs = %{
        text: word.text,
        meaning: "duplicate",
        reading: "てすと",
        difficulty: 5
      }

      assert {:error, changeset} = Content.create_word(attrs)
      assert "has already been taken" in errors_on(changeset).text
    end

    test "create_word_with_kanji/2 creates word and kanji links in transaction" do
      kanji1 = kanji_with_readings_fixture()
      kanji2 = kanji_with_readings_fixture()

      reading1 = List.first(Enum.filter(kanji1.kanji_readings, &(&1.reading_type == :on)))
      reading2 = List.first(Enum.filter(kanji2.kanji_readings, &(&1.reading_type == :on)))

      word_attrs = %{
        text: unique_word_text(),
        meaning: "test compound",
        reading: "てすと",
        difficulty: 5,
        usage_frequency: 100
      }

      kanji_links = [
        %{position: 0, kanji_id: kanji1.id, kanji_reading_id: reading1 && reading1.id},
        %{position: 1, kanji_id: kanji2.id, kanji_reading_id: reading2 && reading2.id}
      ]

      assert {:ok, %Word{} = word} = Content.create_word_with_kanji(word_attrs, kanji_links)
      assert word.text == word_attrs.text
      assert length(word.word_kanjis) == 2

      # Verify word_kanjis were created
      wks = Content.list_kanji_for_word(word.id)
      assert length(wks) == 2
    end

    test "create_word_with_kanji/2 rolls back on invalid kanji link" do
      word_attrs = %{
        text: unique_word_text(),
        meaning: "test",
        reading: "てすと",
        difficulty: 5
      }

      # Invalid kanji_id
      kanji_links = [
        %{position: 0, kanji_id: Ecto.UUID.generate(), kanji_reading_id: nil}
      ]

      assert {:error, %Ecto.Changeset{} = changeset} =
               Content.create_word_with_kanji(word_attrs, kanji_links)

      assert changeset.errors[:kanji_id] || changeset.errors[:text]

      # Verify word was not created
      assert Content.get_word_by_text(word_attrs.text) == nil
    end

    test "update_word/2 with valid data updates the word" do
      word = word_fixture()
      update_attrs = %{meaning: "updated meaning", difficulty: 4}

      assert {:ok, %Word{} = word} = Content.update_word(word, update_attrs)
      assert word.meaning == "updated meaning"
      assert word.difficulty == 4
    end

    test "update_word/2 with invalid data returns error changeset" do
      word = word_fixture()
      assert {:error, %Ecto.Changeset{}} = Content.update_word(word, @invalid_attrs)
      assert word.id == Content.get_word!(word.id).id
    end

    test "delete_word/1 deletes the word and associated kanji links" do
      word = word_with_kanji_fixture()
      wk_ids = Enum.map(word.word_kanjis, & &1.id)

      assert {:ok, %Word{}} = Content.delete_word(word)

      assert_raise Ecto.NoResultsError, fn ->
        Content.get_word!(word.id)
      end

      # Verify word_kanjis were also deleted
      for wk_id <- wk_ids do
        assert_raise Ecto.NoResultsError, fn ->
          Content.get_word_kanji!(wk_id)
        end
      end
    end

    test "change_word/1 returns a word changeset" do
      word = word_fixture()
      assert %Ecto.Changeset{} = Content.change_word(word)
    end
  end

  describe "word_kanjis" do
    import Medoru.ContentFixtures

    @invalid_attrs %{position: nil}

    test "list_word_kanjis/0 returns all word kanji links" do
      word = word_with_kanji_fixture()

      assert Content.list_word_kanjis()
             |> Enum.map(& &1.id)
             |> Enum.member?(List.first(word.word_kanjis).id)
    end

    test "list_kanji_for_word/1 returns kanji links for specific word" do
      word = word_with_kanji_fixture()

      wks = Content.list_kanji_for_word(word.id)
      assert length(wks) == 2
      assert List.first(wks).position == 0
      assert List.last(wks).position == 1
    end

    test "get_word_kanji!/1 returns the word kanji link with given id" do
      word = word_with_kanji_fixture()
      wk = List.first(word.word_kanjis)

      assert Content.get_word_kanji!(wk.id).id == wk.id
    end

    test "create_word_kanji/1 with valid data creates a word kanji link" do
      word = word_fixture()
      kanji = kanji_fixture()

      valid_attrs = %{
        position: 0,
        word_id: word.id,
        kanji_id: kanji.id,
        kanji_reading_id: nil
      }

      assert {:ok, %WordKanji{} = wk} = Content.create_word_kanji(valid_attrs)
      assert wk.position == 0
      assert wk.word_id == word.id
      assert wk.kanji_id == kanji.id
    end

    test "create_word_kanji/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_word_kanji(@invalid_attrs)
    end

    test "create_word_kanji/1 validates position is non-negative" do
      word = word_fixture()
      kanji = kanji_fixture()

      attrs = %{
        position: -1,
        word_id: word.id,
        kanji_id: kanji.id
      }

      assert {:error, changeset} = Content.create_word_kanji(attrs)
      assert "must be greater than or equal to 0" in errors_on(changeset).position
    end

    test "update_word_kanji/2 with valid data updates the word kanji link" do
      word = word_with_kanji_fixture()
      wk = List.first(word.word_kanjis)

      assert {:ok, %WordKanji{} = wk} = Content.update_word_kanji(wk, %{position: 5})
      assert wk.position == 5
    end

    test "delete_word_kanji/1 deletes the word kanji link" do
      word = word_with_kanji_fixture()
      wk = List.first(word.word_kanjis)

      assert {:ok, %WordKanji{}} = Content.delete_word_kanji(wk)

      assert_raise Ecto.NoResultsError, fn ->
        Content.get_word_kanji!(wk.id)
      end
    end

    test "change_word_kanji/1 returns a word kanji changeset" do
      word = word_with_kanji_fixture()
      wk = List.first(word.word_kanjis)

      assert %Ecto.Changeset{} = Content.change_word_kanji(wk)
    end
  end

  describe "lessons" do
    import Medoru.ContentFixtures

    @invalid_attrs %{title: nil, description: nil, difficulty: nil, order_index: nil}

    test "list_lessons/0 returns all lessons ordered by difficulty and order_index" do
      # Create lessons in non-sequential order
      lesson1 = lesson_fixture(%{difficulty: 5, order_index: 2})
      lesson2 = lesson_fixture(%{difficulty: 5, order_index: 1})
      lesson3 = lesson_fixture(%{difficulty: 4, order_index: 1})

      list = Content.list_lessons()
      difficulty_4_index = Enum.find_index(list, &(&1.id == lesson3.id))
      difficulty_5_first = Enum.find_index(list, &(&1.id == lesson2.id))
      difficulty_5_second = Enum.find_index(list, &(&1.id == lesson1.id))

      # N4 should come before N5
      assert difficulty_4_index < difficulty_5_first
      # Within N5, order_index 1 should come before 2
      assert difficulty_5_first < difficulty_5_second
    end

    test "list_lessons_by_difficulty/1 returns lessons filtered by difficulty" do
      n5_lesson = lesson_fixture(%{difficulty: 5})
      n4_lesson = lesson_fixture(%{difficulty: 4})

      n5_list = Content.list_lessons_by_difficulty(5)
      n4_list = Content.list_lessons_by_difficulty(4)

      assert Enum.map(n5_list, & &1.id) |> Enum.member?(n5_lesson.id)
      assert Enum.map(n4_list, & &1.id) |> Enum.member?(n4_lesson.id)
      refute Enum.map(n5_list, & &1.id) |> Enum.member?(n4_lesson.id)
    end

    test "get_lesson!/1 returns the lesson with given id" do
      lesson = lesson_fixture()
      assert Content.get_lesson!(lesson.id).id == lesson.id
    end

    test "get_lesson!/1 raises if lesson does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Content.get_lesson!(Ecto.UUID.generate())
      end
    end

    test "get_lesson_with_words!/1 returns lesson with preloaded words" do
      lesson = lesson_with_words_fixture()
      loaded = Content.get_lesson_with_words!(lesson.id)

      assert loaded.id == lesson.id
      assert is_list(loaded.lesson_words)
      assert length(loaded.lesson_words) == 2

      # Check that words are preloaded
      first_lw = List.first(loaded.lesson_words)
      assert %Word{} = first_lw.word
    end

    test "create_lesson/1 with valid data creates a lesson" do
      valid_attrs = %{
        title: "Test Lesson",
        description: "Test description",
        difficulty: 5,
        order_index: 1
      }

      assert {:ok, %Medoru.Content.Lesson{} = lesson} = Content.create_lesson(valid_attrs)
      assert lesson.title == "Test Lesson"
      assert lesson.description == "Test description"
      assert lesson.difficulty == 5
      assert lesson.order_index == 1
    end

    test "create_lesson/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_lesson(@invalid_attrs)
    end

    test "create_lesson/1 validates difficulty range" do
      attrs = %{
        title: "Test",
        description: "Test",
        difficulty: 6,
        order_index: 1
      }

      assert {:error, changeset} = Content.create_lesson(attrs)
      assert "must be less than or equal to 5" in errors_on(changeset).difficulty
    end

    test "create_lesson/1 validates order_index is non-negative" do
      attrs = %{
        title: "Test",
        description: "Test",
        difficulty: 5,
        order_index: -1
      }

      assert {:error, changeset} = Content.create_lesson(attrs)
      assert "must be greater than or equal to 0" in errors_on(changeset).order_index
    end

    test "create_lesson_with_words/2 creates lesson and word links in transaction" do
      word1 = word_fixture()
      word2 = word_fixture()

      lesson_attrs = %{
        title: "Test Lesson",
        description: "Test with words",
        difficulty: 5,
        order_index: 1
      }

      word_links = [
        %{position: 0, word_id: word1.id},
        %{position: 1, word_id: word2.id}
      ]

      assert {:ok, %Medoru.Content.Lesson{} = lesson} =
               Content.create_lesson_with_words(lesson_attrs, word_links)

      assert lesson.title == "Test Lesson"
      assert length(lesson.lesson_words) == 2

      # Verify lesson_words were created
      lws = Content.list_words_for_lesson(lesson.id)
      assert length(lws) == 2
    end

    test "create_lesson_with_words/2 rolls back on invalid word link" do
      lesson_attrs = %{
        title: "Test Lesson",
        description: "Test",
        difficulty: 5,
        order_index: 1
      }

      # Invalid word_id
      word_links = [
        %{position: 0, word_id: Ecto.UUID.generate()}
      ]

      assert {:error, %Ecto.Changeset{} = changeset} =
               Content.create_lesson_with_words(lesson_attrs, word_links)

      assert changeset.errors[:word_id]

      # Verify lesson was not created
      assert Content.list_lessons() == []
    end

    test "update_lesson/2 with valid data updates the lesson" do
      lesson = lesson_fixture()
      update_attrs = %{title: "Updated Title", description: "Updated description"}

      assert {:ok, %Medoru.Content.Lesson{} = lesson} =
               Content.update_lesson(lesson, update_attrs)

      assert lesson.title == "Updated Title"
      assert lesson.description == "Updated description"
    end

    test "update_lesson/2 with invalid data returns error changeset" do
      lesson = lesson_fixture()
      assert {:error, %Ecto.Changeset{}} = Content.update_lesson(lesson, @invalid_attrs)
      assert lesson.id == Content.get_lesson!(lesson.id).id
    end

    test "delete_lesson/1 deletes the lesson and associated word links" do
      lesson = lesson_with_words_fixture()
      lw_ids = Enum.map(lesson.lesson_words, & &1.id)

      assert {:ok, %Medoru.Content.Lesson{}} = Content.delete_lesson(lesson)

      assert_raise Ecto.NoResultsError, fn ->
        Content.get_lesson!(lesson.id)
      end

      # Verify lesson_words were also deleted
      for lw_id <- lw_ids do
        assert_raise Ecto.NoResultsError, fn ->
          Content.get_lesson_word!(lw_id)
        end
      end
    end

    test "change_lesson/1 returns a lesson changeset" do
      lesson = lesson_fixture()
      assert %Ecto.Changeset{} = Content.change_lesson(lesson)
    end
  end

  describe "lesson_words" do
    import Medoru.ContentFixtures

    @invalid_attrs %{position: nil}

    test "list_lesson_words/0 returns all lesson word links" do
      lesson = lesson_with_words_fixture()

      assert Content.list_lesson_words()
             |> Enum.map(& &1.id)
             |> Enum.member?(List.first(lesson.lesson_words).id)
    end

    test "list_words_for_lesson/1 returns word links for specific lesson" do
      lesson = lesson_with_words_fixture()

      lws = Content.list_words_for_lesson(lesson.id)
      assert length(lws) == 2
      assert List.first(lws).position == 0
      assert List.last(lws).position == 1
    end

    test "get_lesson_word!/1 returns the lesson word link with given id" do
      lesson = lesson_with_words_fixture()
      lw = List.first(lesson.lesson_words)

      assert Content.get_lesson_word!(lw.id).id == lw.id
    end

    test "create_lesson_word/1 with valid data creates a lesson word link" do
      lesson = lesson_fixture()
      word = word_fixture()

      valid_attrs = %{
        position: 0,
        lesson_id: lesson.id,
        word_id: word.id
      }

      assert {:ok, %Medoru.Content.LessonWord{} = lw} =
               Content.create_lesson_word(valid_attrs)

      assert lw.position == 0
      assert lw.lesson_id == lesson.id
      assert lw.word_id == word.id
    end

    test "create_lesson_word/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_lesson_word(@invalid_attrs)
    end

    test "create_lesson_word/1 validates position is non-negative" do
      lesson = lesson_fixture()
      word = word_fixture()

      attrs = %{
        position: -1,
        lesson_id: lesson.id,
        word_id: word.id
      }

      assert {:error, changeset} = Content.create_lesson_word(attrs)
      assert "must be greater than or equal to 0" in errors_on(changeset).position
    end

    test "update_lesson_word/2 with valid data updates the lesson word link" do
      lesson = lesson_with_words_fixture()
      lw = List.first(lesson.lesson_words)

      assert {:ok, %Medoru.Content.LessonWord{} = lw} =
               Content.update_lesson_word(lw, %{position: 5})

      assert lw.position == 5
    end

    test "delete_lesson_word/1 deletes the lesson word link" do
      lesson = lesson_with_words_fixture()
      lw = List.first(lesson.lesson_words)

      assert {:ok, %Medoru.Content.LessonWord{}} = Content.delete_lesson_word(lw)

      assert_raise Ecto.NoResultsError, fn ->
        Content.get_lesson_word!(lw.id)
      end
    end

    test "change_lesson_word/1 returns a lesson word changeset" do
      lesson = lesson_with_words_fixture()
      lw = List.first(lesson.lesson_words)

      assert %Ecto.Changeset{} = Content.change_lesson_word(lw)
    end
  end

  # Helper functions

  defp unique_kanji_char do
    index = System.unique_integer([:positive]) |> rem(100)
    <<0x3400 + index::utf8>>
  end

  defp unique_word_text do
    index = System.unique_integer([:positive]) |> rem(100)
    <<0x3400 + index::utf8>>
  end
end
