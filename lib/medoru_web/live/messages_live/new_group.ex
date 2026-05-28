defmodule MedoruWeb.MessagesLive.NewGroup do
  @moduledoc """
  LiveView for creating a new group conversation.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Chat
  alias Medoru.Encryption
  alias Medoru.Accounts

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, locale: locale, page_title: gettext("New Group Chat"))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_scope.current_user

    user_ids =
      case params["users"] do
        nil -> []
        ids -> String.split(ids, ",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      end

    # Include current user and deduplicate
    all_user_ids = Enum.uniq([current_user.id | user_ids])

    # Fetch user details
    users =
      Accounts.User
      |> Medoru.Repo.all()
      |> Medoru.Repo.preload(:profile)
      |> Enum.filter(&(&1.id in all_user_ids))

    # Get public keys for all participants (multi-device support)
    public_keys = Encryption.get_public_keys(all_user_ids)

    # Backward-compat: single most-recent key per user
    participant_public_keys =
      Map.new(public_keys, fn {uid, keys} ->
        most_recent = List.first(keys)
        {to_string(uid), Base.encode64(most_recent.public_key_spki)}
      end)

    # Multi-key format: all active keys per user
    participant_public_keys_v2 =
      Map.new(public_keys, fn {uid, keys} ->
        {to_string(uid), Enum.map(keys, &Base.encode64(&1.public_key_spki))}
      end)

    # Check if any participants are missing public keys
    missing_keys = Enum.reject(all_user_ids, &Map.has_key?(public_keys, &1))

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:user_ids, all_user_ids)
     |> assign(:participant_public_keys, participant_public_keys)
     |> assign(:participant_public_keys_v2, participant_public_keys_v2)
     |> assign(:missing_keys, missing_keys)
     |> assign(:title, "")
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("update_title", %{"title" => title}, socket) do
    {:noreply, assign(socket, :title, String.trim(title))}
  end

  @impl true
  def handle_event("register_public_key", %{"public_key" => public_key_b64}, socket) do
    current_user = socket.assigns.current_scope.current_user
    public_key_spki = Base.decode64!(public_key_b64)
    Encryption.store_public_key(current_user.id, public_key_spki)
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "create_group",
        %{"title" => title, "encrypted_keys" => encrypted_keys},
        socket
      ) do
    current_user = socket.assigns.current_scope.current_user
    user_ids = socket.assigns.user_ids
    title = String.trim(title)

    if title == "" do
      {:noreply, assign(socket, :error, gettext("Please enter a group name."))}
    else
      other_user_ids = List.delete(user_ids, current_user.id)

      case Chat.create_group_conversation(
             current_user.id,
             title,
             other_user_ids,
             encrypted_keys
           ) do
        {:ok, conversation} ->
          {:noreply, push_navigate(socket, to: ~p"/messages/#{conversation.id}")}

        {:error, _} ->
          {:noreply, assign(socket, :error, gettext("Could not create group."))}
      end
    end
  end

  # Helpers
  def user_display_name(user) do
    (user.profile && user.profile.display_name) || user.name || gettext("Anonymous")
  end

  def user_avatar(user) do
    (user.profile && user.profile.avatar) || user.avatar_url
  end
end
