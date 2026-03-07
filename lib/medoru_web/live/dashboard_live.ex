defmodule MedoruWeb.DashboardLive do
  @moduledoc """
  Main learning dashboard for authenticated users.
  """
  use MedoruWeb, :live_view

  alias Medoru.{Accounts, Learning}

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    %{current_user: user} = socket.assigns.current_scope

    # Load fresh user data with profile
    user = Accounts.get_user_with_profile!(user.id)

    # Calculate stats dynamically from learning progress
    learning_stats = Learning.get_user_stats(user.id)

    # Get daily review stats
    daily_stats = Learning.get_daily_review_stats(user.id)

    # Merge learning stats with user stats (level, xp from gamification)
    user_stats = user.stats || %Accounts.UserStats{}

    stats = %{
      level: user_stats.level,
      xp: user_stats.xp,
      total_kanji_learned: learning_stats.total_kanji_learned,
      total_words_learned: learning_stats.total_words_learned,
      current_streak: daily_stats.current_streak,
      longest_streak: daily_stats.longest_streak
    }

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:user, user)
     |> assign(:stats, stats)
     |> assign(:profile, user.profile)
     |> assign(:daily_stats, daily_stats)}
  end

  # Components

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl shadow-sm border border-base-300 p-6 hover:shadow-md hover:border-primary/20 transition-all duration-200">
      <div class="flex items-center">
        <div class={[
          "flex-shrink-0 p-3 rounded-xl",
          stat_card_icon_bg(@color)
        ]}>
          <.icon name={"hero-#{@icon}"} class={["h-6 w-6", stat_card_icon_color(@color)]} />
        </div>
        <div class="ml-4">
          <p class="text-sm font-medium text-secondary/70">{@label}</p>
          <p class="text-2xl font-bold text-base-content">{@value}</p>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card_icon_bg("orange"), do: "bg-orange-100/80 dark:bg-orange-900/30"
  defp stat_card_icon_bg("yellow"), do: "bg-yellow-100/80 dark:bg-yellow-900/30"
  defp stat_card_icon_bg("purple"), do: "bg-purple-100/80 dark:bg-purple-900/30"
  defp stat_card_icon_bg("blue"), do: "bg-blue-100/80 dark:bg-blue-900/30"
  defp stat_card_icon_bg("green"), do: "bg-emerald-100/80 dark:bg-emerald-900/30"
  defp stat_card_icon_bg("red"), do: "bg-red-100/80 dark:bg-red-900/30"
  defp stat_card_icon_bg(_), do: "bg-base-200"

  defp stat_card_icon_color("orange"), do: "text-orange-600 dark:text-orange-400"
  defp stat_card_icon_color("yellow"), do: "text-yellow-600 dark:text-yellow-400"
  defp stat_card_icon_color("purple"), do: "text-purple-600 dark:text-purple-400"
  defp stat_card_icon_color("blue"), do: "text-blue-600 dark:text-blue-400"
  defp stat_card_icon_color("green"), do: "text-emerald-600 dark:text-emerald-400"
  defp stat_card_icon_color("red"), do: "text-red-600 dark:text-red-400"
  defp stat_card_icon_color(_), do: "text-secondary"

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :button_text, :string, required: true
  attr :button_link, :string, required: true
  attr :icon, :string, required: true

  defp action_card(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl shadow-sm border border-base-300 p-6 hover:shadow-md hover:border-primary/20 transition-all duration-200 group">
      <div class="flex items-start">
        <div class="flex-shrink-0 p-3 bg-primary/10 rounded-xl text-primary group-hover:bg-primary/20 transition-colors">
          <.icon name={"hero-#{@icon}"} class="h-6 w-6" />
        </div>
        <div class="ml-4 flex-1">
          <h3 class="text-lg font-semibold text-base-content">{@title}</h3>
          <p class="mt-1 text-secondary">{@description}</p>
          <.link
            navigate={@button_link}
            class="mt-4 inline-flex items-center px-4 py-2.5 text-sm font-medium rounded-xl text-primary-content bg-primary hover:bg-primary/90 active:scale-[0.98] transition-all shadow-sm hover:shadow"
          >
            {@button_text}
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
