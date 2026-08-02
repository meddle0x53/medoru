defmodule Medoru.Learning.WordBook do
  @moduledoc """
  Schema for Word Books - user-created vocabulary card collections.

  A word book can contain up to 100 words and defines how the vocabulary
  cards look: card shape, cards per page, backgrounds, theme, and per-side
  (front/back) display configuration.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User
  alias Medoru.Classrooms.Classroom
  alias Medoru.Learning.WordBookWord

  @max_words 100
  @card_shapes ~w(square rectangle)
  @cards_per_page_options [1, 2, 4, 6]

  @meaning_locales ~w(en bg ja)
  @example_counts [1, 2, "all"]
  @side_config_keys ~w(show_word show_image show_sound show_reading show_level show_frequency
                       meanings examples example_count)
  @side_config_boolean_keys ~w(show_word show_image show_sound show_reading show_level show_frequency)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_books" do
    field :title, :string
    field :description, :string
    field :cover_image, :string
    field :theme, :string
    field :card_shape, :string, default: "rectangle"
    field :cards_per_page, :integer, default: 4
    field :front_background, :string
    field :back_background, :string
    field :front_config, :map, default: %{}
    field :back_config, :map, default: %{}
    field :word_count, :integer, default: 0

    belongs_to :user, User
    has_many :word_book_words, WordBookWord, preload_order: [asc: :position]
    has_many :words, through: [:word_book_words, :word]

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(word_book, attrs) do
    word_book
    |> cast(attrs, [
      :title,
      :description,
      :cover_image,
      :theme,
      :card_shape,
      :cards_per_page,
      :front_background,
      :back_background,
      :front_config,
      :back_config,
      :word_count,
      :user_id
    ])
    |> validate_required([:title, :user_id, :card_shape, :cards_per_page])
    |> validate_length(:title, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:card_shape, @card_shapes)
    |> validate_inclusion(:cards_per_page, @cards_per_page_options)
    |> validate_theme()
    |> validate_number(:word_count,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: @max_words
    )
    |> validate_side_config(:front_config)
    |> validate_side_config(:back_config)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for updating word count.
  """
  def update_word_count_changeset(word_book, count) do
    word_book
    |> cast(%{word_count: count}, [:word_count])
    |> validate_number(:word_count,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: @max_words
    )
  end

  @doc """
  Returns the maximum number of words allowed in a word book.
  """
  def max_words, do: @max_words

  @doc """
  Returns the allowed card shapes.
  """
  def card_shapes, do: @card_shapes

  @doc """
  Returns the allowed cards-per-page options.
  """
  def cards_per_page_options, do: @cards_per_page_options

  # Theme must be one of the shared daisyUI themes; nil/"" means "no theme".
  defp validate_theme(changeset) do
    validate_change(changeset, :theme, fn :theme, theme ->
      if theme in [nil, ""] or theme in Classroom.allowed_themes() do
        []
      else
        [theme: "is not a valid theme"]
      end
    end)
  end

  # Validates a front/back config map: only known keys with valid values.
  defp validate_side_config(changeset, field) do
    validate_change(changeset, field, fn ^field, config ->
      if is_map(config) do
        Enum.flat_map(config, fn {key, value} ->
          key = to_string(key)

          if key in @side_config_keys do
            validate_side_config_value(field, key, value)
          else
            [{field, "has unknown key #{inspect(key)}"}]
          end
        end)
      else
        [{field, "must be a map"}]
      end
    end)
  end

  defp validate_side_config_value(field, key, value) when key in @side_config_boolean_keys do
    if is_boolean(value) do
      []
    else
      [{field, "#{key} must be a boolean"}]
    end
  end

  defp validate_side_config_value(field, key, value) when key in ["meanings", "examples"] do
    if is_list(value) and Enum.all?(value, &(&1 in @meaning_locales)) do
      []
    else
      [{field, "#{key} must be a list of locales (en, bg, ja)"}]
    end
  end

  defp validate_side_config_value(field, "example_count", value) do
    if value in @example_counts do
      []
    else
      [{field, "example_count must be 1, 2, or \"all\""}]
    end
  end
end
