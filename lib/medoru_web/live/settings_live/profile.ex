defmodule MedoruWeb.SettingsLive.Profile do
  @moduledoc """
  Profile settings page for users to update their display name, bio, and avatar.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts

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

    {:ok,
     socket
     |> assign(:page_title, "Profile Settings")
     |> assign(:profile, profile)
     |> assign(:form, to_form(changeset))
     |> assign(:uploaded_files, [])
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
        # For now, we'll just use the path as a placeholder
        # In production, you'd upload to S3 or similar
        dest = Path.join(["priv/static/uploads/avatars", entry.client_name])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/avatars/#{entry.client_name}"}
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
         |> put_flash(:info, "Profile updated successfully.")
         |> push_navigate(to: ~p"/settings/profile")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  # Helper functions

  defp format_bytes(bytes) when bytes < 1_000, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_000_000, do: "#{div(bytes, 1_000)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_000_000, 1)} MB"

  defp error_to_string(:too_large), do: "File is too large (max 2MB)"
  defp error_to_string(:too_many_files), do: "You can only upload one file"
  defp error_to_string(:not_accepted), do: "File type not accepted (use JPG, PNG, or GIF)"
  defp error_to_string(err), do: to_string(err)
end
