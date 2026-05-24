defmodule Medoru.Encryption do
  @moduledoc """
  The Encryption context.

  Manages RSA public keys for end-to-end encryption.
  Private keys are never stored on the server.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo

  alias Medoru.Encryption.UserPublicKey

  @doc """
  Gets the active public key for a user.
  Returns nil if no key exists.
  """
  def get_public_key(user_id) do
    UserPublicKey
    |> where([k], k.user_id == ^user_id and k.is_active == true)
    |> where([k], like(k.algorithm, "RSA%"))
    |> order_by([k], desc: k.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets public keys for multiple users at once.
  Returns a map of user_id => public_key record.
  """
  def get_public_keys(user_ids) when is_list(user_ids) do
    UserPublicKey
    |> where([k], k.user_id in ^user_ids and k.is_active == true)
    |> where([k], like(k.algorithm, "RSA%"))
    |> order_by([k], desc: k.inserted_at)
    |> Repo.all()
    |> Enum.reduce(%{}, fn key, acc ->
      # Only keep the first (most recent) key per user
      Map.put_new(acc, key.user_id, key)
    end)
  end

  @doc """
  Stores a new public key for a user.
  Deactivates any previous keys.
  """
  def store_public_key(user_id, spki_binary, opts \\ []) do
    algorithm = Keyword.get(opts, :algorithm, "RSA-OAEP-2048")
    version = Keyword.get(opts, :version, "v1")

    Repo.transaction(fn ->
      # Delete old keys to ensure only one key per user
      UserPublicKey
      |> where([k], k.user_id == ^user_id)
      |> Repo.delete_all()

      # Insert new key
      %UserPublicKey{}
      |> UserPublicKey.changeset(%{
        user_id: user_id,
        key_version: version,
        public_key_spki: spki_binary,
        algorithm: algorithm,
        is_active: true
      })
      |> Repo.insert!()
    end)
  end

  @doc """
  Lists all public keys for a user (for audit/history).
  """
  def list_public_keys(user_id) do
    UserPublicKey
    |> where([k], k.user_id == ^user_id)
    |> order_by([k], desc: k.inserted_at)
    |> Repo.all()
  end
end
