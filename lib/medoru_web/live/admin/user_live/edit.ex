defmodule MedoruWeb.Admin.UserLive.Edit do
  @moduledoc """
  Admin interface for editing a user (changing type).
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Accounts.User

  embed_templates "edit/*"

  @impl true
  def render(assigns) do
    ~H"""
    {edit(assigns)}
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = Accounts.get_user_for_admin!(id)

    {:ok,
     socket
     |> assign(:page_title, gettext("Edit User - %{email}", email: user.email))
     |> assign(:user, user)
     |> assign(:user_types, User.types())
     |> assign(:current_type, user.type)}
  end

  @impl true
  def handle_event("change_type", %{"type" => type}, socket) do
    if type in User.types() do
      case Accounts.update_user_type(socket.assigns.user, type) do
        {:ok, updated_user} ->
          {:noreply,
           socket
           |> assign(:user, updated_user)
           |> assign(:current_type, updated_user.type)
           |> put_flash(:info, gettext("User type updated to %{type}.", type: type))}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, gettext("Failed to update user type."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("go_back", _, socket) do
    {:noreply,
     socket
     |> push_navigate(to: ~p"/admin/users")}
  end

  @impl true
  def handle_event("reset_progress", _, socket) do
    user = socket.assigns.user

    {:ok, stats} = Accounts.reset_user_progress(user.id)

    # Reload user to get updated stats
    updated_user = Accounts.get_user_for_admin!(user.id)

    {:noreply,
     socket
     |> assign(:user, updated_user)
     |> put_flash(
       :info,
       gettext(
         "User progress reset successfully. Deleted %{sessions} test sessions, %{progress} progress records.",
         sessions: stats.test_sessions_deleted,
         progress: stats.lesson_progress_deleted + stats.classroom_progress_deleted
       )
     )}
  end
end
