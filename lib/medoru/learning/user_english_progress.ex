defmodule Medoru.Learning.UserEnglishProgress do
  @moduledoc """
  Schema for tracking English-learning progress for users.

  Currently tracks which words a user has learned while learning English
  (i.e. the user is an English speaker learning Japanese vocabulary).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_english_progress" do
    belongs_to :user, Medoru.Accounts.User
    belongs_to :word, Medoru.Content.Word

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_english_progress, attrs) do
    user_english_progress
    |> cast(attrs, [:user_id, :word_id])
    |> validate_required([:user_id, :word_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:word_id)
    |> unique_constraint([:user_id, :word_id],
      name: :user_english_progress_user_id_word_id_index
    )
  end
end
