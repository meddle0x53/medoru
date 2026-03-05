defmodule Medoru.Content.KanjiReading do
  @moduledoc """
  Schema for Kanji readings (on'yomi and kun'yomi).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "kanji_readings" do
    field :reading_type, Ecto.Enum, values: [:on, :kun]
    field :reading, :string
    field :romaji, :string
    field :usage_notes, :string

    belongs_to :kanji, Medoru.Content.Kanji

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kanji_reading, attrs) do
    kanji_reading
    |> cast(attrs, [:reading_type, :reading, :romaji, :usage_notes, :kanji_id])
    |> validate_required([:reading_type, :reading, :romaji, :kanji_id])
    |> validate_inclusion(:reading_type, [:on, :kun])
    |> validate_kana_reading()
    |> foreign_key_constraint(:kanji_id)
  end

  defp validate_kana_reading(changeset) do
    validate_change(changeset, :reading, fn :reading, value ->
      reading_type = get_field(changeset, :reading_type)

      case valid_kana?(value, reading_type) do
        true -> []
        false -> [reading: "must be valid kana (katakana for on, hiragana for kun)"]
      end
    end)
  end

  # On readings use katakana (U+30A0 to U+30FF)
  # Kun readings use hiragana (U+3040 to U+309F)
  defp valid_kana?(reading, :on) do
    String.to_charlist(reading)
    |> Enum.all?(fn cp -> cp >= 0x30A0 and cp <= 0x30FF end)
  end

  defp valid_kana?(reading, :kun) do
    String.to_charlist(reading)
    |> Enum.all?(fn cp -> cp >= 0x3040 and cp <= 0x309F end)
  end

  defp valid_kana?(_, _), do: false
end
