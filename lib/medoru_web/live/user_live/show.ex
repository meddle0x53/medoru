defmodule MedoruWeb.UserLive.Show do
  @moduledoc """
  Public profile page for users.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Gamification

  embed_templates "show/*"

  @impl true
  def render(assigns) do
    ~H"""
    {profile_page(assigns)}
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Handle binary_id (UUID) casting
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        case Accounts.get_user(uuid) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, gettext("User not found."))
             |> push_navigate(to: ~p"/")}

          user ->
            user = Accounts.get_user_with_profile!(user.id)
            user_badges = Gamification.list_user_badges(user.id)
            featured_badge = Gamification.get_featured_badge(user.id)

            {:ok,
             socket
             |> assign(:page_title, profile_title(user))
             |> assign(:user, user)
             |> assign(:profile, user.profile)
             |> assign(:stats, user.stats)
             |> assign(:user_badges, user_badges)
             |> assign(:featured_badge, featured_badge)}
        end

      :error ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Invalid user ID."))
         |> push_navigate(to: ~p"/")}
    end
  end

  defp profile_title(user) do
    name = (user.profile && user.profile.display_name) || user.name || gettext("User")

    gettext("%{name}'s Profile", name: name)
  end

  # Badge color mapping for Tailwind classes
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
