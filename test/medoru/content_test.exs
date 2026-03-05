defmodule Medoru.ContentTest do
  use Medoru.DataCase

  alias Medoru.Content
  alias Medoru.Content.{Kanji, KanjiReading}

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

  # Helper to generate unique kanji characters for tests
  defp unique_kanji_char do
    index = System.unique_integer([:positive]) |> rem(100)
    <<0x3400 + index::utf8>>
  end
end
