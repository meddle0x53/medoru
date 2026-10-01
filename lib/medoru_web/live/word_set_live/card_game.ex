defmodule MedoruWeb.WordSetLive.CardGame do
  @moduledoc """
  LiveView for the word set memory card game.

  Uses the word snapshot stored on the word set's card game record. Unlike the
  daily card challenge there is no XP or streak — the game just ends with a
  result screen and a link back to the word set.
  """

  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Learning.{WordSetCardGame, WordSets}
  alias MedoruWeb.CardGameLogic

  @max_pairs 10

  @impl true
  def mount(%{"id" => word_set_id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    locale = socket.assigns.current_scope.locale || "en"
    english_mode? = user.learning_language == "english"

    word_set = WordSets.get_word_set!(word_set_id)

    if word_set.user_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, gettext("You don't have permission to play this game."))
       |> push_navigate(to: ~p"/words/sets")}
    else
      case WordSets.get_card_game_for_set(word_set_id) do
        nil ->
          {:ok,
           socket
           |> put_flash(:error, gettext("Create a game first."))
           |> push_navigate(to: ~p"/words/sets/#{word_set_id}")}

        game ->
          words = WordSetCardGame.snapshot_words(game)
          pair_count = min(@max_pairs, length(words))
          max_attempts = max(10, pair_count * 2)

          {:ok,
           socket
           |> assign(:page_title, gettext("Memory Card Game"))
           |> assign(:word_set, word_set)
           |> assign(:game, game)
           |> assign(:words, words)
           |> assign(:pair_count, pair_count)
           |> assign(:session, new_session(words, max_attempts))
           |> assign(:result, nil)
           |> assign(:locale, locale)
           |> assign(:english_mode, english_mode?)
           |> assign(:show_input_modal, false)
           |> assign(:input_word, nil)
           |> assign(:input_error, nil)
           |> assign(:answer_meaning, "")
           |> assign(:input_disabled, false)}
      end
    end
  end

  @impl true
  def handle_event("flip_card", %{"position" => position}, socket) do
    if socket.assigns[:result] || socket.assigns[:show_input_modal] do
      {:noreply, socket}
    else
      session = socket.assigns.session
      position = String.to_integer(position)

      case CardGameLogic.flip_card(session, position) do
        {:ok, updated_session} ->
          {:noreply, assign(socket, :session, updated_session)}

        {:needs_input, updated_session, word_id} ->
          word = Enum.find(socket.assigns.words, fn w -> w.id == word_id end)

          {:noreply,
           socket
           |> assign(:session, updated_session)
           |> assign(:show_input_modal, true)
           |> assign(:input_word, word)
           |> assign(:input_error, nil)
           |> assign(:answer_meaning, "")
           |> assign(:input_disabled, false)}

        {:ok, updated_session, :no_match} ->
          socket = assign(socket, :session, updated_session)

          if CardGameLogic.game_over?(updated_session) do
            finish_game(socket, :lost)
          else
            Process.send_after(self(), :close_unmatched, 1500)
            {:noreply, socket}
          end

        {:error, _reason} ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("update_answer", params, socket) do
    value = params["meaning"] || params["value"] || ""
    {:noreply, assign(socket, :answer_meaning, value)}
  end

  @impl true
  def handle_event("submit_answer", params, socket) do
    socket = assign(socket, :input_disabled, true)
    session = socket.assigns.session
    word = socket.assigns.input_word

    answer =
      (params["meaning"] || socket.assigns.answer_meaning || "")
      |> String.trim()

    correct? =
      if socket.assigns.english_mode do
        CardGameLogic.validate_japanese_answer(answer, word)
      else
        CardGameLogic.validate_meaning(answer, word, socket.assigns.locale)
      end

    if correct? do
      updated_session = CardGameLogic.collect_flipped_cards(session)

      socket =
        socket
        |> assign(:session, updated_session)
        |> assign(:show_input_modal, false)
        |> assign(:input_word, nil)
        |> assign(:input_error, nil)
        |> assign(:answer_meaning, "")
        |> assign(:input_disabled, false)

      if CardGameLogic.all_collected?(updated_session) do
        finish_game(socket, :won)
      else
        {:noreply, socket}
      end
    else
      updated_session = CardGameLogic.consume_attempt_and_close_flipped(session)

      socket =
        socket
        |> assign(:session, updated_session)
        |> assign(:input_error, gettext("Wrong meaning. Try again!"))

      if CardGameLogic.game_over?(updated_session) do
        finish_game(socket, :lost)
      else
        Process.send_after(self(), :close_input_and_cards, 1200)
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("cancel_input", _params, socket) do
    session = socket.assigns.session
    updated_session = CardGameLogic.consume_attempt_and_close_flipped(session)

    socket =
      socket
      |> assign(:session, updated_session)
      |> assign(:show_input_modal, false)
      |> assign(:input_word, nil)
      |> assign(:input_error, nil)

    if CardGameLogic.game_over?(updated_session) do
      finish_game(socket, :lost)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("play_again", _params, socket) do
    pair_count = socket.assigns.pair_count
    max_attempts = max(10, pair_count * 2)

    {:noreply,
     socket
     |> assign(:session, new_session(socket.assigns.words, max_attempts))
     |> assign(:result, nil)
     |> assign(:show_input_modal, false)
     |> assign(:input_word, nil)
     |> assign(:input_error, nil)
     |> assign(:answer_meaning, "")
     |> assign(:input_disabled, false)}
  end

  @impl true
  def handle_info(:close_unmatched, socket) do
    if socket.assigns.show_input_modal do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :session, CardGameLogic.close_flipped(socket.assigns.session))}
    end
  end

  @impl true
  def handle_info(:close_input_and_cards, socket) do
    {:noreply,
     socket
     |> assign(:session, CardGameLogic.close_flipped(socket.assigns.session))
     |> assign(:show_input_modal, false)
     |> assign(:input_word, nil)
     |> assign(:input_error, nil)
     |> assign(:input_disabled, false)}
  end

  defp new_session(words, max_attempts) do
    CardGameLogic.new_session(Enum.map(words, & &1.id), max_attempts)
  end

  defp finish_game(socket, result) do
    {:noreply,
     socket
     |> assign(:result, result)
     |> assign(:show_input_modal, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-6">
        <div class="flex flex-wrap items-center justify-between gap-2 mb-6">
          <div class="min-w-0">
            <h1 class="text-xl sm:text-2xl font-bold text-base-content truncate">
              {gettext("Memory Card Game")}
            </h1>
            <p class="text-secondary text-sm mt-1">
              <.link navigate={~p"/words/sets/#{@word_set.id}"} class="hover:text-primary">
                {@word_set.name}
              </.link>
              ·
              <%= if @english_mode do %>
                {gettext("Match meaning pairs and type the Japanese word or reading to collect them!")}
              <% else %>
                {gettext("Match word pairs and type their meanings to collect them!")}
              <% end %>
            </p>
          </div>
          <div class="text-right shrink-0">
            <div class="badge badge-primary badge-lg">
              {@pair_count} {gettext("pairs")}
            </div>
          </div>
        </div>

        <%= cond do %>
          <% @result == :won -> %>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body text-center">
                <.icon name="hero-check-circle" class="w-16 h-16 text-success mx-auto mb-4" />
                <h2 class="text-xl font-bold">{gettext("You Win!")}</h2>
                <p class="text-secondary">
                  {gettext("You matched all pairs and knew all the meanings!")}
                </p>
                <p class="text-lg font-bold text-primary mt-2">
                  {gettext("Attempts used")}: {@session.attempts_used}
                </p>

                <div class="mt-6 flex flex-col sm:flex-row justify-center gap-3">
                  <button
                    type="button"
                    phx-click="play_again"
                    class="btn btn-primary btn-sm h-auto py-2 px-4 whitespace-normal text-center leading-tight w-full sm:w-auto"
                  >
                    {gettext("Play Again")}
                  </button>
                  <.link
                    navigate={~p"/words/sets/#{@word_set.id}"}
                    class="btn btn-outline btn-sm h-auto py-2 px-4 whitespace-normal text-center leading-tight w-full sm:w-auto"
                  >
                    <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> {gettext("Back to Word Set")}
                  </.link>
                </div>
              </div>
            </div>
          <% @result == :lost -> %>
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body text-center">
                <.icon name="hero-x-circle" class="w-16 h-16 text-error mx-auto mb-4" />
                <h2 class="text-xl font-bold">{gettext("Game Over")}</h2>
                <p class="text-secondary">
                  {gettext("You ran out of attempts. Try again!")}
                </p>

                <div class="mt-6 flex flex-col sm:flex-row justify-center gap-3">
                  <button
                    type="button"
                    phx-click="play_again"
                    class="btn btn-primary btn-sm h-auto py-2 px-4 whitespace-normal text-center leading-tight w-full sm:w-auto"
                  >
                    {gettext("Play Again")}
                  </button>
                  <.link
                    navigate={~p"/words/sets/#{@word_set.id}"}
                    class="btn btn-outline btn-sm h-auto py-2 px-4 whitespace-normal text-center leading-tight w-full sm:w-auto"
                  >
                    <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> {gettext("Back to Word Set")}
                  </.link>
                </div>
              </div>
            </div>
          <% true -> %>
            <%!-- Game Board --%>
            <div class="mb-4 flex items-center justify-between">
              <div class="flex items-center gap-4">
                <div class="text-sm">
                  <span class="text-secondary">{gettext("Attempts")}:</span>
                  <span class={[
                    "font-bold",
                    (CardGameLogic.attempts_remaining(@session) <= 3 && "text-error") ||
                      "text-base-content"
                  ]}>
                    {CardGameLogic.attempts_remaining(@session)} / {@session.max_attempts}
                  </span>
                </div>
                <div class="text-sm">
                  <span class="text-secondary">{gettext("Pairs")}:</span>
                  <span class="font-bold text-base-content">
                    {(length(@session.cards_state["collected_indices"] || []) / 2) |> trunc()} / {@pair_count}
                  </span>
                </div>
              </div>
              <.link navigate={~p"/words/sets/#{@word_set.id}"} class="btn btn-ghost btn-sm">
                <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> {gettext("Back")}
              </.link>
            </div>

            <div class="grid grid-cols-4 sm:grid-cols-5 gap-2 sm:gap-3 mx-auto max-w-lg">
              <%= for {card_state, index} <- Enum.with_index(CardGameLogic.card_states(@session)) do %>
                <% word = CardGameLogic.word_at_position(@session, @words, index) %>
                <button
                  phx-click="flip_card"
                  phx-value-position={index}
                  disabled={
                    card_state == :collected or card_state == :flipped or
                      CardGameLogic.game_over?(@session) or
                      @show_input_modal
                  }
                  class={[
                    "aspect-[3/4] rounded-xl font-bold transition-all duration-300 flex flex-col items-center justify-center relative overflow-hidden text-xs sm:text-sm",
                    card_state == :hidden &&
                      "bg-gradient-to-br from-primary to-primary/70 text-primary-content hover:from-primary/90 hover:to-primary/60 shadow-md hover:shadow-lg hover:scale-105",
                    card_state == :flipped &&
                      "bg-base-100 border-2 border-primary text-base-content shadow-lg scale-105",
                    card_state == :collected &&
                      "bg-success/20 border-2 border-success text-success opacity-50 cursor-default",
                    (CardGameLogic.game_over?(@session) or @show_input_modal) &&
                      card_state == :hidden && "opacity-60 cursor-not-allowed"
                  ]}
                >
                  <%= case card_state do %>
                    <% :hidden -> %>
                      <span class="text-xl sm:text-2xl">?</span>
                    <% :flipped -> %>
                      <%= if @english_mode do %>
                        <span class="font-bold text-center px-1 break-words text-xs sm:text-sm line-clamp-3">
                          {word.meaning}
                        </span>
                      <% else %>
                        <span class="font-bold">{word.text}</span>
                        <span :if={word.reading != ""} class="text-xs text-secondary mt-1">
                          {word.reading}
                        </span>
                      <% end %>
                    <% :collected -> %>
                      <.icon name="hero-check" class="w-6 h-6 sm:w-8 sm:h-8" />
                  <% end %>
                </button>
              <% end %>
            </div>
        <% end %>

        <%!-- Meaning Input Modal --%>
        <%= if @show_input_modal and @input_word do %>
          <div class="fixed inset-0 bg-black/50 z-50 flex items-start sm:items-center justify-center p-4 pt-16 sm:pt-4">
            <div class="bg-base-100 rounded-2xl shadow-xl max-w-md w-full p-6 max-h-[80vh] overflow-y-auto">
              <h3 class="text-xl font-bold text-base-content mb-2">
                {gettext("Match Found!")}
              </h3>
              <p class="text-secondary mb-4">
                <%= if @english_mode do %>
                  {gettext("Type the Japanese word or reading to collect these cards.")}
                <% else %>
                  {gettext("Type the meaning to collect these cards.")}
                <% end %>
              </p>

              <%!-- Word preview card --%>
              <div class="card bg-primary/10 border border-primary/30 rounded-xl p-4 mb-4 text-center">
                <%= if @english_mode do %>
                  <p class="text-lg font-bold text-base-content">{@input_word.meaning}</p>
                <% else %>
                  <p class="text-lg font-bold text-base-content">{@input_word.text}</p>
                  <p :if={@input_word.reading != ""} class="text-sm text-secondary mt-1">
                    {@input_word.reading}
                  </p>
                <% end %>
              </div>

              <%!-- Error alert --%>
              <%= if @input_error do %>
                <div class="alert alert-error mb-4">
                  <.icon name="hero-x-circle" class="w-5 h-5" />
                  <span>{@input_error}</span>
                </div>
              <% end %>

              <%!-- Input form --%>
              <form phx-submit="submit_answer" class="space-y-3 mb-4">
                <div>
                  <label class="block text-sm font-medium text-base-content mb-1">
                    <%= if @english_mode do %>
                      {gettext("Japanese word or reading")}
                    <% else %>
                      {gettext("Meaning")}
                    <% end %>
                  </label>
                  <input
                    type="text"
                    id="meaning-input"
                    name="meaning"
                    value={@answer_meaning}
                    phx-change="update_answer"
                    disabled={@input_disabled}
                    class={[
                      "input input-bordered w-full text-base",
                      @input_disabled && "bg-base-200 opacity-60"
                    ]}
                    placeholder={
                      if @english_mode do
                        gettext("Type the word or reading...")
                      else
                        gettext("Type the meaning...")
                      end
                    }
                    phx-mounted={!@input_disabled && JS.focus(to: "#meaning-input")}
                  />
                </div>

                <div class="flex gap-3 justify-end pt-2">
                  <button
                    type="button"
                    phx-click="cancel_input"
                    disabled={@input_disabled}
                    class="btn btn-ghost"
                  >
                    {gettext("Give Up")}
                  </button>
                  <button type="submit" disabled={@input_disabled} class="btn btn-primary">
                    <.icon name="hero-check" class="w-4 h-4 mr-1" /> {gettext("Submit")}
                  </button>
                </div>
              </form>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
