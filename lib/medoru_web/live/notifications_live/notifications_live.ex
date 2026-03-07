defmodule MedoruWeb.NotificationsLive do
  @moduledoc """
  Notifications page for users to view all their notifications.
  """
  use MedoruWeb, :live_view

  alias Medoru.Notifications

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    notifications = Notifications.list_notifications(user.id, limit: 50)
    unread_count = Notifications.count_unread_notifications(user.id)

    {:ok,
     socket
     |> assign(:page_title, "Notifications")
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)
     |> assign(:filter, "all")}
  end

  @impl true
  def handle_event("mark_read", %{"id" => notification_id}, socket) do
    user = socket.assigns.current_scope.current_user
    notification = Notifications.get_user_notification(user.id, notification_id)

    if notification do
      Notifications.mark_as_read(notification)
    end

    # Refresh notifications based on current filter
    notifications = list_notifications(user.id, socket.assigns.filter)
    unread_count = Notifications.count_unread_notifications(user.id)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    user = socket.assigns.current_scope.current_user

    Notifications.mark_all_as_read(user.id)

    # Refresh notifications
    notifications = list_notifications(user.id, socket.assigns.filter)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, 0)}
  end

  @impl true
  def handle_event("filter", %{"type" => filter}, socket) do
    user = socket.assigns.current_scope.current_user
    notifications = list_notifications(user.id, filter)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:filter, filter)}
  end

  defp list_notifications(user_id, "unread") do
    Notifications.list_unread_notifications(user_id, limit: 50)
  end

  defp list_notifications(user_id, "all") do
    Notifications.list_notifications(user_id, limit: 50)
  end

  defp list_notifications(user_id, type) do
    # For specific types, we'd need to add a query function
    # For now, return all and filter in memory
    Notifications.list_notifications(user_id, limit: 50)
    |> Enum.filter(&(&1.type == type))
  end

  # Helper functions for template

  def icon_for_type("badge_earned"), do: "hero-trophy"
  def icon_for_type("streak_milestone"), do: "hero-fire"
  def icon_for_type("lesson_complete"), do: "hero-academic-cap"
  def icon_for_type("daily_reminder"), do: "hero-calendar"
  def icon_for_type(_), do: "hero-bell"

  def icon_bg_class("badge_earned"),
    do: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-300"

  def icon_bg_class("streak_milestone"),
    do: "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-300"

  def icon_bg_class("lesson_complete"),
    do: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300"

  def icon_bg_class("daily_reminder"),
    do: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"

  def icon_bg_class(_), do: "bg-base-200 text-base-content"

  def format_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604_800 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%B %d, %Y")
    end
  end
end
