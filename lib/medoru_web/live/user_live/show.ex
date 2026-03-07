defmodule MedoruWeb.UserLive.Show do
  @moduledoc """
  Public profile page for users.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts

  embed_templates "show/*"

  @impl true
  def render(assigns) do
    ~H"""
    {profile_page(assigns)}
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Accounts.get_user(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found.")
         |> push_navigate(to: ~p"/")}

      user ->
        user = Accounts.get_user_with_profile!(user.id)

        {:ok,
         socket
         |> assign(:page_title, profile_title(user))
         |> assign(:user, user)
         |> assign(:profile, user.profile)
         |> assign(:stats, user.stats)}
    end
  end

  defp profile_title(user) do
    name = user.profile && user.profile.display_name || user.name || "User"
    "#{name}'s Profile"
  end
end
