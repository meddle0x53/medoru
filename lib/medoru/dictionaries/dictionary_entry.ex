defmodule Medoru.Dictionaries.DictionaryEntry do
  @moduledoc """
  Schema for a single dictionary entry.

  The left side (`key`) is matched when the user types `/d <key>`.
  The right side (`value`) is inserted into the message.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dictionary_entries" do
    field :key, :string
    field :value, :string
    field :category, :string
    field :match_mode, :string, default: "prefix"

    belongs_to :dictionary, Medoru.Dictionaries.ChatDictionary

    timestamps(type: :utc_datetime)
  end

  @match_modes ["prefix", "substring"]

  def match_modes, do: @match_modes

  @doc false
  def changeset(dictionary_entry, attrs) do
    dictionary_entry
    |> cast(attrs, [:dictionary_id, :key, :value, :category, :match_mode])
    |> validate_required([:dictionary_id, :key, :value])
    |> validate_inclusion(:match_mode, @match_modes)
    |> validate_length(:key, max: 500)
    |> validate_length(:value, max: 1000)
    |> validate_length(:category, max: 50)
    |> foreign_key_constraint(:dictionary_id)
    |> update_change(:key, &String.trim/1)
    |> update_change(:value, &String.trim/1)
    |> update_change(:category, fn c -> if is_binary(c), do: String.trim(c), else: c end)
  end
end
