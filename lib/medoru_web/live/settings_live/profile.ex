defmodule MedoruWeb.SettingsLive.Profile do
  @moduledoc """
  Profile settings page for users to update their display name, bio, and avatar.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Gamification
  alias Phoenix.LiveView.JS

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

    # Load API tokens
    api_tokens = Accounts.list_user_api_tokens(user.id)
    api_token_count = length(api_tokens)

    {:ok,
     socket
     |> assign(:page_title, gettext("Profile Settings"))
     |> assign(:profile, profile)
     |> assign(:form, to_form(changeset))
     |> assign(:uploaded_files, [])
     |> assign(:user_badges, user_badges)
     |> assign(:featured_badge, featured_badge)
     |> assign(:api_tokens, api_tokens)
     |> assign(:api_token_count, api_token_count)
     |> assign(:new_token_plaintext, nil)
     |> assign(:new_token_form, to_form(%{"name" => "", "expires_in_days" => ""}, as: :api_token))
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
        # Get uploads directory from env var or application config
        uploads_dir =
          System.get_env("UPLOADS_DIR") ||
            Application.get_env(:medoru, :uploads_dir) ||
            "/var/opt/medoru/uploads"

        upload_dir = Path.join(uploads_dir, "avatars")

        require Logger
        Logger.info("Avatar upload: uploads_dir=#{uploads_dir}, upload_dir=#{upload_dir}")

        # Generate unique filename to avoid collisions
        ext = Path.extname(entry.client_name) |> String.downcase()
        timestamp = System.system_time(:millisecond)

        unique_name =
          "#{timestamp}_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}#{ext}"

        dest = Path.join(upload_dir, unique_name)

        # Create directory with proper error handling
        case File.mkdir_p(upload_dir) do
          :ok ->
            File.cp!(path, dest)
            Logger.info("Avatar saved successfully to: #{dest}")
            {:ok, "/uploads/avatars/#{unique_name}"}

          {:error, reason} ->
            Logger.error(
              "Failed to create avatar upload directory '#{upload_dir}': #{inspect(reason)}"
            )

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
        # Refresh the current user to update avatar in header
        user = socket.assigns.current_scope.current_user
        refreshed_user = Accounts.get_user_with_profile(user.id)
        unread_count = Medoru.Notifications.count_unread_notifications(user.id)
        locale = socket.assigns.current_scope.locale

        {:noreply,
         socket
         |> assign(:profile, updated_profile)
         |> assign(:current_scope, %{
           current_user: refreshed_user,
           unread_count: unread_count,
           locale: locale
         })
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

  @impl true
  def handle_event("create_api_token", %{"api_token" => token_params}, socket) do
    user = socket.assigns.current_scope.current_user

    case Accounts.create_api_token(user.id, token_params) do
      {:ok, _token, plaintext} ->
        api_tokens = Accounts.list_user_api_tokens(user.id)

        {:noreply,
         socket
         |> assign(:api_tokens, api_tokens)
         |> assign(:api_token_count, length(api_tokens))
         |> assign(:new_token_plaintext, plaintext)
         |> assign(:new_token_form, to_form(%{"name" => "", "expires_in_days" => ""}, as: :api_token))
         |> put_flash(:info, gettext("API token created successfully. Copy it now — you won't see it again."))}

      {:error, :limit_reached} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("You can only create up to 3 API tokens."))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to create API token."))}
    end
  end

  @impl true
  def handle_event("delete_api_token", %{"id" => token_id}, socket) do
    user = socket.assigns.current_scope.current_user

    case Accounts.delete_api_token(user.id, token_id) do
      {:ok, _} ->
        api_tokens = Accounts.list_user_api_tokens(user.id)

        {:noreply,
         socket
         |> assign(:api_tokens, api_tokens)
         |> assign(:api_token_count, length(api_tokens))
         |> assign(:new_token_plaintext, nil)
         |> put_flash(:info, gettext("API token revoked."))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, gettext("Token not found."))}
    end
  end

  @impl true
  def handle_event("dismiss_new_token", _params, socket) do
    {:noreply, assign(socket, :new_token_plaintext, nil)}
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

  # API Token helpers

  defp mask_token(token) when byte_size(token) > 8 do
    prefix = binary_part(token, 0, 4)
    suffix = binary_part(token, byte_size(token) - 4, 4)
    "#{prefix}...#{suffix}"
  end

  defp mask_token(_), do: "****"

  defp format_token_expiry(nil), do: gettext("Never expires")
  defp format_token_expiry(%DateTime{} = dt) do
    diff = DateTime.diff(dt, DateTime.utc_now(), :day)

    cond do
      diff < 0 -> gettext("Expired")
      diff == 0 -> gettext("Expires today")
      diff == 1 -> gettext("Expires tomorrow")
      diff < 30 -> gettext("Expires in %{days} days", days: diff)
      true -> gettext("Expires on %{date}", date: Calendar.strftime(dt, "%b %d, %Y"))
    end
  end

  defp format_token_last_used(nil), do: gettext("Never used")
  defp format_token_last_used(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> gettext("Just now")
      diff < 3600 -> gettext("%{m}m ago", m: div(diff, 60))
      diff < 86400 -> gettext("%{h}h ago", h: div(diff, 3600))
      diff < 604_800 -> gettext("%{d}d ago", d: div(diff, 86400))
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end
end
