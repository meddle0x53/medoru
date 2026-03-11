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
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  def format_relative_time(nil), do: ""
end
