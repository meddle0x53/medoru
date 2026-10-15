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

  import Ecto.Query

  alias Medoru.Accounts
  alias Medoru.Challenges
  alias Medoru.Content.Kanji
  alias Medoru.Repo

  # Game constants (mirrored in the template and data attributes):
  # 20 lives, 5 yellow-stroke hint charges, 50-kanji eligibility gate.

  # Boss kanji for Kanji Master: whole-dictionary rarities (22+ strokes)
  # the player likely hasn't learned, serialized exactly like the pool.
  @boss_min_strokes 22

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    user = socket.assigns.current_scope.current_user

    if socket.assigns.live_action in [:n5, :n4] do
      # N5/N4 modes: no gate — anyone (including anonymous visitors) plays,
      # and everyone starts with the same 10 coins.
      mode = Atom.to_string(socket.assigns.live_action)

      page_title =
        if socket.assigns.live_action == :n4,
          do: gettext("Kanji Master N4"),
          else: gettext("Kanji Master N5")

      pool =
        if socket.assigns.live_action == :n4,
          do: Challenges.kanji_master_n4_pool(),
          else: Challenges.kanji_master_n5_pool()

      {:noreply,
       socket
       |> assign(:page_title, page_title)
       |> assign(:mode, mode)
       |> assign(:gate?, false)
       |> assign(:anonymous?, is_nil(user))
       |> assign(:learned_count, if(user, do: Challenges.learned_kanji_count(user), else: 0))
       |> assign(:pool, pool)
       |> assign(:boss_pool, boss_pool())
       |> assign(:start_coins, 10)
       |> assign(:game_over, nil)
       |> assign(:record_error, nil)
       |> assign(:recorded?, false)
       |> assign(:leaderboard, Challenges.get_leaderboard(mode))}
    else
      if user && Challenges.eligible?(user) do
        level =
          user.id
          |> Accounts.get_stats_by_user!()
          |> Map.fetch!(:xp)
          |> Accounts.calculate_level()

        pool = Challenges.kanji_master_pool(user)
        boss_pool = boss_pool()

        {:noreply,
         socket
         |> assign(:page_title, gettext("Kanji Master"))
         |> assign(:mode, "master")
         |> assign(:gate?, false)
         |> assign(:anonymous?, false)
         |> assign(:learned_count, Challenges.learned_kanji_count(user))
         |> assign(:pool, pool)
         |> assign(:boss_pool, boss_pool)
         |> assign(:start_coins, level)
         |> assign(:game_over, nil)
         |> assign(:record_error, nil)
         |> assign(:recorded?, false)
         |> assign(:leaderboard, Challenges.get_leaderboard())}
      else
        {:noreply,
         socket
         |> assign(:page_title, gettext("Kanji Master"))
         |> assign(:mode, "master")
         |> assign(:gate?, true)
         |> assign(:anonymous?, is_nil(user))
         |> assign(:learned_count, if(user, do: Challenges.learned_kanji_count(user), else: 0))
         |> assign(:pool, [])
         |> assign(:boss_pool, [])
         |> assign(:start_coins, 0)
         |> assign(:game_over, nil)
         |> assign(:record_error, nil)
         |> assign(:recorded?, false)
         |> assign(:leaderboard, Challenges.get_leaderboard())}
      end
    end
  end

  @impl true
  def handle_event("game_over", %{"score" => score, "reason" => reason} = params, socket) do
    case parse_int(score) do
      {:ok, parsed} ->
        failed =
          case params["failed_kanji"] do
            char when is_binary(char) ->
              known =
                socket.assigns.pool ++ socket.assigns.boss_pool

              if char in Enum.map(known, & &1.character), do: char, else: nil

            _ ->
              nil
          end

        {:noreply,
         assign(socket, :game_over, %{score: parsed, reason: reason, failed_kanji: failed})}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "record_score",
        %{"score" => score} = params,
        socket
      ) do
    user = socket.assigns.current_scope.current_user
    mode = socket.assigns.mode || "master"

    with {:ok, parsed} <- parse_int(score) do
      result =
        if user do
          Challenges.record_score(user, %{
            score: parsed,
            display_mode: Map.get(params, "display_mode", "linked"),
            anonymous_name: Map.get(params, "anonymous_name"),
            mode: mode
          })
        else
          # Anonymous recording — only possible in N5 mode. The name is
          # required, trimmed and capped at 12 characters (validated in the
          # changeset as well).
          Challenges.record_anonymous_score(%{
            score: parsed,
            anonymous_name: Map.get(params, "anonymous_name"),
            mode: mode
          })
        end

      case result do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:recorded?, true)
           |> assign(:record_error, nil)
           |> assign(:leaderboard, Challenges.get_leaderboard(mode))}

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

  # Up to 2 random whole-dictionary kanji with 22+ strokes and usable stroke
  # data (fallback: the highest-stroke kanji available). Serialized exactly
  # like kanji_master_pool/1 so the hook can draw them with no word (the
  # question falls back to the readings/meanings template).
  defp boss_pool do
    drawable =
      from(k in Kanji,
        where:
          not is_nil(k.stroke_data) and fragment("?->'strokes' != '[]'::jsonb", k.stroke_data)
      )

    kanji =
      Repo.all(
        from k in drawable,
          where: k.stroke_count >= @boss_min_strokes,
          order_by: fragment("RANDOM()"),
          limit: 2
      )

    kanji =
      if kanji == [] do
        Repo.all(
          from k in drawable,
            order_by: [desc: k.stroke_count],
            limit: 2
        )
      else
        kanji
      end

    Enum.map(kanji, fn k ->
      %{
        character: k.character,
        stroke_data: k.stroke_data,
        stroke_count: k.stroke_count,
        word: nil,
        kun: [],
        on: [],
        meanings: (k.meanings || []) |> Enum.take(2)
      }
    end)
  end

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
          data-boss-pool={Jason.encode!(@boss_pool)}
          data-start-coins={@start_coins}
          data-start-lives="20"
          data-start-hints="5"
          data-question-template={gettext("Draw the kanji in %{word}（%{reading}）— %{meaning}")}
          data-question-fallback={gettext("Draw the kanji with these readings")}
          data-kun-label={gettext("KUN")}
          data-on-label={gettext("ON")}
          data-status-stroke-label={gettext("Stroke %{n}")}
          data-status-none-label={gettext("No upgrade")}
          data-perfect-label={gettext("Perfect!")}
          data-boss-label={gettext("Boss")}
          data-upgrade-names={
            Jason.encode!(%{
              "blue" => gettext("Blue"),
              "purple" => gettext("Purple"),
              "orange" => gettext("Orange"),
              "silver" => gettext("Silver"),
              "cyan" => gettext("Cyan"),
              "momo" => gettext("Momo")
            })
          }
        >
          <%!-- HUD --%>
          <div class="flex items-center justify-center gap-2 sm:gap-8 px-2 sm:px-4 py-2 sm:py-3 text-xs sm:text-base font-bold select-none w-full max-w-full">
            <span id="km-lives" class="inline-flex items-center gap-1 text-error">
              <span id="km-lives-count">20</span>
              <.icon name="hero-heart" class="w-4 h-4 sm:w-5 sm:h-5" />
            </span>
            <span id="km-coins" class="inline-flex items-center gap-1 text-warning">
              <span id="km-coins-count">{@start_coins}</span>
              <.icon name="hero-circle-stack" class="w-4 h-4 sm:w-5 sm:h-5" />
            </span>
            <span id="km-hints" class="inline-flex items-center gap-1 text-yellow-500">
              <span id="km-hints-count">5</span>
              <.icon name="hero-heart" class="w-4 h-4 sm:w-5 sm:h-5" />
            </span>
            <span class="inline-flex items-center gap-1 text-primary">
              <span id="km-score">0</span> <.icon name="hero-star" class="w-4 h-4 sm:w-5 sm:h-5" />
            </span>
            <button
              id="km-status-btn"
              type="button"
              class="btn btn-ghost btn-circle btn-xs"
              aria-label={gettext("Upgrade status")}
            >
              <.icon name="hero-queue-list" class="w-5 h-5 sm:w-6 sm:h-6" />
            </button>
            <button
              id="km-help-btn"
              type="button"
              class="btn btn-ghost btn-circle btn-xs"
              aria-label={gettext("How to play")}
            >
              <.icon name="hero-question-mark-circle" class="w-5 h-5 sm:w-6 sm:h-6" />
            </button>
            <button
              id="km-give-up-btn"
              type="button"
              class="btn btn-ghost btn-circle btn-xs text-error"
              aria-label={gettext("Give up")}
              data-give-up-confirm={
                gettext(
                  "Are you sure you want to give up? Your run will end and you can record your score."
                )
              }
            >
              <.icon name="hero-flag" class="w-5 h-5 sm:w-6 sm:h-6" />
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
          <p
            id="km-boss-label"
            class="hidden text-center text-sm font-bold uppercase tracking-widest pb-2"
          >
            {gettext("Boss")}
          </p>

          <%!-- Shop overlay + game-over panel mount points (populated by the hook) --%>
          <div id="km-shop" data-sold-out-label={gettext("Sold out")}>
            <div
              id="km-shop-overlay"
              class="hidden fixed inset-0 z-50 flex items-center justify-center bg-base-300/70 p-4"
            >
              <div class="bg-base-100 rounded-2xl shadow-xl border border-base-300 p-4 sm:p-6 w-full max-w-sm">
                <div class="flex items-center justify-between mb-1">
                  <h3 class="text-lg font-bold text-base-content">{gettext("Shop")}</h3>
                  <button
                    id="km-status-btn-shop"
                    type="button"
                    class="btn btn-ghost btn-xs"
                    title={gettext("Upgrade status")}
                  >
                    <.icon name="hero-queue-list" class="w-4 h-4" />
                  </button>
                </div>
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
                <div id="km-pack-area" class="hidden mt-3">
                  <div class="flex items-center justify-end mb-2">
                    <button id="km-pack-reroll" type="button" class="btn btn-xs btn-primary">
                      {gettext("Re-roll")}: <span id="km-reroll-cost" class="text-warning"></span>
                    </button>
                  </div>
                  <div id="km-pack-offers" class="flex flex-col gap-2"></div>
                </div>
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
                    <%= if @game_over.reason == "gave_up" do %>
                      <h2 class="text-2xl font-bold text-warning mb-2">{gettext("You gave up")}</h2>
                    <% else %>
                      <h2 class="text-2xl font-bold text-error mb-2">{gettext("Game Over")}</h2>
                    <% end %>
                  <% end %>

                  <p class="text-lg mb-6">
                    {gettext("Score")}: <span class="font-bold text-primary">{@game_over.score}</span>
                  </p>

                  <%= if @game_over.failed_kanji && @game_over.reason != "exhausted" do %>
                    <p class="text-base mb-2">
                      {gettext("The kanji you failed is:")}
                      <span class="font-japanese font-bold text-lg">{@game_over.failed_kanji}</span>
                    </p>
                    <p class="mb-6">
                      <.link
                        href={~p"/kanji/#{@game_over.failed_kanji}"}
                        target="_blank"
                        rel="noopener"
                        class="link link-primary"
                      >
                        {gettext("View it and practice →")}
                      </.link>
                    </p>
                  <% end %>

                  <%= if @recorded? do %>
                    <p class="text-success font-medium mb-4">
                      {gettext("Score recorded! Check the leaderboard:")}
                    </p>
                    <.link navigate={~p"/challenges"} class="btn btn-primary btn-sm w-full">
                      {gettext("View Leaderboard")}
                    </.link>
                  <% else %>
                    <%= if @anonymous? do %>
                      <form phx-submit="record_score" class="text-left">
                        <input type="hidden" name="score" value={@game_over.score} />
                        <input type="hidden" name="display_mode" value="anonymous" />
                        <label class="block text-sm text-secondary mb-1" for="km-anon-name">
                          {gettext("Name (max 12 characters)")}
                        </label>
                        <input
                          id="km-anon-name"
                          type="text"
                          name="anonymous_name"
                          required
                          maxlength="12"
                          placeholder={gettext("Name (max 12 characters)")}
                          class="input input-bordered input-sm w-full mb-2"
                        />
                        <button type="submit" class="btn btn-primary btn-sm w-full">
                          {gettext("Record Score")}
                        </button>
                      </form>
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
                          maxlength="12"
                          class="input input-bordered input-sm w-full mb-2"
                        />
                        <button type="submit" class="btn btn-primary btn-sm w-full">
                          {gettext("Record Score")}
                        </button>
                      </form>
                    <% end %>
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
                    "Levels go from simple (1-6 strokes) up to 19+ strokes, then restart with kanji you haven't drawn yet. After the last level you might face a rare boss kanji for a huge reward!"
                  )}
                </li>
                <li>{gettext("Each cycle, a wrong stroke costs one more life.")}</li>
                <li>
                  {gettext(
                    "The shop opens once before your first kanji and then every 4 kanji — spend coins on lives, hints, upgrades, or skips."
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
                    "Lives — you start with 20. Lose one (or more per cycle) on a wrong stroke."
                  )}
                </li>
                <li class="flex items-center gap-2">
                  <.icon name="hero-circle-stack" class="w-4 h-4 text-warning" />
                  {gettext(
                    "Coins — you start with your site level and earn 2 per completed kanji (plus 1 extra life every 4th kanji). Spent in the shop."
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
                <li>
                  <span class="font-bold" style="color: #f9a8d4">{gettext("Pink (momo)")}</span>
                  — {gettext(
                    "20% jackpot on a correct draw (+1 life, +5 coins, +5 yellow strokes); a mistake costs +1 life, 5 coins, and 2 yellow-stroke charges."
                  )}
                </li>
              </ul>
              <h4 class="text-sm font-semibold uppercase tracking-widest text-base-content/60 mb-2">
                {gettext("Boss kanji")}
              </h4>
              <p class="text-sm text-secondary mb-2">
                {gettext(
                  "The last kanji of each level is a boss with debuffed strokes; a rare final boss appears after level 5."
                )}
              </p>
              <ul class="text-sm space-y-1.5 mb-4">
                <li>
                  <span class="font-bold" style="color: #15803d">{gettext("Suppressed")}</span>
                  — {gettext("a stroke with an upgrade loses its bonus effects.")}
                </li>
                <li>
                  <span class="font-bold" style="color: #000000">{gettext("Black")}</span>
                  — {gettext("a correct draw earns 0 points.")}
                </li>
                <li>
                  <span class="font-bold" style="color: #ff1f1f">{gettext("Bright red")}</span>
                  — {gettext("a wrong draw costs 1 extra life.")}
                </li>
                <li>
                  <span class="font-bold">{gettext("Hidden")}</span>
                  — {gettext("yellow hints cannot be used on this stroke.")}
                </li>
                <li>
                  <span class="font-bold" style="color: #be185d">{gettext("Trap")}</span>
                  — {gettext(
                    "50% chance of +1 life on a correct draw; 50% chance of 3 extra lives lost on a wrong draw."
                  )}
                </li>
              </ul>
              <p class="text-sm text-secondary mb-4">
                {gettext(
                  "A pack of 3 upgrades costs a random 4-6 coins — buy it to reveal the offers and pick one. Afterwards you can re-roll the pack for 1 coin, then 2, then 3... The re-roll cost resets each time the shop opens, and re-rolling replaces the pack price (you never pay both). Packs only offer strokes of the current level and below (level 1 packs: strokes 1-6, level 2: 1-10, and so on), and the shop right after a level boss offers strokes of the next level. Already-upgraded strokes never appear while other strokes are available — when everything at this level is upgraded, packs offer re-colors of strokes you already upgraded."
                )}
              </p>
              <p class="text-sm text-secondary mb-4">
                {gettext(
                  "Purchase limits per shop visit: up to 2 upgrade packs, 4 lives, 7 yellow strokes, and 2 kanji skips. Limits reset when the shop reopens."
                )}
              </p>
              <button id="km-help-close" type="button" class="btn btn-ghost btn-sm w-full">
                {gettext("Close")}
              </button>
            </div>
          </div>

          <%!-- Upgrade status overlay: every stroke of the current kanji + currencies --%>
          <div
            id="km-status-overlay"
            class="hidden fixed inset-0 z-50 flex items-center justify-center bg-base-300/80 p-4"
          >
            <div class="bg-base-100 rounded-2xl shadow-xl border border-base-300 p-4 sm:p-6 w-full max-w-sm max-h-[80vh] overflow-y-auto">
              <h3 class="text-lg font-bold text-base-content mb-1">{gettext("Upgrade status")}</h3>
              <p class="text-xs text-secondary mb-3">{gettext("Current kanji")}</p>
              <ul id="km-status-strokes" class="text-sm space-y-1.5 mb-4"></ul>
              <h4 class="text-xs font-semibold uppercase tracking-widest text-base-content/60 mb-2">
                {gettext("Currencies")}
              </h4>
              <div id="km-status-currencies" class="flex items-center gap-4 text-sm font-bold">
                <span class="inline-flex items-center gap-1 text-error">
                  <span id="km-status-lives">0</span>
                  <.icon name="hero-heart" class="w-4 h-4" />
                </span>
                <span class="inline-flex items-center gap-1 text-warning">
                  <span id="km-status-coins">0</span>
                  <.icon name="hero-circle-stack" class="w-4 h-4" />
                </span>
                <span class="inline-flex items-center gap-1 text-yellow-500">
                  <span id="km-status-hints">0</span>
                  <.icon name="hero-heart" class="w-4 h-4" />
                </span>
              </div>
              <button id="km-status-close" type="button" class="btn btn-ghost btn-sm w-full mt-4">
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
