defmodule MedoruWeb.DailyChallengesLive do
  @moduledoc """
  LiveView for the daily challenges page.
  Shows all available daily challenges with completion status.
  """
  use MedoruWeb, :live_view

  alias Medoru.Learning

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-base-content">{gettext("Daily Challenges")}</h1>
          <p class="mt-2 text-secondary">
            {gettext("Complete any challenge to keep your streak going!")}
          </p>
        </div>

        <%!-- Streak Banner --%>
        <div class="card bg-gradient-to-br from-primary/10 to-secondary/10 border border-primary/20 mb-8">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-4">
                <div class={[
                  "w-14 h-14 rounded-full flex items-center justify-center",
                  if(@stats.studied_today, do: "bg-success/20", else: "bg-warning/20")
                ]}>
                  <.icon
                    name={if @stats.studied_today, do: "hero-check-circle", else: "hero-fire"}
                    class={[
                      "w-8 h-8",
                      if(@stats.studied_today, do: "text-success", else: "text-warning")
                    ]}
                  />
                </div>
                <div>
                  <h2 class="text-xl font-bold text-base-content">
                    <%= if @stats.studied_today do %>
                      {gettext("Streak saved today!")} 🔥 {@stats.current_streak}
                    <% else %>
                      {gettext("Keep your streak going!")} 🔥 {@stats.current_streak}
                    <% end %>
                  </h2>
                  <p class="text-base-content/70">
                    {@stats.completed_count} / {@stats.total_challenges} {gettext("completed today")}
                  </p>
                </div>
              </div>
              <div class="text-right hidden sm:block">
                <div class="text-3xl font-bold text-base-content">{@stats.current_streak}</div>
                <div class="text-sm text-secondary">{gettext("day streak")}</div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Challenges Grid --%>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <%!-- Daily Test --%>
          <div class={[
            "card border transition-all",
            if(@stats.daily_test_completed,
              do: "border-success/30 bg-success/5",
              else: "border-base-300 bg-base-100"
            )
          ]}>
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <div class={[
                  "w-12 h-12 rounded-xl flex items-center justify-center",
                  if(@stats.daily_test_completed, do: "bg-success/20", else: "bg-primary/10")
                ]}>
                  <.icon
                    name="hero-clipboard-document-list"
                    class={[
                      "w-6 h-6",
                      if(@stats.daily_test_completed, do: "text-success", else: "text-primary")
                    ]}
                  />
                </div>
                <%= if @stats.daily_test_completed do %>
                  <span class="badge badge-success">{gettext("Completed")}</span>
                <% else %>
                  <span class="badge badge-ghost">{gettext("Available")}</span>
                <% end %>
              </div>
              <h3 class="card-title text-lg">{gettext("Daily Test")}</h3>
              <p class="text-sm text-secondary mt-2">
                {gettext("Review due words and learn new ones with a personalized test.")}
              </p>
              <div class="mt-4 flex items-center gap-2 text-sm text-base-content/70">
                <.icon name="hero-sparkles" class="w-4 h-4 text-warning" />
                <span>{gettext("Variable XP")}</span>
              </div>
              <div class="card-actions mt-4">
                <%= if @stats.daily_test_completed do %>
                  <button class="btn btn-success btn-sm w-full" disabled>
                    <.icon name="hero-check" class="w-4 h-4 mr-1" /> {gettext("Done")}
                  </button>
                <% else %>
                  <.link navigate={~p"/daily-test"} class="btn btn-primary btn-sm w-full">
                    <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Start")}
                  </.link>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Daily Kanji Test --%>
          <div class={[
            "card border transition-all",
            if(@stats.daily_kanji_completed,
              do: "border-success/30 bg-success/5",
              else: "border-base-300 bg-base-100"
            )
          ]}>
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <div class={[
                  "w-12 h-12 rounded-xl flex items-center justify-center",
                  if(@stats.daily_kanji_completed, do: "bg-success/20", else: "bg-error/10")
                ]}>
                  <.icon
                    name="hero-pencil"
                    class={[
                      "w-6 h-6",
                      if(@stats.daily_kanji_completed, do: "text-success", else: "text-error")
                    ]}
                  />
                </div>
                <%= if @stats.daily_kanji_completed do %>
                  <span class="badge badge-success">{gettext("Completed")}</span>
                <% else %>
                  <span class="badge badge-ghost">{gettext("Available")}</span>
                <% end %>
              </div>
              <h3 class="card-title text-lg">{gettext("Daily Kanji")}</h3>
              <p class="text-sm text-secondary mt-2">
                {gettext("Practice writing 10-20 learned kanji with stroke validation.")}
              </p>
              <div class="mt-4 flex items-center gap-2 text-sm text-base-content/70">
                <.icon name="hero-sparkles" class="w-4 h-4 text-warning" />
                <span>{gettext("Up to 600 XP")}</span>
              </div>
              <div class="card-actions mt-4">
                <%= if @stats.daily_kanji_completed do %>
                  <button class="btn btn-success btn-sm w-full" disabled>
                    <.icon name="hero-check" class="w-4 h-4 mr-1" /> {gettext("Done")}
                  </button>
                <% else %>
                  <.link navigate={~p"/daily-challenges/kanji"} class="btn btn-primary btn-sm w-full">
                    <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Start")}
                  </.link>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Daily Card Game --%>
          <div class={[
            "card border transition-all",
            if(@stats.daily_cards_completed,
              do: "border-success/30 bg-success/5",
              else: "border-base-300 bg-base-100"
            )
          ]}>
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <div class={[
                  "w-12 h-12 rounded-xl flex items-center justify-center",
                  if(@stats.daily_cards_completed, do: "bg-success/20", else: "bg-accent/10")
                ]}>
                  <.icon
                    name="hero-squares-2x2"
                    class={[
                      "w-6 h-6",
                      if(@stats.daily_cards_completed, do: "text-success", else: "text-accent")
                    ]}
                  />
                </div>
                <%= if @stats.daily_cards_completed do %>
                  <span class="badge badge-success">{gettext("Completed")}</span>
                <% else %>
                  <span class="badge badge-ghost">{gettext("Available")}</span>
                <% end %>
              </div>
              <h3 class="card-title text-lg">{gettext("Daily Cards")}</h3>
              <p class="text-sm text-secondary mt-2">
                {gettext("Match word pairs in a memory game. Type meanings to win!")}
              </p>
              <div class="mt-4 flex items-center gap-2 text-sm text-base-content/70">
                <.icon name="hero-sparkles" class="w-4 h-4 text-warning" />
                <span>{gettext("Up to 300 XP")}</span>
              </div>
              <div class="card-actions mt-4">
                <%= if @stats.daily_cards_completed do %>
                  <button class="btn btn-success btn-sm w-full" disabled>
                    <.icon name="hero-check" class="w-4 h-4 mr-1" /> {gettext("Done")}
                  </button>
                <% else %>
                  <.link navigate={~p"/daily-challenges/cards"} class="btn btn-primary btn-sm w-full">
                    <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Start")}
                  </.link>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Daily Component Hunt --%>
          <div class={[
            "card border transition-all",
            if(@stats.daily_radical_hunt_completed,
              do: "border-success/30 bg-success/5",
              else: "border-base-300 bg-base-100"
            )
          ]}>
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <div class={[
                  "w-12 h-12 rounded-xl flex items-center justify-center",
                  if(@stats.daily_radical_hunt_completed, do: "bg-success/20", else: "bg-warning/10")
                ]}>
                  <.icon
                    name="hero-magnifying-glass"
                    class={[
                      "w-6 h-6",
                      if(@stats.daily_radical_hunt_completed,
                        do: "text-success",
                        else: "text-warning"
                      )
                    ]}
                  />
                </div>
                <%= if @stats.daily_radical_hunt_completed do %>
                  <span class="badge badge-success">{gettext("Completed")}</span>
                <% else %>
                  <span class="badge badge-ghost">{gettext("Available")}</span>
                <% end %>
              </div>
              <h3 class="card-title text-lg">{gettext("Daily Component Hunt")}</h3>
              <p class="text-sm text-secondary mt-2">
                {gettext("Type kanji containing a chosen component before time runs out.")}
              </p>
              <div class="mt-4 flex items-center gap-2 text-sm text-base-content/70">
                <.icon name="hero-sparkles" class="w-4 h-4 text-warning" />
                <span>{gettext("30 XP per kanji + 50 XP")}</span>
              </div>
              <div class="card-actions mt-4">
                <%= if @stats.daily_radical_hunt_completed do %>
                  <button class="btn btn-success btn-sm w-full" disabled>
                    <.icon name="hero-check" class="w-4 h-4 mr-1" /> {gettext("Done")}
                  </button>
                <% else %>
                  <.link
                    navigate={~p"/daily-challenges/radical-hunt"}
                    class="btn btn-primary btn-sm w-full"
                  >
                    <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Start")}
                  </.link>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <%!-- Hollow Ouroboros Run --%>
        <div class="mt-6 flex justify-center">
          <div class={[
            "card border transition-all w-full md:w-[calc(50%-0.75rem)] lg:w-[calc(25%-1.125rem)]",
            if(@stats.ouroboros_run_completed,
              do: "border-success/30 bg-success/5",
              else: "border-base-300 bg-base-100"
            )
          ]}>
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <div class={[
                  "w-12 h-12 rounded-xl flex items-center justify-center",
                  if(@stats.ouroboros_run_completed, do: "bg-success/20", else: "bg-secondary/10")
                ]}>
                  <.icon
                    name="hero-bolt"
                    class={[
                      "w-6 h-6",
                      if(@stats.ouroboros_run_completed, do: "text-success", else: "text-secondary")
                    ]}
                  />
                </div>
                <%= if @stats.ouroboros_run_completed do %>
                  <span class="badge badge-success">{gettext("Completed")}</span>
                <% else %>
                  <span class="badge badge-ghost">{gettext("Available")}</span>
                <% end %>
              </div>
              <h3 class="card-title text-lg">{gettext("RPG Game Run")}</h3>
              <p class="text-sm text-secondary mt-2">
                {gettext("Play The RPG Game. Earn site XP from Ouro Essence gained.")}
              </p>
              <div class="mt-4 flex items-center gap-2 text-sm text-base-content/70">
                <.icon name="hero-sparkles" class="w-4 h-4 text-warning" />
                <span>{gettext("100 XP per Ouro Essence")}</span>
              </div>
              <div class="card-actions mt-4">
                <%= if @stats.ouroboros_run_completed do %>
                  <button class="btn btn-success btn-sm w-full" disabled>
                    <.icon name="hero-check" class="w-4 h-4 mr-1" /> {gettext("Done")}
                  </button>
                <% else %>
                  <.link
                    navigate={~p"/the-hollow-ouroboros?daily_challenge=1"}
                    class="btn btn-primary btn-sm w-full"
                  >
                    <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Start")}
                  </.link>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    stats = Learning.get_daily_challenge_stats(user.id)

    {:ok,
     socket
     |> assign(:page_title, gettext("Daily Challenges"))
     |> assign(:stats, stats)}
  end
end
