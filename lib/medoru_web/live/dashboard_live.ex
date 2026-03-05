defmodule MedoruWeb.DashboardLive do
  @moduledoc """
  Main learning dashboard for authenticated users.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts

  @impl true
  def mount(_params, _session, socket) do
    %{current_user: user} = socket.assigns.current_scope

    # Load fresh user data with profile and stats
    user = Accounts.get_user_with_profile_and_stats!(user.id)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:user, user)
     |> assign(:stats, user.stats)
     |> assign(:profile, user.profile)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Welcome Header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">
            Welcome back, {@profile.display_name || @user.name || @user.email}!
          </h1>
          <p class="mt-2 text-gray-600">
            Continue your Japanese learning journey.
          </p>
        </div>

        <%!-- Stats Grid --%>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <.stat_card
            label="Current Streak"
            value={@stats.current_streak}
            icon="fire"
            color="orange"
          />
          <.stat_card label="XP" value={@stats.xp} icon="star" color="yellow" />
          <.stat_card label="Level" value={@stats.level} icon="trophy" color="purple" />
          <.stat_card
            label="Kanji Learned"
            value={@stats.total_kanji_learned}
            icon="book-open"
            color="blue"
          />
        </div>

        <%!-- Quick Actions --%>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <.action_card
            title="Daily Review"
            description="Review kanji due for today and keep your streak going."
            button_text="Start Review"
            button_link={~p"/daily-review"}
            icon="calendar"
          />
          <.action_card
            title="Continue Learning"
            description="Pick up where you left off with your lessons."
            button_text="View Lessons"
            button_link={~p"/lessons"}
            icon="academic-cap"
          />
          <.action_card
            title="Browse Kanji"
            description="Explore the kanji database organized by JLPT level."
            button_text="Browse Kanji"
            button_link={~p"/kanji"}
            icon="book-open"
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Components

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div class="flex items-center">
        <div class={[
          "flex-shrink-0 p-3 rounded-lg",
          "bg-#{@color}-100 text-#{@color}-600"
        ]}>
          <.icon name={"hero-#{@icon}"} class="h-6 w-6" />
        </div>
        <div class="ml-4">
          <p class="text-sm font-medium text-gray-500">{@label}</p>
          <p class="text-2xl font-bold text-gray-900">{@value}</p>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :button_text, :string, required: true
  attr :button_link, :string, required: true
  attr :icon, :string, required: true

  defp action_card(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div class="flex items-start">
        <div class="flex-shrink-0 p-3 bg-indigo-100 rounded-lg text-indigo-600">
          <.icon name={"hero-#{@icon}"} class="h-6 w-6" />
        </div>
        <div class="ml-4 flex-1">
          <h3 class="text-lg font-semibold text-gray-900">{@title}</h3>
          <p class="mt-1 text-gray-600">{@description}</p>
          <.link
            navigate={@button_link}
            class="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 transition-colors"
          >
            {@button_text}
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
