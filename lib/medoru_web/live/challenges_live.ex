defmodule MedoruWeb.ChallengesLive do
  @moduledoc """
  Learner challenges — permanent challenges (unlike daily challenges).

  Currently one challenge: Kanji Master. The card shows the top 5
  leaderboard and the current viewer's rank (even outside the top 5).
  """

  use MedoruWeb, :live_view

  alias Medoru.Challenges

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    my_rank = if user, do: Challenges.get_rank_and_score(user.id), else: nil

    {:ok,
     socket
     |> assign(:page_title, gettext("Learner Challenges"))
     |> assign(:leaderboard, Challenges.get_leaderboard())
     |> assign(:my_rank, my_rank)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">{gettext("Learner Challenges")}</h1>
          <p class="mt-2 text-secondary">
            {gettext("Permanent challenges. Compete with other learners for the top spots!")}
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="card border border-base-300 bg-base-100 transition-all">
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <div class="w-12 h-12 rounded-xl flex items-center justify-center bg-primary/10">
                  <.icon name="hero-pencil-square" class="w-6 h-6 text-primary" />
                </div>
                <span class="badge badge-ghost">{gettext("Available")}</span>
              </div>

              <h3 class="card-title text-lg">{gettext("Kanji Master")}</h3>
              <p class="text-sm text-secondary mt-2">
                {gettext("An endless kanji-writing survival game. 15 lives — how far can you go?")}
              </p>

              <%= if @my_rank do %>
                <p class="mt-3 text-sm text-base-content/70">
                  {gettext("Your rank: #%{rank}", rank: @my_rank.rank)} · {gettext("Best: %{score}",
                    score: @my_rank.score
                  )}
                </p>
              <% end %>

              <div class="mt-4">
                <h4 class="text-xs font-semibold uppercase tracking-widest text-base-content/60 mb-2">
                  {gettext("Top 5")}
                </h4>
                <%= if @leaderboard == [] do %>
                  <p class="text-sm text-secondary">{gettext("No scores yet. Be the first!")}</p>
                <% else %>
                  <ol class="space-y-1.5">
                    <li
                      :for={{entry, index} <- Enum.with_index(@leaderboard, 1)}
                      class="flex items-center gap-2 text-sm"
                    >
                      <span class="w-6 text-right font-bold text-base-content/50">{index}</span>
                      <%= if entry.display_mode == "linked" do %>
                        <.link
                          navigate={~p"/users/#{entry.user_id}"}
                          class="text-primary hover:underline font-medium truncate"
                        >
                          {leaderboard_name(entry)}
                        </.link>
                      <% else %>
                        <span class="font-medium truncate">{entry.anonymous_name}</span>
                      <% end %>
                      <span class="ml-auto font-bold text-base-content">{entry.score}</span>
                    </li>
                  </ol>
                <% end %>
              </div>

              <div class="card-actions mt-4">
                <.link navigate={~p"/challenges/kanji-master"} class="btn btn-primary btn-sm w-full">
                  <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Start")}
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp leaderboard_name(entry) do
    case entry.user do
      %{profile: %{display_name: name}} when name not in [nil, ""] -> name
      %{name: name} when name not in [nil, ""] -> name
      _ -> gettext("Learner")
    end
  end
end
