defmodule MedoruWeb.DashboardLive do
  @moduledoc """
  Main learning dashboard for authenticated users.
  """
  use MedoruWeb, :live_view

  alias Medoru.Accounts

  embed_templates "*.html"

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
