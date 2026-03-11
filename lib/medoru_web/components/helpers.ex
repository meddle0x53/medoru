defmodule MedoruWeb.Components.Helpers do
  @moduledoc """
  Shared helper functions for LiveView components.
  """

  @doc """
  Formats a datetime as a relative time string (e.g., "2h ago", "just now").

  ## Examples

      iex> format_relative_time(~U[2026-03-11 10:00:00Z])
      "2h ago"

      iex> format_relative_time(DateTime.utc_now())
      "just now"

  """
  def format_relative_time(datetime) when is_struct(datetime, DateTime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  def format_relative_time(nil), do: ""

  @doc """
  Returns a display name for a user, respecting privacy.

  - Shows name if available
  - If no name and viewer is the user or admin: shows email
  - If no name and viewer is someone else: shows "Anonymous"

  ## Examples

      iex> display_name(user, current_user_id, is_admin?)
      "John Doe"

      iex> display_name(user_without_name, viewer_user_id, false)
      "Anonymous"

  """
  def display_name(user, viewer_user_id, is_admin? \\ false)

  def display_name(%{profile: %{display_name: name}}, _, _) when not is_nil(name) and name != "",
    do: name

  def display_name(%{name: name}, _, _) when not is_nil(name) and name != "", do: name

  def display_name(%{id: user_id, email: email}, viewer_user_id, is_admin?)
      when user_id == viewer_user_id or is_admin?,
      do: email

  def display_name(_, _, _), do: "Anonymous"
end
