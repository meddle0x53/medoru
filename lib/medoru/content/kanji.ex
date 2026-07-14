defmodule Medoru.Content.Kanji do
  @moduledoc """
  Schema for Kanji characters.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "kanji" do
    field :character, :string
    field :meanings, {:array, :string}
    field :stroke_count, :integer
    field :jlpt_level, :integer
    # Japanese school level (1-6 = Elementary, 7 = Junior High)
    field :school_level, :integer
    field :stroke_data, :map, default: %{}
    field :radicals, {:array, :string}, default: []
    field :components, {:array, :string}, default: []
    field :frequency, :integer
    # Translations: %{"bg" => %{"meanings" => [...]}, "ja" => %{"meanings" => [...]}}
    field :translations, :map, default: %{}

    has_many :kanji_readings, Medoru.Content.KanjiReading, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kanji, attrs) do
    attrs = parse_form_fields(attrs)

    kanji
    |> cast(attrs, [
      :character,
      :meanings,
      :stroke_count,
      :jlpt_level,
      :school_level,
      :stroke_data,
      :radicals,
      :components,
      :frequency,
      :translations
    ])
    |> validate_required([:character, :meanings, :stroke_count])
    |> validate_length(:character, is: 1)
    |> validate_kanji_character()
    |> validate_number(:stroke_count, greater_than: 0)
    |> validate_number(:jlpt_level, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_number(:school_level, greater_than_or_equal_to: 1, less_than_or_equal_to: 7)
    |> unique_constraint(:character)
  end

  # Parse form string values into the shapes expected by the schema.
  defp parse_form_fields(attrs) when is_map(attrs) do
    attrs
    |> parse_field_meanings("meanings")
    |> parse_field_meanings("radicals")
    |> parse_field_meanings("components")
    |> parse_translation_meanings("bg")
    |> parse_translation_meanings("ja")
    |> parse_stroke_data()
  end

  defp parse_form_fields(attrs), do: attrs

  defp parse_field_meanings(attrs, field) do
    case Map.get(attrs, field) do
      nil ->
        attrs

      meanings when is_binary(meanings) ->
        parsed =
          meanings
          |> String.split(~r/[，,、]/u)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        Map.put(attrs, field, parsed)

      _ ->
        attrs
    end
  end

  defp parse_translation_meanings(attrs, locale) do
    case get_in(attrs, ["translations", locale, "meanings"]) do
      nil ->
        attrs

      meanings when is_binary(meanings) ->
        parsed =
          meanings
          |> String.split(~r/[，,、]/u)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        put_in(attrs, ["translations", locale, "meanings"], parsed)

      _ ->
        attrs
    end
  end

  defp parse_stroke_data(attrs) when is_map(attrs) do
    case Map.get(attrs, "stroke_data") do
      nil ->
        attrs

      data when is_map(data) ->
        attrs

      "" ->
        Map.put(attrs, "stroke_data", %{})

      json when is_binary(json) ->
        case Jason.decode(json) do
          {:ok, decoded} when is_map(decoded) ->
            Map.put(attrs, "stroke_data", decoded)

          _ ->
            attrs
        end

      _ ->
        attrs
    end
  end

  defp validate_kanji_character(changeset) do
    validate_change(changeset, :character, fn :character, value ->
      case String.length(value) == 1 and kanji_character?(value) do
        true -> []
        false -> [character: "must be a valid kanji character (CJK Unified Ideographs)"]
      end
    end)
  end

  # Check if character is in CJK Unified Ideographs range:
  # - Main CJK range: U+4E00 to U+9FFF
  # - Extension A: U+3400 to U+4DBF
  defp kanji_character?(<<codepoint::utf8>>) do
    (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or
      (codepoint >= 0x3400 and codepoint <= 0x4DBF)
  end

  defp kanji_character?(_), do: false
end
