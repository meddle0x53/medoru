defmodule Medoru.ContentFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Medoru.Content` context.
  """

  alias Medoru.Content

  @doc """
  Generate a kanji with readings.
  """
  def kanji_fixture(attrs \\ %{}) do
    {:ok, kanji} =
      attrs
      |> Enum.into(%{
        character: unique_kanji_character(),
        meanings: ["test meaning", "another meaning"],
        stroke_count: 4,
        jlpt_level: 5,
        frequency: 100,
        radicals: ["口"],
        stroke_data: %{}
      })
      |> Content.create_kanji()

    kanji
  end

  @doc """
  Generate a kanji with readings in a single transaction.
  """
  def kanji_with_readings_fixture(kanji_attrs \\ %{}, readings_attrs \\ nil) do
    kanji_attrs =
      Enum.into(kanji_attrs, %{
        character: unique_kanji_character(),
        meanings: ["test meaning"],
        stroke_count: 4,
        jlpt_level: 5,
        frequency: 100,
        radicals: ["口"],
        stroke_data: %{}
      })

    readings_attrs =
      readings_attrs ||
        [
          %{
            reading_type: :on,
            reading: "テスト",
            romaji: "tesuto",
            usage_notes: "Test reading"
          },
          %{
            reading_type: :kun,
            reading: "てすと",
            romaji: "tesuto",
            usage_notes: "Test kun reading"
          }
        ]

    {:ok, kanji} = Content.create_kanji_with_readings(kanji_attrs, readings_attrs)

    kanji
  end

  @doc """
  Generate a kanji reading.
  """
  def kanji_reading_fixture(kanji_id, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        reading_type: :on,
        reading: "テスト",
        romaji: "tesuto",
        usage_notes: "Test reading",
        kanji_id: kanji_id
      })

    {:ok, reading} = Content.create_kanji_reading(attrs)
    reading
  end

  @doc """
  Generate a word without kanji links.
  """
  def word_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        text: unique_word_text(),
        meaning: "test meaning",
        reading: "てすと",
        difficulty: 5,
        usage_frequency: 100
      })

    {:ok, word} = Medoru.Content.create_word(attrs)
    word
  end

  @doc """
  Generate a word with kanji links in a single transaction.
  """
  def word_with_kanji_fixture(kanji_attrs \\ %{}, word_attrs \\ %{}) do
    # Create kanji with readings first
    kanji1 = kanji_with_readings_fixture(kanji_attrs)
    kanji2 = kanji_with_readings_fixture(kanji_attrs)

    reading1 = List.first(Enum.filter(kanji1.kanji_readings, &(&1.reading_type == :on)))
    reading2 = List.first(Enum.filter(kanji2.kanji_readings, &(&1.reading_type == :on)))

    word_attrs =
      Enum.into(word_attrs, %{
        text: kanji1.character <> kanji2.character,
        meaning: "test compound word",
        reading: "てすと",
        difficulty: 5,
        usage_frequency: 100
      })

    kanji_links = [
      %{position: 0, kanji_id: kanji1.id, kanji_reading_id: reading1 && reading1.id},
      %{position: 1, kanji_id: kanji2.id, kanji_reading_id: reading2 && reading2.id}
    ]

    {:ok, word} = Medoru.Content.create_word_with_kanji(word_attrs, kanji_links)
    %{word | word_kanjis: Medoru.Content.list_kanji_for_word(word.id)}
  end

  # Counter for generating unique kanji characters
  # Uses private Unicode range characters to avoid conflicts
  defp unique_kanji_character do
    # Use CJK Unified Ideographs Extension A range (U+3400 to U+4DBF)
    # These are rarely used and safe for testing
    index = System.unique_integer([:positive]) |> rem(100)
    <<0x3400 + index::utf8>>
  end

  # Generate a unique word text using test-safe Japanese characters
  defp unique_word_text do
    # Use CJK Unified Ideographs Extension A for test words
    index = System.unique_integer([:positive]) |> rem(100)
    <<0x3400 + index::utf8>>
  end

  @doc """
  Generate a lesson without kanji links.
  """
  def lesson_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "Test Lesson #{System.unique_integer([:positive])}",
        description: "Test lesson description",
        difficulty: 5,
        order_index: System.unique_integer([:positive])
      })

    {:ok, lesson} = Medoru.Content.create_lesson(attrs)
    lesson
  end

  @doc """
  Generate a lesson with word links in a single transaction.
  """
  def lesson_with_words_fixture(word_attrs \\ %{}, lesson_attrs \\ %{}) do
    # Create words first
    word1 = word_fixture(word_attrs)
    word2 = word_fixture(word_attrs)

    lesson_attrs =
      Enum.into(lesson_attrs, %{
        title: "Test Lesson #{System.unique_integer([:positive])}",
        description: "Test lesson with words",
        difficulty: 5,
        order_index: System.unique_integer([:positive])
      })

    word_links = [
      %{position: 0, word_id: word1.id},
      %{position: 1, word_id: word2.id}
    ]

    {:ok, lesson} = Medoru.Content.create_lesson_with_words(lesson_attrs, word_links)
    %{lesson | lesson_words: Medoru.Content.list_words_for_lesson(lesson.id)}
  end
end
