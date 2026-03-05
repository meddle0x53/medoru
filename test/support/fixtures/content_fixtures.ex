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

  # Counter for generating unique kanji characters
  # Uses private Unicode range characters to avoid conflicts
  defp unique_kanji_character do
    # Use CJK Unified Ideographs Extension A range (U+3400 to U+4DBF)
    # These are rarely used and safe for testing
    index = System.unique_integer([:positive]) |> rem(100)
    <<0x3400 + index::utf8>>
  end
end
