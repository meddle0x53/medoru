defmodule MedoruWeb.NotificationDropdownLive do
  @moduledoc """
  A small LiveView for the notification dropdown in the header.

  This is embedded in the layout using live_render and handles
  real-time notification updates.
  """
  use MedoruWeb, :live_view

  alias Medoru.Notifications

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    if connected?(socket) do
      # Subscribe to notifications for this user
      Phoenix.PubSub.subscribe(Medoru.PubSub, "notifications:#{user_id}")
    end

    notifications = Notifications.list_unread_notifications(user_id, limit: 5)
    unread_count = Notifications.count_unread_notifications(user_id)

    {:ok,
     socket
     |> assign(:user_id, user_id)
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-2">
      <div class="flex items-center justify-between px-4 py-2 border-b border-base-300">
        <h3 class="font-semibold text-sm">Notifications</h3>
        <%= if @unread_count > 0 do %>
          <button
            phx-click="mark_all_read"
            class="text-xs text-primary hover:underline"
          >
            Mark all read
          </button>
        <% end %>
      </div>

      <div class="max-h-80 overflow-y-auto">
        <%= if length(@notifications) == 0 do %>
          <div class="p-4 text-center text-base-content/50">
            <.icon name="hero-bell-slash" class="w-8 h-8 mx-auto mb-2 opacity-50" />
            <p class="text-sm">No new notifications</p>
          </div>
        <% else %>
          <%= for notification <- @notifications do %>
            <div
              phx-click="mark_read"
              phx-value-id={notification.id}
              class="px-4 py-3 hover:bg-base-200 cursor-pointer border-b border-base-300 last:border-b-0 transition-colors"
            >
              <div class="flex items-start gap-3">
                <div class={[
                  "flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center",
                  icon_bg_class(notification.type)
                ]}>
                  <.icon name={icon_for_type(notification.type)} class="w-4 h-4" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-base-content">
                    {notification.title}
                  </p>
                  <p class="text-xs text-base-content/70 line-clamp-2">
                    {notification.message}
                  </p>
                  <p class="text-xs text-base-content/50 mt-1">
                    {format_time(notification.inserted_at)}
                  </p>
                  <%= if notification_link(notification) do %>
                    <.link
                      navigate={notification_link(notification)}
                      class="text-xs text-primary hover:underline mt-1 inline-block"
                    >
                      {gettext("View →")}
                    </.link>
                  <% end %>
                </div>
                <%= if is_nil(notification.read_at) do %>
                  <div class="flex-shrink-0 w-2 h-2 rounded-full bg-primary mt-1"></div>
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <div class="border-t border-base-300 px-4 py-2">
        <.link navigate={~p"/notifications"} class="text-sm text-primary hover:underline">
          View all notifications
        </.link>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("mark_read", %{"id" => notification_id}, socket) do
    notification = Notifications.get_user_notification(socket.assigns.user_id, notification_id)

    if notification do
      Notifications.mark_as_read(notification)
    end

    # Refresh notifications
    notifications = Notifications.list_unread_notifications(socket.assigns.user_id, limit: 5)
    unread_count = Notifications.count_unread_notifications(socket.assigns.user_id)

    # Broadcast update to other LiveViews
    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "notifications:#{socket.assigns.user_id}",
      {:unread_count_updated, unread_count}
    )

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_all_as_read(socket.assigns.user_id)

    # Refresh notifications
    notifications = Notifications.list_unread_notifications(socket.assigns.user_id, limit: 5)

    # Broadcast update
    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "notifications:#{socket.assigns.user_id}",
      {:unread_count_updated, 0}
    )

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, 0)}
  end

  @impl true
  def handle_info({:unread_count_updated, count}, socket) do
    # Update when another LiveView updates the count
    notifications = Notifications.list_unread_notifications(socket.assigns.user_id, limit: 5)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, count)}
  end

  @impl true
  def handle_info({:new_notification, _notification}, socket) do
    # Refresh when a new notification arrives
    notifications = Notifications.list_unread_notifications(socket.assigns.user_id, limit: 5)
    unread_count = Notifications.count_unread_notifications(socket.assigns.user_id)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)}
  end

  # Helper functions

  defp icon_for_type("badge_earned"), do: "hero-trophy"
  defp icon_for_type("streak_milestone"), do: "hero-fire"
  defp icon_for_type("lesson_complete"), do: "hero-academic-cap"
  defp icon_for_type("daily_reminder"), do: "hero-calendar"
  defp icon_for_type("classroom_lesson"), do: "hero-book-open"
  defp icon_for_type("classroom_test"), do: "hero-clipboard-document-list"
  defp icon_for_type(_), do: "hero-bell"

  defp icon_bg_class("badge_earned"), do: "bg-yellow-100 text-yellow-700"
  defp icon_bg_class("streak_milestone"), do: "bg-orange-100 text-orange-700"
  defp icon_bg_class("lesson_complete"), do: "bg-green-100 text-green-700"
  defp icon_bg_class("daily_reminder"), do: "bg-blue-100 text-blue-700"
  defp icon_bg_class("classroom_lesson"), do: "bg-purple-100 text-purple-700"
  defp icon_bg_class("classroom_test"), do: "bg-indigo-100 text-indigo-700"
  defp icon_bg_class(_), do: "bg-base-200 text-base-content"

  defp notification_link(%{type: "classroom_lesson", data: %{"lesson_id" => id, "classroom_id" => cid}}) do
    ~p"/classrooms/#{cid}/custom-lessons/#{id}"
  end

  defp notification_link(%{type: "classroom_test", data: %{"test_id" => id, "classroom_id" => cid}}) do
    ~p"/classrooms/#{cid}/tests/#{id}"
  end

  defp notification_link(_), do: nil

  defp format_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
