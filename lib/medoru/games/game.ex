defmodule Medoru.Games.Game do
  @moduledoc """
  Base schema for classroom games.

  Games belong to a classroom and can be of different types.
  Each type has its own configuration table.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Classrooms.Classroom

  @types ["memory_cards", "kana_memory_cards", "kana_falling", "kanji_falling", "words_falling"]
  @statuses [:draft, :published]
  @skill_levels 1..5

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "games" do
    field :name, :string
    field :type, :string
    field :status, Ecto.Enum, values: @statuses, default: :draft
    field :max_players, :integer, default: 1
    field :settings, :map, default: %{}
    field :skill_level, :integer, default: 1

    belongs_to :classroom, Classroom
    has_one :memory_card_game, Medoru.Games.MemoryCardGame
    has_one :kana_memory_card_game, Medoru.Games.KanaMemoryCardGame
    has_one :kana_falling_game, Medoru.Games.KanaFallingGame
    has_one :kanji_falling_game, Medoru.Games.KanjiFallingGame
    has_one :words_falling_game, Medoru.Games.WordsFallingGame
    has_many :memory_card_sessions, Medoru.Games.MemoryCardSession
    has_many :kana_falling_sessions, Medoru.Games.KanaFallingSession
    has_many :kanji_falling_sessions, Medoru.Games.KanjiFallingSession
    has_many :words_falling_sessions, Medoru.Games.WordsFallingSession

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :type, :status, :max_players, :settings, :skill_level, :classroom_id])
    |> validate_required([:name, :type, :status, :max_players, :skill_level, :classroom_id])
    |> validate_inclusion(:type, @types)
    |> validate_number(:max_players, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_inclusion(:skill_level, @skill_levels)
    |> foreign_key_constraint(:classroom_id)
  end

  @doc """
  Changeset for publishing a game.
  """
  def publish_changeset(game) do
    changeset(game, %{status: :published})
  end

  @doc """
  Changeset for unpublishing a game.
  """
  def unpublish_changeset(game) do
    changeset(game, %{status: :draft})
  end
end
