defmodule MedoruWeb.DailyCardGameLive do
  use MedoruWeb, :live_view

  alias Medoru.Learning
  alias Medoru.Content

  @max_attempts 20
  @pair_count 10

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    locale = socket.assigns.current_scope.locale || "en"
    english_mode? = user.learning_language == "english"

    if Learning.daily_challenge_completed?(user.id, "daily_cards") do
      {:ok,
       socket
       |> assign(:page_title, gettext("Daily Card Challenge"))
       |> assign(:already_completed, true)
       |> assign(:streak, get_streak(user.id))}
    else
      words = select_words(user)

      if length(words) < @pair_count do
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("Not enough words learned yet. Complete some lessons first!")
         )
         |> push_navigate(to: ~p"/daily-challenges")}
      else
        card_positions =
          words
          |> Enum.flat_map(&[&1.id, &1.id])
          |> Enum.shuffle()

        session = %{
          status: :in_progress,
          attempts_used: 0,
          max_attempts: @max_attempts,
          cards_state: %{
            "card_positions" => card_positions,
            "collected_indices" => [],
            "flipped_indices" => []
          }
        }

        {:ok,
         socket
         |> assign(:page_title, gettext("Daily Card Challenge"))
         |> assign(:already_completed, false)
         |> assign(:words, words)
         |> assign(:session, session)
         |> assign(:game_over, false)
         |> assign(:xp_awarded, nil)
         |> assign(:pair_count, @pair_count)
         |> assign(:streak, get_streak(user.id))
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
    if socket.assigns[:already_completed] || socket.assigns[:game_over] ||
         socket.assigns[:show_input_modal] do
      {:noreply, socket}
    else
      session = socket.assigns.session
      position = String.to_integer(position)

      case flip_card(session, position) do
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

          if game_over?(updated_session) do
            complete_game(socket, :lost)
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
        validate_japanese_answer(answer, word)
      else
        validate_meaning(answer, word, socket.assigns.locale)
      end

    if correct? do
      # Correct - collect the flipped cards
      updated_session = collect_flipped_cards(session)

      socket =
        socket
        |> assign(:session, updated_session)
        |> assign(:show_input_modal, false)
        |> assign(:input_word, nil)
        |> assign(:input_error, nil)
        |> assign(:answer_meaning, "")
        |> assign(:input_disabled, false)

      if all_collected?(updated_session) do
        complete_game(socket, :won)
      else
        {:noreply, socket}
      end
    else
      # Wrong - consume attempt, close cards
      updated_session = consume_attempt_and_close_flipped(session)

      socket =
        socket
        |> assign(:session, updated_session)
        |> assign(:input_error, gettext("Wrong meaning. Try again!"))

      if game_over?(updated_session) do
        complete_game(socket, :lost)
      else
        # Close the modal and flip cards back after a short delay
        Process.send_after(self(), :close_input_and_cards, 1200)
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("cancel_input", _params, socket) do
    session = socket.assigns.session
    updated_session = consume_attempt_and_close_flipped(session)

    socket =
      socket
      |> assign(:session, updated_session)
      |> assign(:show_input_modal, false)
      |> assign(:input_word, nil)
      |> assign(:input_error, nil)

    if game_over?(updated_session) do
      complete_game(socket, :lost)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:close_unmatched, socket) do
    # Don't close cards if the meaning input modal is open
    if socket.assigns.show_input_modal do
      {:noreply, socket}
    else
      session = socket.assigns.session

      new_state =
        session.cards_state
        |> Map.put("flipped_indices", [])

      updated_session = Map.put(session, :cards_state, new_state)
      {:noreply, assign(socket, :session, updated_session)}
    end
  end

  @impl true
  def handle_info(:close_input_and_cards, socket) do
    session = socket.assigns.session

    new_state =
      session.cards_state
      |> Map.put("flipped_indices", [])

    updated_session = Map.put(session, :cards_state, new_state)

    {:noreply,
     socket
     |> assign(:session, updated_session)
     |> assign(:show_input_modal, false)
     |> assign(:input_word, nil)
     |> assign(:input_error, nil)
     |> assign(:input_disabled, false)}
  end

  # ============================================================================
  # Game Logic (inline, no DB)
  # ============================================================================

  defp flip_card(session, position) do
    cards_state = session.cards_state
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []
    flipped = cards_state["flipped_indices"] || []

    cond do
      session.status != :in_progress ->
        {:error, :game_over}

      position in collected ->
        {:error, :already_collected}

      position in flipped ->
        {:error, :already_flipped}

      length(flipped) >= 2 ->
        {:error, :too_many_flipped}

      position < 0 or position >= length(card_positions) ->
        {:error, :invalid_position}

      true ->
        new_flipped = flipped ++ [position]

        if length(new_flipped) == 2 do
          handle_two_flipped(session, new_flipped, card_positions, collected)
        else
          new_state = %{
            "card_positions" => card_positions,
            "collected_indices" => collected,
            "flipped_indices" => new_flipped
          }

          {:ok, Map.put(session, :cards_state, new_state)}
        end
    end
  end

  defp handle_two_flipped(session, [pos1, pos2], card_positions, collected) do
    word1 = Enum.at(card_positions, pos1)
    word2 = Enum.at(card_positions, pos2)

    if word1 == word2 do
      # Match found - ask for meaning input (keep flipped)
      new_state = %{
        "card_positions" => card_positions,
        "collected_indices" => collected,
        "flipped_indices" => [pos1, pos2]
      }

      updated = Map.put(session, :cards_state, new_state)
      {:needs_input, updated, word1}
    else
      new_attempts = session.attempts_used + 1

      new_state = %{
        "card_positions" => card_positions,
        "collected_indices" => collected,
        "flipped_indices" => [pos1, pos2]
      }

      updated =
        session
        |> Map.put(:cards_state, new_state)
        |> Map.put(:attempts_used, new_attempts)

      if new_attempts >= session.max_attempts do
        {:ok, Map.put(updated, :status, :completed), :no_match}
      else
        {:ok, updated, :no_match}
      end
    end
  end

  defp collect_flipped_cards(session) do
    cards_state = session.cards_state
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []
    flipped = cards_state["flipped_indices"] || []

    new_collected = collected ++ flipped

    new_state = %{
      "card_positions" => card_positions,
      "collected_indices" => new_collected,
      "flipped_indices" => []
    }

    updated = Map.put(session, :cards_state, new_state)

    if all_collected?(updated) do
      Map.put(updated, :status, :completed)
    else
      updated
    end
  end

  defp consume_attempt_and_close_flipped(session) do
    cards_state = session.cards_state
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []

    new_attempts = session.attempts_used + 1

    new_state = %{
      "card_positions" => card_positions,
      "collected_indices" => collected,
      "flipped_indices" => []
    }

    updated =
      session
      |> Map.put(:cards_state, new_state)
      |> Map.put(:attempts_used, new_attempts)

    if new_attempts >= session.max_attempts do
      Map.put(updated, :status, :completed)
    else
      updated
    end
  end

  defp complete_game(socket, result) do
    user = socket.assigns.current_scope.current_user

    xp =
      case result do
        :won -> 300
        :lost -> 100
      end

    score = socket.assigns.session.attempts_used

    _ =
      Learning.complete_daily_challenge(user.id, "daily_cards", xp,
        score: score,
        metadata: %{
          "result" => to_string(result),
          "attempts_used" => score
        }
      )

    {:noreply,
     socket
     |> assign(:game_over, true)
     |> assign(:xp_awarded, xp)
     |> assign(:show_input_modal, false)
     |> assign(:streak, get_streak(user.id))}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp select_words(%{learning_language: "english"} = user) do
    learned = Learning.list_english_learned_words(user.id, limit: 200)

    words =
      if length(learned) >= @pair_count do
        learned |> Enum.shuffle() |> Enum.take(@pair_count)
      else
        # Fallback: fill with N5 words
        n5_words =
          Content.list_words_by_difficulty(5)
          |> Enum.reject(fn w -> w.id in Enum.map(learned, & &1.id) end)
          |> Enum.shuffle()
          |> Enum.take(@pair_count - length(learned))

        learned ++ n5_words
      end

    words
  end

  defp select_words(user) do
    learned = Learning.list_learned_words(user.id, limit: 200)

    words =
      if length(learned) >= @pair_count do
        learned |> Enum.shuffle() |> Enum.take(@pair_count)
      else
        # Fallback: fill with N5 words
        n5_words =
          Content.list_words_by_difficulty(5)
          |> Enum.reject(fn w -> w.id in Enum.map(learned, & &1.id) end)
          |> Enum.shuffle()
          |> Enum.take(@pair_count - length(learned))

        learned ++ n5_words
      end

    words
  end

  defp validate_meaning(answer, _word, _locale) when answer == "", do: false

  defp validate_meaning(answer, word, locale) do
    answer_lower = String.downcase(answer)

    # Build list of valid meanings: English + locale translation
    localized_meaning = get_localized_meaning(word, locale)

    meanings =
      [word.meaning, localized_meaning]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&split_meanings/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))

    Enum.any?(meanings, fn meaning ->
      String.contains?(meaning, answer_lower) or
        String.contains?(answer_lower, meaning)
    end)
  end

  defp get_localized_meaning(%{translations: translations}, locale)
       when is_map(translations) and translations != %{} do
    case get_in(translations, [locale, "meaning"]) do
      nil -> get_in(translations, ["en", "meaning"])
      meaning -> meaning
    end
  end

  defp get_localized_meaning(_word, _locale), do: nil

  defp split_meanings(nil), do: []

  defp split_meanings(text) do
    text
    |> String.split(~r/[,;、]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp validate_japanese_answer(answer, _word) when answer == "", do: false

  defp validate_japanese_answer(answer, word) do
    answer = String.trim(answer)

    valid_answers =
      [word.text, word.reading]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&split_readings/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Enum.any?(valid_answers, fn valid ->
      String.downcase(valid) == String.downcase(answer)
    end)
  end

  defp split_readings(nil), do: []

  defp split_readings(text) do
    text
    |> String.split(~r{[/／]})
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp card_states(session) do
    cards_state = session.cards_state || %{}
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []
    flipped = cards_state["flipped_indices"] || []

    Enum.map(0..(length(card_positions) - 1), fn index ->
      cond do
        index in collected -> :collected
        index in flipped -> :flipped
        true -> :hidden
      end
    end)
  end

  defp word_at_position(session, words, position) do
    cards_state = session.cards_state || %{}
    card_positions = cards_state["card_positions"] || []
    word_id = Enum.at(card_positions, position)

    Enum.find(words, %{text: "?", reading: "", meaning: "?"}, fn w ->
      w.id == word_id
    end)
  end

  defp attempts_remaining(session) do
    session.max_attempts - session.attempts_used
  end

  defp game_over?(session) do
    session.status == :completed or attempts_remaining(session) <= 0
  end

  defp all_collected?(session) do
    cards_state = session.cards_state || %{}
    collected = cards_state["collected_indices"] || []
    card_positions = cards_state["card_positions"] || []
    length(collected) == length(card_positions)
  end

  defp get_streak(user_id) do
    case Learning.get_daily_streak(user_id) do
      nil -> %{current_streak: 0}
      streak -> streak
    end
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-base-content">{gettext("Daily Card Challenge")}</h1>
          <p class="text-secondary text-sm mt-1">
            <%= if @english_mode do %>
              {gettext("Match meaning pairs and type the Japanese word or reading to collect them!")}
            <% else %>
              {gettext("Match word pairs and type their meanings to collect them!")}
            <% end %>
          </p>
        </div>
        <div class="text-right">
          <div class="badge badge-primary badge-lg">
            <.icon name="hero-fire" class="w-4 h-4 mr-1" />
            {@streak.current_streak} {gettext("day streak")}
          </div>
        </div>
      </div>

      <%= cond do %>
        <% @already_completed -> %>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body text-center">
              <.icon name="hero-check-circle" class="w-16 h-16 text-success mx-auto mb-4" />
              <h2 class="text-xl font-bold">{gettext("Already Completed!")}</h2>
              <p class="text-secondary">
                {gettext("You have already completed today's card challenge.")}
              </p>
              <div class="mt-4 flex flex-col sm:flex-row justify-center gap-3">
                <.link navigate={~p"/daily-challenges"} class="btn btn-primary">
                  {gettext("Back to Daily Challenges")}
                </.link>
                <.link navigate={~p"/dashboard"} class="btn btn-outline">
                  <.icon name="hero-home" class="w-4 h-4 mr-2" /> {gettext("Dashboard")}
                </.link>
              </div>
            </div>
          </div>
        <% @game_over -> %>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body text-center">
              <%= if @xp_awarded == 300 do %>
                <.icon name="hero-check-circle" class="w-16 h-16 text-success mx-auto mb-4" />
                <h2 class="text-xl font-bold">{gettext("Challenge Complete!")}</h2>
                <p class="text-secondary">
                  {gettext("You matched all pairs and knew all the meanings!")}
                </p>
              <% else %>
                <.icon name="hero-x-circle" class="w-16 h-16 text-error mx-auto mb-4" />
                <h2 class="text-xl font-bold">{gettext("Game Over")}</h2>
                <p class="text-secondary">
                  {gettext("You ran out of attempts. Try again tomorrow!")}
                </p>
              <% end %>
              <p class="text-lg font-bold text-primary mt-2">+{@xp_awarded} XP</p>

              <div class="mt-6 flex flex-col sm:flex-row justify-center gap-3">
                <.link navigate={~p"/daily-challenges"} class="btn btn-primary">
                  {gettext("Back to Daily Challenges")}
                </.link>
                <.link navigate={~p"/dashboard"} class="btn btn-outline">
                  <.icon name="hero-home" class="w-4 h-4 mr-2" /> {gettext("Dashboard")}
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
                  (attempts_remaining(@session) <= 3 && "text-error") || "text-base-content"
                ]}>
                  {attempts_remaining(@session)} / {@session.max_attempts}
                </span>
              </div>
              <div class="text-sm">
                <span class="text-secondary">{gettext("Pairs")}:</span>
                <span class="font-bold text-base-content">
                  {(length(@session.cards_state["collected_indices"] || []) / 2) |> trunc()} / {@pair_count}
                </span>
              </div>
            </div>
            <.link navigate={~p"/daily-challenges"} class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> {gettext("Back")}
            </.link>
          </div>

          <div class="grid grid-cols-4 sm:grid-cols-5 gap-2 sm:gap-3 mx-auto max-w-lg">
            <%= for {card_state, index} <- Enum.with_index(card_states(@session)) do %>
              <% word = word_at_position(@session, @words, index) %>
              <button
                phx-click="flip_card"
                phx-value-position={index}
                disabled={
                  card_state == :collected or card_state == :flipped or game_over?(@session) or
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
                  (game_over?(@session) or @show_input_modal) && card_state == :hidden &&
                    "opacity-60 cursor-not-allowed"
                ]}
              >
                <%= case card_state do %>
                  <% :hidden -> %>
                    <span class="text-xl sm:text-2xl">?</span>
                  <% :flipped -> %>
                    <%= if @english_mode do %>
                      <span class="font-bold text-center px-1">{word.meaning}</span>
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
    """
  end
end
