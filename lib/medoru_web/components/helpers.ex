defmodule MedoruWeb.Components.Helpers do
  @moduledoc """
  Shared helper functions for LiveView components.
  """

  use Gettext, backend: MedoruWeb.Gettext

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
  Formats a datetime as a localized date string.
  Uses month names wrapped in gettext for localization.
  """
  def format_localized_date(datetime) when is_struct(datetime, DateTime) do
    month = gettext_month(datetime.month)
    "#{month} #{datetime.day}, #{datetime.year}"
  end

  def format_localized_date(nil), do: ""

  @doc """
  Formats a datetime as a localized short date + time string.
  """
  def format_localized_datetime(datetime) when is_struct(datetime, DateTime) do
    month = gettext_short_month(datetime.month)
    hour = String.pad_leading("#{datetime.hour}", 2, "0")
    minute = String.pad_leading("#{datetime.minute}", 2, "0")
    "#{month} #{datetime.day}, #{hour}:#{minute}"
  end

  def format_localized_datetime(nil), do: ""

  defp gettext_month(1), do: gettext("January")
  defp gettext_month(2), do: gettext("February")
  defp gettext_month(3), do: gettext("March")
  defp gettext_month(4), do: gettext("April")
  defp gettext_month(5), do: gettext("May")
  defp gettext_month(6), do: gettext("June")
  defp gettext_month(7), do: gettext("July")
  defp gettext_month(8), do: gettext("August")
  defp gettext_month(9), do: gettext("September")
  defp gettext_month(10), do: gettext("October")
  defp gettext_month(11), do: gettext("November")
  defp gettext_month(12), do: gettext("December")

  defp gettext_short_month(1), do: gettext("Jan")
  defp gettext_short_month(2), do: gettext("Feb")
  defp gettext_short_month(3), do: gettext("Mar")
  defp gettext_short_month(4), do: gettext("Apr")
  defp gettext_short_month(5), do: gettext("May")
  defp gettext_short_month(6), do: gettext("Jun")
  defp gettext_short_month(7), do: gettext("Jul")
  defp gettext_short_month(8), do: gettext("Aug")
  defp gettext_short_month(9), do: gettext("Sep")
  defp gettext_short_month(10), do: gettext("Oct")
  defp gettext_short_month(11), do: gettext("Nov")
  defp gettext_short_month(12), do: gettext("Dec")

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
