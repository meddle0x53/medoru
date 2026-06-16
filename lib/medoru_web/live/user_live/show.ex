defmodule MedoruWeb.UserLive.Show do
  @moduledoc """
  Public profile page for users.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Gamification
  alias Medoru.Learning
  alias Medoru.Social
  alias MedoruWeb.Presence

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
              current_streak: current_streak,
              longest_streak: longest_streak,
              total_kanji_learned: Learning.count_learned_kanji(user.id),
              total_words_learned: Learning.count_learned_words(user.id),
              total_grammar_learned: Learning.count_learned_grammar_definitions(user.id),
              total_tests_completed: cached_stats.total_tests_completed,
              total_duels_played: cached_stats.total_duels_played
            }

            user_badges = Gamification.list_user_badges(user.id)
            featured_badge = Gamification.get_featured_badge(user.id)

            # XP progress
            xp_progress = Accounts.xp_progress(cached_stats)

            # Get daily challenges status for admin reset feature
            daily_challenges_status = get_daily_challenges_status(user.id)

            # Check block status if viewing another user
            current_user =
              socket.assigns.current_scope && socket.assigns.current_scope.current_user

            is_blocked =
              if current_user do
                Social.blocked_by?(current_user.id, user.id)
              else
                false
              end

            # If the profile owner has blocked the viewer, treat as not found
            is_blocked_by_them =
              if current_user do
                Social.blocked_by?(user.id, current_user.id)
              else
                false
              end

            if is_blocked_by_them do
              {:ok,
               socket
               |> put_flash(:error, gettext("User not found."))
               |> push_navigate(to: ~p"/")}
            else
              # Check follow status and counts

              is_following =
                if current_user && current_user.id != user.id do
                  Social.following?(current_user.id, user.id)
                else
                  false
                end

              follower_count = Social.count_followers(user.id)
              following_count = Social.count_following(user.id)
              user_tags = Social.list_user_tags(user.id)

              # Check online status
              is_online = Presence.list("user_online:#{user.id}") != %{}

              if connected?(socket) do
                Phoenix.PubSub.subscribe(Medoru.PubSub, "user_online:#{user.id}")
              end

              {:ok,
               socket
               |> assign(:page_title, profile_title(user))
               |> assign(:user, user)
               |> assign(:profile, user.profile)
               |> assign(:stats, real_stats)
               |> assign(:user_badges, user_badges)
               |> assign(:featured_badge, featured_badge)
               |> assign(:xp_progress, xp_progress)
               |> assign(:daily_challenges_status, daily_challenges_status)
               |> assign(:is_blocked, is_blocked)
               |> assign(:is_following, is_following)
               |> assign(:follower_count, follower_count)
               |> assign(:following_count, following_count)
               |> assign(:user_tags, user_tags)
               |> assign(:is_online, is_online)}
            end
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
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    is_online = Presence.list("user_online:#{socket.assigns.user.id}") != %{}
    {:noreply, assign(socket, :is_online, is_online)}
  end

  @impl true
  def handle_event("block_user", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    user = socket.assigns.user

    if current_user && current_user.id != user.id do
      case Social.block_user(current_user.id, user.id) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:is_blocked, true)
           |> put_flash(:info, gettext("User blocked."))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not block user."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unblock_user", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    user = socket.assigns.user

    if current_user && current_user.id != user.id do
      Social.unblock_user(current_user.id, user.id)

      {:noreply,
       socket
       |> assign(:is_blocked, false)
       |> put_flash(:info, gettext("User unblocked."))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reset_daily_challenges", _params, socket) do
    user = socket.assigns.user
    current_user = socket.assigns.current_scope.current_user

    # Only admins can reset daily challenges
    if current_user.type == "admin" do
      {:ok, count} = Learning.reset_daily_challenges(user.id)
      daily_challenges_status = get_daily_challenges_status(user.id)

      {:noreply,
       socket
       |> assign(:daily_challenges_status, daily_challenges_status)
       |> put_flash(
         :info,
         gettext("Daily challenges reset successfully. Deleted %{count} records.", count: count)
       )}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Only admins can reset daily challenges."))}
    end
  end

  @impl true
  def handle_event("follow_user", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    user = socket.assigns.user

    if current_user && current_user.id != user.id do
      case Social.follow_user(current_user.id, user.id) do
        {:ok, _} ->
          follower_count = Social.count_followers(user.id)

          {:noreply,
           socket
           |> assign(:is_following, true)
           |> assign(:follower_count, follower_count)
           |> put_flash(:info, gettext("Now following user."))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not follow user."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unfollow_user", _params, socket) do
    current_user = socket.assigns.current_scope.current_user
    user = socket.assigns.user

    if current_user && current_user.id != user.id do
      Social.unfollow_user(current_user.id, user.id)
      follower_count = Social.count_followers(user.id)

      {:noreply,
       socket
       |> assign(:is_following, false)
       |> assign(:follower_count, follower_count)
       |> put_flash(:info, gettext("Unfollowed user."))}
    else
      {:noreply, socket}
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

  defp tag_color_classes("red"), do: "bg-red-500 text-white"
  defp tag_color_classes("orange"), do: "bg-orange-500 text-white"
  defp tag_color_classes("amber"), do: "bg-amber-500 text-white"
  defp tag_color_classes("yellow"), do: "bg-yellow-400 text-black"
  defp tag_color_classes("lime"), do: "bg-lime-500 text-white"
  defp tag_color_classes("green"), do: "bg-green-500 text-white"
  defp tag_color_classes("emerald"), do: "bg-emerald-500 text-white"
  defp tag_color_classes("teal"), do: "bg-teal-500 text-white"
  defp tag_color_classes("cyan"), do: "bg-cyan-500 text-white"
  defp tag_color_classes("sky"), do: "bg-sky-500 text-white"
  defp tag_color_classes("blue"), do: "bg-blue-500 text-white"
  defp tag_color_classes("indigo"), do: "bg-indigo-500 text-white"
  defp tag_color_classes("violet"), do: "bg-violet-500 text-white"
  defp tag_color_classes("purple"), do: "bg-purple-500 text-white"
  defp tag_color_classes("fuchsia"), do: "bg-fuchsia-500 text-white"
  defp tag_color_classes("pink"), do: "bg-pink-500 text-white"
  defp tag_color_classes("rose"), do: "bg-rose-500 text-white"
  defp tag_color_classes("slate"), do: "bg-slate-500 text-white"
  defp tag_color_classes("stone"), do: "bg-stone-500 text-white"
  defp tag_color_classes("primary"), do: "bg-primary text-primary-content"
  defp tag_color_classes("secondary"), do: "bg-secondary text-secondary-content"
  defp tag_color_classes("accent"), do: "bg-accent text-accent-content"
  defp tag_color_classes("info"), do: "bg-info text-info-content"
  defp tag_color_classes("success"), do: "bg-success text-success-content"
  defp tag_color_classes("warning"), do: "bg-warning text-warning-content"
  defp tag_color_classes("error"), do: "bg-error text-error-content"
  defp tag_color_classes(_), do: "bg-base-300 text-base-content"

  defp render_markdown(text) when is_binary(text) do
    {:ok, html, _} = Earmark.as_html(text, escape: false, smartypants: false)
    html
  end

  defp render_markdown(nil), do: ""

  defp gender_label(0), do: gettext("Male")
  defp gender_label(1), do: gettext("Female")
  defp gender_label(2), do: gettext("Other")
  defp gender_label(_), do: nil

  defp gender_icon_class(0), do: "text-blue-500"
  defp gender_icon_class(1), do: "text-pink-500"
  defp gender_icon_class(2), do: "text-purple-500"
  defp gender_icon_class(_), do: "text-base-content/50"

  defp learning_language_label("japanese"), do: gettext("Japanese")
  defp learning_language_label("english"), do: gettext("English")
  defp learning_language_label("bulgarian"), do: gettext("Bulgarian")
  defp learning_language_label(_), do: nil

  defp learning_language_text(language) do
    label = learning_language_label(language)

    if label do
      gettext("Learning %{language}", language: label)
    else
      nil
    end
  end

  defp get_daily_challenges_status(user_id) do
    challenges = Learning.get_todays_challenges(user_id)
    has_any = map_size(challenges) > 0

    %{
      has_challenges: has_any,
      completed_count: map_size(challenges),
      challenge_types: Map.keys(challenges)
    }
  end
end
