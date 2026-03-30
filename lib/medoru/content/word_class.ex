defmodule Medoru.Content.WordClass do
  @moduledoc """
  Schema for word classes (semantic categories).

  Examples: time, place, person, object
  Used in grammar patterns to restrict word selection.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Content.WordClassMembership

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "word_classes" do
    field :name, :string
    field :display_name, :string
    field :description, :string
    field :examples, {:array, :string}, default: []
    field :pattern, :string

    has_many :word_class_memberships, WordClassMembership
    has_many :words, through: [:word_class_memberships, :word]

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(word_class, attrs) do
    word_class
    |> cast(attrs, [:name, :display_name, :description, :examples, :pattern])
    |> validate_required([:name, :display_name])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_length(:display_name, min: 1, max: 100)
    |> validate_pattern()
    |> unique_constraint(:name)
  end

  defp validate_pattern(changeset) do
    case get_change(changeset, :pattern) do
      nil ->
        changeset

      "" ->
        changeset

      pattern ->
        case Regex.compile(pattern) do
          {:ok, _} -> changeset
          {:error, reason} -> add_error(changeset, :pattern, "Invalid regex: #{inspect(reason)}")
        end
    end
  end
end
