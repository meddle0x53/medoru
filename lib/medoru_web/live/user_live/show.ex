defmodule MedoruWeb.UserLive.Show do
  @moduledoc """
  Public profile page for users.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Gamification
  alias Medoru.Learning

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
            cached_stats = Accounts.get_or_create_user_stats(user.id)
            
            # Calculate real stats from actual data
            streak = Learning.get_daily_streak(user.id)
            current_streak = if streak, do: streak.current_streak, else: 0
            longest_streak = if streak, do: streak.longest_streak, else: 0
            
            real_stats = %{
              level: cached_stats.level,
              xp: cached_stats.xp,
              current_streak: current_streak,
              longest_streak: longest_streak,
              total_kanji_learned: Learning.count_learned_kanji(user.id),
              total_words_learned: Learning.count_learned_words(user.id),
              total_tests_completed: cached_stats.total_tests_completed,
              total_duels_played: cached_stats.total_duels_played
            }
            
            user_badges = Gamification.list_user_badges(user.id)
            featured_badge = Gamification.get_featured_badge(user.id)
            
            # Get daily test status for admin reset feature
            daily_test_status = Learning.get_daily_test_status(user.id)

            {:ok,
             socket
             |> assign(:page_title, profile_title(user))
             |> assign(:user, user)
             |> assign(:profile, user.profile)
             |> assign(:stats, real_stats)
             |> assign(:user_badges, user_badges)
             |> assign(:featured_badge, featured_badge)
             |> assign(:daily_test_status, daily_test_status)}
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

  @impl true
  def handle_event("reset_daily_test", _params, socket) do
    user = socket.assigns.user
    current_user = socket.assigns.current_scope.current_user

    # Only admins can reset daily tests
    if current_user.type == "admin" do
      case Learning.delete_user_daily_test(user.id) do
        {:ok, :deleted} ->
          # Refresh daily test status
          daily_test_status = Learning.get_daily_test_status(user.id)
          
          {:noreply,
           socket
           |> assign(:daily_test_status, daily_test_status)
           |> put_flash(:info, gettext("Daily test reset successfully. User can now generate a new test."))}

        {:ok, :no_test_found} ->
          {:noreply,
           socket
           |> put_flash(:warning, gettext("No daily test found for this user today."))}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, gettext("Failed to reset daily test."))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Only admins can reset daily tests."))}
    end
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
