defmodule MedoruWeb.NotificationsLive do
  @moduledoc """
  Notifications page for users to view all their notifications.
  """
  use MedoruWeb, :live_view

  alias Medoru.Notifications
  alias Medoru.Learning.WordSets
  alias Medoru.Repo

  @per_page 10

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Medoru.PubSub, "notifications:#{user.id}")
    end

    {:ok,
     socket
     |> assign(:page_title, "Notifications")
     |> assign(:notifications, [])
     |> assign(:unread_count, 0)
     |> assign(:filter, "all")
     |> assign(:page, 1)
     |> assign(:total_count, 0)
     |> assign(:total_pages, 1)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = parse_page(params["page"])
    filter = params["filter"] || "all"
    user = socket.assigns.current_scope.current_user

    socket = load_notifications(socket, user.id, filter, page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:filter, filter)}
  end

  @impl true
  def handle_event("mark_read", %{"id" => notification_id}, socket) do
    user = socket.assigns.current_scope.current_user
    notification = Notifications.get_user_notification(user.id, notification_id)

    if notification do
      Notifications.mark_as_read(notification)
    end

    socket = load_notifications(socket, user.id, socket.assigns.filter, socket.assigns.page)
    unread_count = Notifications.count_unread_notifications(user.id)

    # Broadcast update to other LiveViews (dropdown in header)
    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "notifications:#{user.id}",
      {:unread_count_updated, unread_count}
    )

    {:noreply,
     socket
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    user = socket.assigns.current_scope.current_user

    Notifications.mark_all_as_read(user.id)

    socket = load_notifications(socket, user.id, socket.assigns.filter, socket.assigns.page)

    # Broadcast update to other LiveViews (dropdown in header)
    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "notifications:#{user.id}",
      {:unread_count_updated, 0}
    )

    {:noreply,
     socket
     |> assign(:unread_count, 0)}
  end

  @impl true
  def handle_event("delete", %{"id" => notification_id}, socket) do
    user = socket.assigns.current_scope.current_user

    notification = Notifications.get_user_notification(user.id, notification_id)

    result =
      if notification && notification.type == "word_set_share" do
        share_id = notification.data["share_id"]

        Ecto.Multi.new()
        |> Ecto.Multi.run(:delete_share, fn _repo, _changes ->
          WordSets.delete_word_set_share(share_id, user.id)
        end)
        |> Ecto.Multi.run(:delete_notification, fn _repo, _changes ->
          Notifications.delete_user_notification(user.id, notification_id)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, _} -> {:ok, nil}
          {:error, _step, error, _changes} -> {:error, error}
        end
      else
        Notifications.delete_user_notification(user.id, notification_id)
      end

    case result do
      {:ok, _} ->
        socket = load_notifications(socket, user.id, socket.assigns.filter, socket.assigns.page)
        unread_count = Notifications.count_unread_notifications(user.id)

        Phoenix.PubSub.broadcast(
          Medoru.PubSub,
          "notifications:#{user.id}",
          {:unread_count_updated, unread_count}
        )

        {:noreply,
         socket
         |> assign(:unread_count, unread_count)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete notification.")}
    end
  end

  @impl true
  def handle_event("delete_all", _params, socket) do
    user = socket.assigns.current_scope.current_user
    {:ok, count} = Notifications.delete_all_notifications(user.id)

    socket = load_notifications(socket, user.id, socket.assigns.filter, 1)

    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "notifications:#{user.id}",
      {:unread_count_updated, 0}
    )

    {:noreply,
     socket
     |> assign(:unread_count, 0)
     |> put_flash(:info, gettext("Deleted %{count} notifications.", count: count))}
  end

  @impl true
  def handle_event("filter", %{"type" => filter}, socket) do
    {:noreply, push_patch(socket, to: ~p"/notifications?#{[filter: filter, page: 1]}")}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    filter = socket.assigns.filter
    {:noreply, push_patch(socket, to: ~p"/notifications?#{[filter: filter, page: page]}")}
  end

  @impl true
  def handle_event("accept_word_set_share", %{"id" => notification_id}, socket) do
    user = socket.assigns.current_scope.current_user

    case handle_word_set_share_action(notification_id, user.id, :accept) do
      {:ok, word_set} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word set added to your collection."))
         |> push_navigate(to: ~p"/words/sets/#{word_set.id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, share_error_message(reason))}
    end
  end

  @impl true
  def handle_event("cancel_word_set_share", %{"id" => notification_id}, socket) do
    user = socket.assigns.current_scope.current_user

    case handle_word_set_share_action(notification_id, user.id, :cancel) do
      {:ok, _} ->
        socket = reload_and_broadcast(socket, user.id)
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, share_error_message(reason))}
    end
  end

  defp handle_word_set_share_action(notification_id, user_id, action) do
    notification = Notifications.get_user_notification(user_id, notification_id)

    if notification && notification.type == "word_set_share" do
      share_id = notification.data["share_id"]

      result =
        case action do
          :accept -> WordSets.accept_word_set_share(share_id, user_id)
          :cancel -> WordSets.delete_word_set_share(share_id, user_id)
        end

      if elem(result, 0) == :ok do
        Notifications.delete_user_notification(user_id, notification_id)
      end

      result
    else
      {:error, :not_found}
    end
  end

  defp reload_and_broadcast(socket, user_id) do
    socket = load_notifications(socket, user_id, socket.assigns.filter, socket.assigns.page)
    unread_count = Notifications.count_unread_notifications(user_id)

    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "notifications:#{user_id}",
      {:unread_count_updated, unread_count}
    )

    assign(socket, :unread_count, unread_count)
  end

  defp share_error_message(:not_found), do: gettext("Share request not found.")
  defp share_error_message(:not_recipient), do: gettext("This share is not for you.")
  defp share_error_message(_), do: gettext("Failed to process share request.")

  @impl true
  def handle_info({:unread_count_updated, _count}, socket) do
    user = socket.assigns.current_scope.current_user
    socket = load_notifications(socket, user.id, socket.assigns.filter, socket.assigns.page)
    unread_count = Notifications.count_unread_notifications(user.id)

    {:noreply,
     socket
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_info({:new_notification, _notification}, socket) do
    user = socket.assigns.current_scope.current_user
    socket = load_notifications(socket, user.id, socket.assigns.filter, socket.assigns.page)
    unread_count = Notifications.count_unread_notifications(user.id)

    {:noreply,
     socket
     |> assign(:unread_count, unread_count)}
  end

  defp load_notifications(socket, user_id, "unread", page) do
    notifications =
      Notifications.list_unread_notifications(user_id, page: page, per_page: @per_page)

    total_count = Notifications.count_unread_notifications(user_id)
    total_pages = max(1, ceil(total_count / @per_page))

    socket
    |> assign(:notifications, notifications)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp load_notifications(socket, user_id, "all", page) do
    notifications = Notifications.list_notifications(user_id, page: page, per_page: @per_page)
    total_count = Notifications.count_notifications(user_id)
    total_pages = max(1, ceil(total_count / @per_page))

    socket
    |> assign(:notifications, notifications)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp load_notifications(socket, user_id, type, page) do
    notifications =
      Notifications.list_notifications_by_type(user_id, type, page: page, per_page: @per_page)

    total_count = Notifications.count_notifications_by_type(user_id, type)
    total_pages = max(1, ceil(total_count / @per_page))

    socket
    |> assign(:notifications, notifications)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  # Helper functions for template

  def icon_for_type("badge_earned"), do: "hero-trophy"
  def icon_for_type("streak_milestone"), do: "hero-fire"
  def icon_for_type("lesson_complete"), do: "hero-academic-cap"
  def icon_for_type("daily_reminder"), do: "hero-calendar"
  def icon_for_type("classroom_lesson"), do: "hero-book-open"
  def icon_for_type("classroom_test"), do: "hero-clipboard-document-list"
  def icon_for_type("chat_message"), do: "hero-chat-bubble-left-ellipsis"
  def icon_for_type("chat_invite"), do: "hero-chat-bubble-left-right"
  def icon_for_type("word_set_share"), do: "hero-share"
  def icon_for_type(_), do: "hero-bell"

  def icon_bg_class("badge_earned"),
    do: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-300"

  def icon_bg_class("streak_milestone"),
    do: "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-300"

  def icon_bg_class("lesson_complete"),
    do: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300"

  def icon_bg_class("daily_reminder"),
    do: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"

  def icon_bg_class("chat_message"),
    do: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300"

  def icon_bg_class("chat_invite"),
    do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300"

  def icon_bg_class("word_set_share"),
    do: "bg-accent/20 text-accent dark:bg-accent/30 dark:text-accent"

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
