defmodule MedoruWeb.KanjiMasterLive do
  @moduledoc """
  Kanji Master — the endless kanji-writing survival game.

  Players with fewer than 50 learned kanji (and anonymous visitors) see
  the gate: an explanation with links to the kanji library, the RPG
  game, and a classroom. Eligible players get the game shell, which the
  `KanjiMaster` JS hook drives entirely client-side; only the final
  score is pushed back to the server.
  """

  use MedoruWeb, :live_view

  alias Medoru.Accounts
  alias Medoru.Challenges

  # Game constants (mirrored in the template and data attributes):
  # 15 lives, 5 yellow-stroke hint charges, 50-kanji eligibility gate.

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    user = socket.assigns.current_scope.current_user

    if user && Challenges.eligible?(user) do
      level =
        user.id |> Accounts.get_stats_by_user!() |> Map.fetch!(:xp) |> Accounts.calculate_level()

      pool = Challenges.kanji_master_pool(user)

      {:noreply,
       socket
       |> assign(:page_title, gettext("Kanji Master"))
       |> assign(:gate?, false)
       |> assign(:anonymous?, false)
       |> assign(:learned_count, Challenges.learned_kanji_count(user))
       |> assign(:pool, pool)
       |> assign(:start_coins, level)
       |> assign(:game_over, nil)
       |> assign(:record_error, nil)
       |> assign(:recorded?, false)
       |> assign(:leaderboard, Challenges.get_leaderboard())}
    else
      {:noreply,
       socket
       |> assign(:page_title, gettext("Kanji Master"))
       |> assign(:gate?, true)
       |> assign(:anonymous?, is_nil(user))
       |> assign(:learned_count, if(user, do: Challenges.learned_kanji_count(user), else: 0))
       |> assign(:pool, [])
       |> assign(:start_coins, 0)
       |> assign(:game_over, nil)
       |> assign(:record_error, nil)
       |> assign(:recorded?, false)
       |> assign(:leaderboard, Challenges.get_leaderboard())}
    end
  end

  @impl true
  def handle_event("game_over", %{"score" => score, "reason" => reason}, socket) do
    case parse_int(score) do
      {:ok, parsed} -> {:noreply, assign(socket, :game_over, %{score: parsed, reason: reason})}
      :error -> {:noreply, socket}
    end
  end

  def handle_event(
        "record_score",
        %{"score" => score, "display_mode" => mode} = params,
        socket
      ) do
    user = socket.assigns.current_scope.current_user

    with true <- not is_nil(user),
         {:ok, parsed} <- parse_int(score) do
      name = Map.get(params, "anonymous_name")

      case Challenges.record_score(user, %{
             score: parsed,
             display_mode: mode,
             anonymous_name: name
           }) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:recorded?, true)
           |> assign(:record_error, nil)
           |> assign(:leaderboard, Challenges.get_leaderboard())}

        {:error, changeset} ->
          message =
            changeset.errors
            |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
            |> Enum.join(", ")

          {:noreply, assign(socket, :record_error, message)}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp parse_int(value) when is_integer(value), do: {:ok, value}

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp parse_int(_), do: :error

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <%= if @gate? do %>
        <div class="max-w-2xl mx-auto px-4 py-12 text-center">
          <div class="w-16 h-16 mx-auto mb-6 rounded-full bg-primary/10 flex items-center justify-center">
            <.icon name="hero-pencil-square" class="w-8 h-8 text-primary" />
          </div>
          <h1 class="text-3xl font-bold text-base-content mb-4">{gettext("Kanji Master")}</h1>
          <p class="text-secondary mb-2">
            {ngettext(
              "You know %{count} kanji. You need at least 50 learned kanji to enter Kanji Master.",
              "You know %{count} kanji. You need at least 50 learned kanji to enter Kanji Master.",
              @learned_count,
              count: @learned_count
            )}
          </p>
          <p class="text-secondary mb-8">{gettext("Learn more kanji and come back!")}</p>

          <%= if @anonymous? do %>
            <p class="mb-8">
              <.link navigate={~p"/users/log-in"} class="btn btn-primary btn-sm">
                {gettext("Log in to check your progress")}
              </.link>
            </p>
          <% end %>

          <div class="flex flex-col sm:flex-row gap-3 justify-center">
            <.link navigate={~p"/kanji"} class="btn btn-outline btn-primary">
              <.icon name="hero-book-open" class="w-4 h-4 mr-1" /> {gettext("Kanji Library")}
            </.link>
            <.link navigate={~p"/the-hollow-ouroboros"} class="btn btn-outline btn-secondary">
              <.icon name="hero-bolt" class="w-4 h-4 mr-1" /> {gettext("The Hollow Ouroboros")}
            </.link>
            <.link
              navigate={~p"/classrooms/36904ffe-0f2d-4fab-b578-652752cf5c27"}
              class="btn btn-outline btn-accent"
            >
              <.icon name="hero-academic-cap" class="w-4 h-4 mr-1" /> {gettext("Practice Classroom")}
            </.link>
          </div>
        </div>
      <% else %>
        <div
          id="kanji-master-game"
          class="fixed inset-x-0 bottom-0 top-16 overflow-hidden flex flex-col bg-base-100"
          phx-hook="KanjiMaster"
          data-pool={Jason.encode!(@pool)}
          data-start-coins={@start_coins}
          data-start-lives="15"
          data-start-hints="5"
          data-question-template={gettext("Draw the kanji in %{word}（%{reading}）— %{meaning}")}
          data-question-fallback={gettext("Draw the kanji with these readings")}
          data-kun-label={gettext("KUN")}
          data-on-label={gettext("ON")}
        >
          <%!-- HUD --%>
          <div class="flex items-center justify-center gap-4 sm:gap-8 px-4 py-3 text-sm sm:text-base font-bold select-none">
            <span id="km-lives" class="inline-flex items-center gap-1 text-error">
              <span id="km-lives-count">15</span> <.icon name="hero-heart" class="w-5 h-5" />
            </span>
            <span id="km-coins" class="inline-flex items-center gap-1 text-warning">
              <span id="km-coins-count">{@start_coins}</span>
              <.icon name="hero-circle-stack" class="w-5 h-5" />
            </span>
            <span id="km-hints" class="inline-flex items-center gap-1 text-yellow-500">
              <span id="km-hints-count">5</span> <.icon name="hero-heart" class="w-5 h-5" />
            </span>
            <span class="inline-flex items-center gap-1 text-primary">
              <span id="km-score">0</span> <.icon name="hero-star" class="w-5 h-5" />
            </span>
            <button
              id="km-help-btn"
              type="button"
              class="btn btn-ghost btn-circle btn-xs"
              aria-label={gettext("How to play")}
            >
              <.icon name="hero-question-mark-circle" class="w-6 h-6" />
            </button>
          </div>

          <%!-- Question + progress --%>
          <div class="text-center px-4">
            <p id="km-question" class="text-base sm:text-lg font-japanese text-base-content"></p>
            <p id="km-readings" class="text-xs sm:text-sm text-secondary font-japanese"></p>
            <p id="km-meanings" class="text-xs sm:text-sm text-accent"></p>
            <p class="text-xs text-secondary"><span id="km-progress"></span></p>
          </div>

          <%!-- Canvas area (sized by the hook) --%>
          <div class="flex-1 min-h-0 flex items-center justify-center p-4">
            <div id="km-canvas-wrap" class="relative touch-none"></div>
          </div>

          <%!-- Shop overlay + game-over panel mount points (populated by the hook) --%>
          <div id="km-shop">
            <div
              id="km-shop-overlay"
              class="hidden fixed inset-0 z-50 flex items-center justify-center bg-base-300/70 p-4"
            >
              <div class="bg-base-100 rounded-2xl shadow-xl border border-base-300 p-4 sm:p-6 w-full max-w-sm">
                <h3 class="text-lg font-bold text-base-content mb-1">{gettext("Shop")}</h3>
                <p class="text-sm text-secondary mb-4">
                  {gettext("Coins")}: <span id="km-shop-coins" class="font-bold text-warning"></span>
                </p>
                <div class="flex flex-col gap-2">
                  <button id="km-buy-life" class="btn btn-sm w-full btn-primary">
                    {gettext("+1 life")} — <span class="km-price"></span>
                  </button>
                  <button id="km-buy-hint" class="btn btn-sm w-full btn-primary">
                    {gettext("+1 yellow stroke")} — <span class="km-price"></span>
                  </button>
                  <button id="km-buy-pack" class="btn btn-sm w-full btn-primary">
                    {gettext("Upgrade pack (3 offers, pick 1)")} — <span class="km-price"></span>
                  </button>
                  <button id="km-buy-skip" class="btn btn-sm w-full btn-primary">
                    {gettext("Skip a kanji")} — <span class="km-price"></span>
                  </button>
                </div>
                <div id="km-pack-offers" class="hidden mt-3 flex flex-col gap-2"></div>
                <div
                  id="km-skip-picker"
                  class="hidden mt-3 max-h-40 overflow-y-auto grid grid-cols-5 gap-1"
                >
                </div>
                <button id="km-shop-close" class="btn btn-ghost btn-sm w-full mt-3">
                  {gettext("Continue →")}
                </button>
              </div>
            </div>
          </div>
          <div id="km-game-over">
            <%= if @game_over do %>
              <div class="fixed inset-0 z-50 flex items-center justify-center bg-base-300/80 p-4">
                <div class="bg-base-100 rounded-2xl shadow-xl border border-base-300 p-6 w-full max-w-md text-center">
                  <%= if @game_over.reason == "exhausted" do %>
                    <h2 class="text-2xl font-bold text-success mb-2">
                      {gettext("Congratulations!")}
                    </h2>
                    <p class="text-secondary mb-4">
                      {gettext("You drew every kanji you know! Learn more kanji for a better score.")}
                    </p>
                  <% else %>
                    <h2 class="text-2xl font-bold text-error mb-2">{gettext("Game Over")}</h2>
                  <% end %>

                  <p class="text-lg mb-6">
                    {gettext("Score")}: <span class="font-bold text-primary">{@game_over.score}</span>
                  </p>

                  <%= if @recorded? do %>
                    <p class="text-success font-medium mb-4">
                      {gettext("Score recorded! Check the leaderboard:")}
                    </p>
                    <.link navigate={~p"/challenges"} class="btn btn-primary btn-sm w-full">
                      {gettext("View Leaderboard")}
                    </.link>
                  <% else %>
                    <form phx-submit="record_score" class="text-left">
                      <input type="hidden" name="score" value={@game_over.score} />
                      <label class="flex items-center gap-2 mb-2">
                        <input type="radio" name="display_mode" value="linked" checked />
                        {gettext("Link my profile")}
                      </label>
                      <label class="flex items-center gap-2 mb-2">
                        <input type="radio" name="display_mode" value="anonymous" />
                        {gettext("Anonymous")}
                      </label>
                      <input
                        type="text"
                        name="anonymous_name"
                        placeholder={gettext("Anonymous name")}
                        class="input input-bordered input-sm w-full mb-2"
                      />
                      <button type="submit" class="btn btn-primary btn-sm w-full">
                        {gettext("Record Score")}
                      </button>
                    </form>
                    <%= if @record_error do %>
                      <p class="text-error text-sm mt-2">{@record_error}</p>
                    <% end %>
                  <% end %>

                  <div class="mt-6 text-left">
                    <h4 class="text-xs font-semibold uppercase tracking-widest text-base-content/60 mb-2">
                      {gettext("Top 5")}
                    </h4>
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
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Help overlay: rules and currency meanings (toggled by the hook) --%>
          <div
            id="km-help-overlay"
            class="hidden fixed inset-0 z-50 flex items-center justify-center bg-base-300/80 p-4"
          >
            <div class="bg-base-100 rounded-2xl shadow-xl border border-base-300 p-4 sm:p-6 w-full max-w-md max-h-[80vh] overflow-y-auto">
              <h3 class="text-lg font-bold text-base-content mb-3">{gettext("How to play")}</h3>
              <p class="text-sm text-secondary mb-4">
                {gettext("Draw the kanji for the given word, stroke by stroke, in the correct order.")}
              </p>
              <ul class="text-sm text-base-content/80 space-y-2 mb-4">
                <li>
                  {gettext(
                    "Levels go from simple (1-3 strokes) to your hardest kanji, then restart with kanji you haven't drawn yet."
                  )}
                </li>
                <li>{gettext("Each cycle, a wrong stroke costs one more life.")}</li>
                <li>
                  {gettext(
                    "The shop opens every 5 kanji — spend coins on lives, hints, upgrades, or skips."
                  )}
                </li>
              </ul>
              <h4 class="text-sm font-semibold uppercase tracking-widest text-base-content/60 mb-2">
                {gettext("Currencies")}
              </h4>
              <ul class="text-sm space-y-1.5 mb-4">
                <li class="flex items-center gap-2">
                  <.icon name="hero-heart" class="w-4 h-4 text-error" />
                  {gettext(
                    "Lives — you start with 15. Lose one (or more per cycle) on a wrong stroke."
                  )}
                </li>
                <li class="flex items-center gap-2">
                  <.icon name="hero-circle-stack" class="w-4 h-4 text-warning" />
                  {gettext(
                    "Coins — you start with your site level and earn 1 per 5 kanji. Spent in the shop."
                  )}
                </li>
                <li class="flex items-center gap-2">
                  <.icon name="hero-heart" class="w-4 h-4 text-yellow-500" />
                  {gettext(
                    "Yellow strokes — spent automatically to draw a wrong stroke for you as a hint."
                  )}
                </li>
                <li class="flex items-center gap-2">
                  <.icon name="hero-star" class="w-4 h-4 text-primary" />
                  {gettext(
                    "Stars — your score. Each correct stroke earns points; upgraded strokes earn more."
                  )}
                </li>
              </ul>
              <h4 class="text-sm font-semibold uppercase tracking-widest text-base-content/60 mb-2">
                {gettext("Stroke upgrades")}
              </h4>
              <ul class="text-sm space-y-1.5 mb-4">
                <li>
                  <span class="font-bold" style="color: #3b82f6">{gettext("Blue")}</span>
                  — {gettext("2 points when drawn correctly.")}
                </li>
                <li>
                  <span class="font-bold" style="color: #a855f7">{gettext("Purple")}</span>
                  — {gettext("50/50 chance of 3 points, otherwise 1.")}
                </li>
                <li>
                  <span class="font-bold" style="color: #f97316">{gettext("Orange")}</span>
                  — {gettext("5 points, but a mistake costs one extra life.")}
                </li>
                <li>
                  <span class="font-bold" style="color: #c0c0c0">{gettext("Silver")}</span>
                  — {gettext("10% chance to win a life when drawn correctly.")}
                </li>
                <li>
                  <span class="font-bold" style="color: #06b6d4">{gettext("Cyan")}</span>
                  — {gettext("5 points, but a mistake also costs 5 coins.")}
                </li>
              </ul>
              <button id="km-help-close" type="button" class="btn btn-ghost btn-sm w-full">
                {gettext("Close")}
              </button>
            </div>
          </div>
        </div>
      <% end %>
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
