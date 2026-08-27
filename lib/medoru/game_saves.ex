defmodule Medoru.GameSaves do
  @moduledoc """
  The GameSaves context.

  Persists Hollow Ouroboros save blobs per user.
  """
  import Ecto.Query, warn: false

  alias Medoru.GameSaves.UserGameSave
  alias Medoru.Repo

  @doc """
  Returns the saved game data for a user, or `nil` if none exists.
  """
  def get_user_save(user_id) do
    Repo.get_by(UserGameSave, user_id: user_id)
  end

  @doc """
  Creates or updates the saved game data for a user.
  """
  def save_user_save(user_id, attrs) when is_binary(user_id) or is_integer(user_id) do
    save =
      case get_user_save(user_id) do
        nil -> %UserGameSave{user_id: user_id}
        existing -> existing
      end

    save
    |> UserGameSave.changeset(attrs)
    |> Repo.insert_or_update()
  end
end
