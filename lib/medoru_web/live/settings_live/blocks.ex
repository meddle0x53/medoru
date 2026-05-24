defmodule MedoruWeb.SettingsLive.Blocks do
  @moduledoc """
  LiveView for managing blocked users.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Social

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    current_user = socket.assigns.current_scope.current_user

    if current_user do
      blocked_users = Social.list_blocked_users(current_user.id)

      {:ok,
       socket
       |> assign(:locale, locale)
       |> assign(:blocked_users, blocked_users)
       |> assign(:page_title, gettext("Blocked Users"))}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event("unblock", %{"id" => blocked_id}, socket) do
    current_user = socket.assigns.current_scope.current_user

    Social.unblock_user(current_user.id, blocked_id)

    blocked_users = Social.list_blocked_users(current_user.id)

    {:noreply,
     socket
     |> assign(:blocked_users, blocked_users)
     |> put_flash(:info, gettext("User unblocked."))}
  end

  # Helpers
  def blocked_user_name(user_block) do
    user = user_block.blocked
    (user.profile && user.profile.display_name) || user.name || gettext("Anonymous")
  end

  def blocked_user_avatar(user_block) do
    user = user_block.blocked
    (user.profile && user.profile.avatar) || user.avatar_url
  end
end
