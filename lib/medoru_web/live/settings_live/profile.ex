defmodule MedoruWeb.SettingsLive.Profile do
  @moduledoc """
  Profile settings page for users to update their display name, bio, and avatar.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Gamification

  embed_templates "profile/*"

  @impl true
  def render(assigns) do
    ~H"""
    {profile(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Get or create profile
    profile =
      try do
        Accounts.get_profile_by_user!(user.id)
      rescue
        Ecto.NoResultsError ->
          # Create profile if it doesn't exist
          {:ok, profile} = Accounts.create_user_profile(user)
          profile
      end

    changeset = Accounts.change_profile(profile, %{})

    # Load user badges
    user_badges = Gamification.list_user_badges(user.id)
    featured_badge = Gamification.get_featured_badge(user.id)

    {:ok,
     socket
     |> assign(:page_title, gettext("Profile Settings"))
     |> assign(:profile, profile)
     |> assign(:form, to_form(changeset))
     |> assign(:uploaded_files, [])
     |> assign(:user_badges, user_badges)
     |> assign(:featured_badge, featured_badge)
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .gif),
       max_entries: 1,
       max_file_size: 2_000_000
     )}
  end

  @impl true
  def handle_event("validate", %{"user_profile" => profile_params}, socket) do
    changeset =
      socket.assigns.profile
      |> Accounts.change_profile(profile_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"user_profile" => profile_params}, socket) do
    profile = socket.assigns.profile

    # Handle avatar upload if present
    avatar_url =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        # Get absolute path to priv/static directory
        static_dir = Application.app_dir(:medoru, "priv/static")
        upload_dir = Path.join(static_dir, "uploads/avatars")
        dest = Path.join(upload_dir, entry.client_name)

        # Create directory with proper error handling
        case File.mkdir_p(upload_dir) do
          :ok ->
            File.cp!(path, dest)
            {:ok, "/uploads/avatars/#{entry.client_name}"}

          {:error, reason} ->
            require Logger
            Logger.error("Failed to create avatar upload directory: #{inspect(reason)}")
            {:error, "Failed to save avatar"}
        end
      end)
      |> List.first()

    # Merge avatar URL if uploaded
    profile_params =
      if avatar_url do
        Map.put(profile_params, "avatar", avatar_url)
      else
        profile_params
      end

    case Accounts.update_profile(profile, profile_params) do
      {:ok, updated_profile} ->
        {:noreply,
         socket
         |> assign(:profile, updated_profile)
         |> put_flash(:info, gettext("Profile updated successfully."))
         |> push_navigate(to: ~p"/settings/profile")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl true
  def handle_event("set_featured_badge", %{"badge_id" => badge_id}, socket) do
    user = socket.assigns.current_scope.current_user
    badge_id = String.to_integer(badge_id)

    case Gamification.set_featured_badge(user.id, badge_id) do
      {:ok, _} ->
        featured_badge = Gamification.get_featured_badge(user.id)

        {:noreply,
         socket
         |> assign(:featured_badge, featured_badge)
         |> put_flash(:info, gettext("Featured badge updated."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not set featured badge."))}
    end
  end

  @impl true
  def handle_event("remove_featured_badge", _params, socket) do
    user = socket.assigns.current_scope.current_user

    Gamification.remove_featured_badge(user.id)

    {:noreply,
     socket
     |> assign(:featured_badge, nil)
     |> put_flash(:info, gettext("Featured badge removed."))}
  end

  # Helper functions

  defp format_bytes(bytes) when bytes < 1_000, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_000_000, do: "#{div(bytes, 1_000)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_000_000, 1)} MB"

  defp error_to_string(:too_large), do: gettext("File is too large (max 2MB)")
  defp error_to_string(:too_many_files), do: gettext("You can only upload one file")

  defp error_to_string(:not_accepted),
    do: gettext("File type not accepted (use JPG, PNG, or GIF)")

  defp error_to_string(err), do: to_string(err)

  # Badge color helper
  defp badge_color_class("blue"),
    do: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"

  defp badge_color_class("green"),
    do: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300"

  defp badge_color_class("yellow"),
    do: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-300"

  defp badge_color_class("orange"),
    do: "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-300"

  defp badge_color_class("red"),
    do: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300"

  defp badge_color_class("purple"),
    do: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300"

  defp badge_color_class("pink"),
    do: "bg-pink-100 text-pink-700 dark:bg-pink-900/30 dark:text-pink-300"

  defp badge_color_class("indigo"),
    do: "bg-indigo-100 text-indigo-700 dark:bg-indigo-900/30 dark:text-indigo-300"

  defp badge_color_class("emerald"),
    do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300"

  defp badge_color_class(_),
    do: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"
end
