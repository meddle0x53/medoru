defmodule MedoruWeb.ChatEmoticons do
  @moduledoc """
  Replaces common text emoticons with Unicode emoji.

  Used in chat message rendering (both server-side and client-side).
  """

  # Ordered longest-first to avoid partial matches
  @replacements [
    # Three-char patterns first
    {":'-)", "😂"},
    {":'-(", "😢"},
    {":-)", "😊"},
    {":-(", "😞"},
    {":-D", "😄"},
    {":-P", "😛"},
    {":-p", "😛"},
    {":-*", "😘"},
    {":-/", "😕"},
    {":-$", "😳"},
    {":-O", "😮"},
    {":-o", "😮"},
    {":-|", "😐"},
    {":')", "🥹"},
    {";-)", "😉"},
    {"</3", "💔"},
    # Two-char patterns
    {":)", "😊"},
    {":(", "😞"},
    {":D", "😄"},
    {":P", "😛"},
    {":p", "😛"},
    {":*", "😘"},
    {":/", "😕"},
    {":$", "😳"},
    {":O", "😮"},
    {":o", "😮"},
    {":|", "😐"},
    {";)", "😉"},
    {"<3", "❤️"},
    {"XD", "😆"},
    {"xD", "😆"},
    {"B)", "😎"},
    {"8)", "😎"}
  ]

  @doc """
  Replaces text emoticons in a string with Unicode emoji.
  """
  def replace(text) when is_binary(text) do
    Enum.reduce(@replacements, text, fn {pattern, emoji}, acc ->
      String.replace(acc, pattern, emoji)
    end)
  end

  def replace(nil), do: nil

  @doc """
  Returns the replacement list for client-side use.
  """
  def replacements, do: @replacements
end
