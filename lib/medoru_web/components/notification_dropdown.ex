defmodule MedoruWeb.NotificationDropdown do
  @moduledoc """
  LiveComponent for the notification dropdown in the header.
  """
  use MedoruWeb, :live_component

  alias Medoru.Notifications

  @impl true
  def mount(socket) do
    {:ok, assign(socket, notifications: [], loading: true)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:user_id, assigns.user_id)
      |> assign(:unread_count, assigns.unread_count)

    # Load notifications if not already loaded
    socket =
      if connected?(socket) and socket.assigns.loading do
        notifications = Notifications.list_unread_notifications(assigns.user_id, limit: 5)
        assign(socket, notifications: notifications, loading: false)
      else
        socket
      end

    {:ok, socket}
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
            phx-target={@myself}
            class="text-xs text-primary hover:underline"
          >
            Mark all read
          </button>
        <% end %>
      </div>

      <div class="max-h-80 overflow-y-auto">
        <%= if @loading do %>
          <div class="p-4 text-center text-base-content/50">
            <.icon name="hero-arrow-path" class="w-5 h-5 animate-spin" />
          </div>
        <% else %>
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
                phx-target={@myself}
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
                  </div>
                  <%= if is_nil(notification.read_at) do %>
                    <div class="flex-shrink-0 w-2 h-2 rounded-full bg-primary mt-1"></div>
                  <% end %>
                </div>
              </div>
            <% end %>
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

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)
     |> push_event("unread_count_changed", %{count: unread_count})}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_all_as_read(socket.assigns.user_id)

    # Refresh notifications
    notifications = Notifications.list_unread_notifications(socket.assigns.user_id, limit: 5)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, 0)
     |> push_event("unread_count_changed", %{count: 0})}
  end

  # Helper functions

  defp icon_for_type("badge_earned"), do: "hero-trophy"
  defp icon_for_type("streak_milestone"), do: "hero-fire"
  defp icon_for_type("lesson_complete"), do: "hero-academic-cap"
  defp icon_for_type("daily_reminder"), do: "hero-calendar"
  defp icon_for_type(_), do: "hero-bell"

  defp icon_bg_class("badge_earned"), do: "bg-yellow-100 text-yellow-700"
  defp icon_bg_class("streak_milestone"), do: "bg-orange-100 text-orange-700"
  defp icon_bg_class("lesson_complete"), do: "bg-green-100 text-green-700"
  defp icon_bg_class("daily_reminder"), do: "bg-blue-100 text-blue-700"
  defp icon_bg_class(_), do: "bg-base-200 text-base-content"

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
