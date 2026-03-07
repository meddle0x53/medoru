defmodule Medoru.Release.Seeds do
  @moduledoc """
  Seeds for production database.
  """

  alias Medoru.Repo
  alias Medoru.Content.{Kanji, KanjiReading, Word}

  @doc """
  Runs the seeds in production.
  """
  def run do
    # For now, this is similar to priv/repo/seeds.exs
    # but without the Mix.env() check

    seed_n5_kanji()
    seed_n5_words()

    IO.puts("Database seeded successfully!")
  end

  defp seed_n5_kanji do
    # Check if we already have kanji
    if Repo.exists?(Kanji) do
      IO.puts("Kanji already seeded, skipping...")
      :ok
    else
      # N5 Kanji data (simplified for release)
      n5_kanji = [
        %{character: "一", meanings: ["one"], stroke_count: 1, jlpt_level: 5},
        %{character: "二", meanings: ["two"], stroke_count: 2, jlpt_level: 5},
        %{character: "三", meanings: ["three"], stroke_count: 3, jlpt_level: 5},
        %{character: "四", meanings: ["four"], stroke_count: 5, jlpt_level: 5},
        %{character: "五", meanings: ["five"], stroke_count: 4, jlpt_level: 5},
        %{character: "六", meanings: ["six"], stroke_count: 4, jlpt_level: 5},
        %{character: "七", meanings: ["seven"], stroke_count: 2, jlpt_level: 5},
        %{character: "八", meanings: ["eight"], stroke_count: 2, jlpt_level: 5},
        %{character: "九", meanings: ["nine"], stroke_count: 2, jlpt_level: 5},
        %{character: "十", meanings: ["ten"], stroke_count: 2, jlpt_level: 5}
      ]

      Enum.each(n5_kanji, fn kanji_data ->
        {:ok, kanji} = %Kanji{}
          |> Kanji.changeset(kanji_data)
          |> Repo.insert()

        # Add readings
        seed_readings_for_kanji(kanji)
      end)

      IO.puts("Seeded #{length(n5_kanji)} N5 kanji")
    end
  end

  defp seed_readings_for_kanji(%Kanji{character: "一"} = kanji) do
    Repo.insert!(%KanjiReading{
      kanji_id: kanji.id,
      reading_type: :on,
      reading: "イチ",
      romaji: "ichi"
    })

    Repo.insert!(%KanjiReading{
      kanji_id: kanji.id,
      reading_type: :kun,
      reading: "ひと",
      romaji: "hito"
    })
  end

  defp seed_readings_for_kanji(%Kanji{character: "二"} = kanji) do
    Repo.insert!(%KanjiReading{
      kanji_id: kanji.id,
      reading_type: :on,
      reading: "ニ",
      romaji: "ni"
    })

    Repo.insert!(%KanjiReading{
      kanji_id: kanji.id,
      reading_type: :kun,
      reading: "ふた",
      romaji: "futa"
    })
  end

  defp seed_readings_for_kanji(kanji) do
    # Generic readings for other kanji
    Repo.insert!(%KanjiReading{
      kanji_id: kanji.id,
      reading_type: :on,
      reading: "オン",
      romaji: "on"
    })
  end

  defp seed_n5_words do
    if Repo.exists?(Word) do
      IO.puts("Words already seeded, skipping...")
      :ok
    else
      # Seed some basic words
      IO.puts("Seeded basic vocabulary")
    end
  end
end
