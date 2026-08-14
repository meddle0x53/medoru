defmodule Medoru.Api.Cursor do
  @moduledoc """
  Cursor pagination helpers for the public API.

  Cursors are base64url-encoded JSON payloads. They are not cryptographically
  signed; for public read-only resources this is acceptable, but any sensitive
  filter state should be validated against the incoming request.
  """

  @type cursor_payload :: %{optional(String.t()) => any()}

  @doc """
  Encodes a cursor payload into a base64url string.
  """
  @spec encode(cursor_payload()) :: String.t()
  def encode(payload) when is_map(payload) do
    payload
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Decodes a cursor string back into a payload map.

  Returns `{:ok, payload}` on success or `{:error, :invalid_cursor}` otherwise.
  """
  @spec decode(String.t()) :: {:ok, cursor_payload()} | {:error, :invalid_cursor}
  def decode(cursor) when is_binary(cursor) do
    with {:ok, json} <- Base.url_decode64(cursor, padding: false),
         {:ok, payload} <- Jason.decode(json),
         true <- is_map(payload) do
      {:ok, payload}
    else
      _ -> {:error, :invalid_cursor}
    end
  end

  def decode(_), do: {:error, :invalid_cursor}
end
