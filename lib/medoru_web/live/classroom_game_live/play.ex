defmodule MedoruWeb.ClassroomGameLive.Play do
  @moduledoc """
  LiveView for students to play a memory card game.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Games

  @impl true
  def mount(%{"classroom_id" => classroom_id, "game_id" => game_id}, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Verify membership
    case Classrooms.get_user_membership(classroom_id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not a member of this classroom."))
         |> push_navigate(to: ~p"/classrooms")}

      membership ->
        if membership.status != :approved do
          {:ok,
           socket
           |> put_flash(:error, gettext("Your membership is pending approval."))
           |> push_navigate(to: ~p"/classrooms")}
        else
          classroom = Classrooms.get_classroom!(classroom_id)
          game = Games.get_game_for_play!(game_id)

          if game.classroom_id != classroom_id do
            {:ok,
             socket
             |> put_flash(:error, gettext("Game not found in this classroom."))
             |> push_navigate(to: ~p"/classrooms/#{classroom_id}")}
          else
            if game.status != :published do
              {:ok,
               socket
               |> put_flash(:error, gettext("This game is not available yet."))
               |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=games")}
            else
              # Get or create session
              {:ok, session} = Games.get_or_create_session(game_id, user.id)

              # If a previous crash left cards flipped, clear them so the game is playable
              session =
                if has_two_flipped?(session) do
                  case Games.close_flipped_cards(session.id) do
                    {:ok, cleared} -> cleared
                    {:error, _} -> session
                  end
                else
                  session
                end

              socket =
                socket
                |> assign(:page_title, game.name)
                |> assign(:classroom, classroom)
                |> assign(:game, game)
                |> assign(:session, session)
                |> assign(:show_input_modal, false)
                |> assign(:input_word_id, nil)
                |> assign(:input_kana_char, nil)
                |> assign(:input_error, nil)
                |> assign(:input_disabled, false)
                |> assign(:answer_meaning, "")
                |> assign(:answer_pronunciation, "")
                |> assign(:answer_reading, "")
                |> assign(:is_mobile, nil)

              {:ok, push_event(socket, "request_fullscreen", %{})}
            end
          end
        end
    end
  end

  @impl true
  def handle_event("device_info", %{"is_mobile" => is_mobile}, socket) do
    {:noreply, assign(socket, :is_mobile, is_mobile)}
  end

  @impl true
  def handle_event("enter_fullscreen", _params, socket) do
    {:noreply, push_event(socket, "force_fullscreen", %{})}
  end

  @impl true
  def handle_event("flip_card", %{"position" => position}, socket) do
    session = socket.assigns.session
    position = String.to_integer(position)
    game = socket.assigns.game

    flip_result =
      if game.type == "kana_memory_cards" do
        Games.flip_kana_card(session.id, position)
      else
        Games.flip_card(session.id, position)
      end

    case flip_result do
      {:ok, updated_session} ->
        {:noreply, assign(socket, :session, updated_session)}

      {:ok, updated_session, :no_match} ->
        # Start 3-second reveal timer before closing unmatched cards
        Process.send_after(self(), :close_unmatched, 3000)
        {:noreply, assign(socket, :session, updated_session)}

      {:ok, updated_session, :collected, points} ->
        socket =
          socket
          |> assign(:session, updated_session)
          |> put_flash(:info, gettext("Match! +%{points} points", points: points))

        {:noreply, socket}

      {:needs_input, updated_session, input_id} ->
        if game.type == "kana_memory_cards" do
          {:noreply,
           socket
           |> assign(:session, updated_session)
           |> assign(:show_input_modal, true)
           |> assign(:input_kana_char, input_id)
           |> assign(:input_error, nil)
           |> assign(:input_disabled, false)
           |> assign(:answer_reading, "")}
        else
          {:noreply,
           socket
           |> assign(:session, updated_session)
           |> assign(:show_input_modal, true)
           |> assign(:input_word_id, input_id)
           |> assign(:input_error, nil)
           |> assign(:input_disabled, false)
           |> assign(:answer_meaning, "")
           |> assign(:answer_pronunciation, "")
           |> assign(:answer_reading, "")}
        end

      {:error, :game_over} ->
        {:noreply, put_flash(socket, :error, gettext("Game over! No attempts remaining."))}

      {:error, :already_collected} ->
        {:noreply, socket}

      {:error, :already_flipped} ->
        {:noreply, socket}

      {:error, :too_many_flipped} ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, gettext("Error: %{reason}", reason: inspect(reason)))}
    end
  end

  @impl true
  def handle_event("submit_answer", params, socket) do
    session = socket.assigns.session
    game = socket.assigns.game

    if game.type == "kana_memory_cards" do
      answer = %{"reading" => params["reading"] || socket.assigns.answer_reading}

      case Games.submit_kana_answer(session.id, answer) do
        {:ok, updated_session, :collected, points} ->
          socket =
            socket
            |> assign(:session, updated_session)
            |> assign(:show_input_modal, false)
            |> assign(:input_word_id, nil)
            |> assign(:input_error, nil)
            |> assign(:input_disabled, false)
            |> assign(:answer_reading, "")
            |> put_flash(:info, gettext("Correct! +%{points} points", points: points))

          {:noreply, socket}

        {:ok, updated_session, :wrong_answer} ->
          Process.send_after(self(), :close_wrong_answer, 2500)

          {:noreply,
           socket
           |> assign(:session, updated_session)
           |> assign(:input_error, gettext("Wrong answer! One attempt lost."))
           |> assign(:input_disabled, true)}

        {:error, :game_over} ->
          {:noreply,
           socket
           |> assign(:show_input_modal, false)
           |> assign(:input_word_id, nil)
           |> put_flash(:error, gettext("Game over! No attempts remaining."))}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:show_input_modal, false)
           |> put_flash(:error, gettext("Error: %{reason}", reason: inspect(reason)))}
      end
    else
      # Word game answer
      answer = %{
        "meaning" => params["meaning"] || socket.assigns.answer_meaning,
        "pronunciation" => params["pronunciation"] || socket.assigns.answer_pronunciation
      }

      locale = socket.assigns.current_scope.locale

      case Games.submit_collection_answer(session.id, answer, locale) do
        {:ok, updated_session, :collected, points} ->
          socket =
            socket
            |> assign(:session, updated_session)
            |> assign(:show_input_modal, false)
            |> assign(:input_word_id, nil)
            |> assign(:input_error, nil)
            |> assign(:input_disabled, false)
            |> assign(:answer_meaning, "")
            |> assign(:answer_pronunciation, "")
            |> put_flash(:info, gettext("Correct! +%{points} points", points: points))

          {:noreply, socket}

        {:ok, updated_session, :wrong_answer} ->
          Process.send_after(self(), :close_wrong_answer, 2500)

          {:noreply,
           socket
           |> assign(:session, updated_session)
           |> assign(:input_error, gettext("Wrong answer! One attempt lost."))
           |> assign(:input_disabled, true)}

        {:error, :game_over} ->
          {:noreply,
           socket
           |> assign(:show_input_modal, false)
           |> assign(:input_word_id, nil)
           |> put_flash(:error, gettext("Game over! No attempts remaining."))}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:show_input_modal, false)
           |> put_flash(:error, gettext("Error: %{reason}", reason: inspect(reason)))}
      end
    end
  end

  @impl true
  def handle_event("cancel_input", _, socket) do
    session = socket.assigns.session

    case Games.cancel_input_attempt(session.id) do
      {:ok, cleared_session, :game_over} ->
        {:noreply,
         socket
         |> assign(:session, cleared_session)
         |> assign(:show_input_modal, false)
         |> assign(:input_word_id, nil)
         |> assign(:input_kana_char, nil)
         |> assign(:input_error, nil)
         |> assign(:input_disabled, false)
         |> assign(:answer_reading, "")
         |> put_flash(:error, gettext("Game over! No attempts remaining."))}

      {:ok, cleared_session, :cancelled} ->
        {:noreply,
         socket
         |> assign(:session, cleared_session)
         |> assign(:show_input_modal, false)
         |> assign(:input_word_id, nil)
         |> assign(:input_kana_char, nil)
         |> assign(:input_error, nil)
         |> assign(:input_disabled, false)
         |> assign(:answer_reading, "")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:show_input_modal, false)
         |> put_flash(:error, gettext("Error: %{reason}", reason: inspect(reason)))}
    end
  end

  @impl true
  def handle_event("reset_game", _, socket) do
    game = socket.assigns.game
    user = socket.assigns.current_scope.current_user

    case Games.reset_session(game.id, user.id) do
      {:ok, _} ->
        {:ok, session} = Games.get_or_create_session(game.id, user.id)

        {:noreply,
         socket
         |> assign(:session, session)
         |> assign(:show_input_modal, false)
         |> assign(:input_word_id, nil)
         |> assign(:input_kana_char, nil)
         |> assign(:input_error, nil)
         |> assign(:input_disabled, false)
         |> put_flash(:info, gettext("Game reset. Good luck!"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to reset game."))}
    end
  end

  @impl true
  def handle_event("update_answer", params, socket) do
    field = params["field"]
    # LiveView sends the value under the input's name attribute
    value = params[field] || params["value"] || ""

    socket =
      case field do
        "meaning" -> assign(socket, :answer_meaning, value)
        "pronunciation" -> assign(socket, :answer_pronunciation, value)
        "reading" -> assign(socket, :answer_reading, value)
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:close_unmatched, socket) do
    case Games.close_flipped_cards(socket.assigns.session.id) do
      {:ok, updated_session} ->
        {:noreply, assign(socket, :session, updated_session)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:close_wrong_answer, socket) do
    session = socket.assigns.session

    {:ok, cleared_session} = Games.close_flipped_cards(session.id)

    {:noreply,
     socket
     |> assign(:session, cleared_session)
     |> assign(:show_input_modal, false)
     |> assign(:input_word_id, nil)
     |> assign(:input_kana_char, nil)
     |> assign(:input_error, nil)
     |> assign(:input_disabled, false)
     |> assign(:answer_meaning, "")
     |> assign(:answer_pronunciation, "")
     |> assign(:answer_reading, "")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div
        id="memory-card-game-container"
        class="max-w-4xl mx-auto px-4 py-6"
        data-memory-card-game="true"
        phx-hook="GameFullscreen"
      >
        <%!-- Header --%>
        <div class="mb-4 sm:mb-6">
          <.link
            navigate={~p"/classrooms/#{@classroom.id}?tab=games"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-3 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Games")}
          </.link>

          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <div>
              <h1 class="text-xl sm:text-2xl font-bold text-base-content">{@game.name}</h1>
              <p class="text-secondary text-sm">
                <%= if @game.type == "kana_memory_cards" do %>
                  {gettext("Kana Memory Card Game")}
                <% else %>
                  {gettext("Memory Card Game")}
                <% end %>
              </p>
            </div>
            <div class="flex items-center gap-3">
              <.link
                navigate={~p"/classrooms/#{@classroom.id}/games/#{@game.id}/rankings"}
                class="btn btn-ghost btn-sm"
              >
                <.icon name="hero-trophy" class="w-4 h-4 mr-1" /> {gettext("Rankings")}
              </.link>
              <%= if @is_mobile == false do %>
                <button
                  type="button"
                  phx-click="enter_fullscreen"
                  class="btn btn-ghost btn-sm"
                  title={gettext("Full Screen")}
                >
                  <.icon name="hero-arrows-pointing-out" class="w-4 h-4" />
                </button>
              <% end %>
              <div class="badge badge-outline badge-lg">
                <.icon name="hero-heart" class="w-4 h-4 mr-1" />
                {attempts_remaining(@session)} / {@session.max_attempts} {gettext("attempts")}
              </div>
              <div class="badge badge-primary badge-lg">
                <.icon name="hero-star" class="w-4 h-4 mr-1" />
                {@session.score} {gettext("pts")}
              </div>
            </div>
          </div>
        </div>

        <%!-- Game Over Banner --%>
        <%= if game_over?(@session) do %>
          <div class="card bg-gradient-to-r from-primary/10 to-secondary/10 border border-primary/30 mb-6">
            <div class="card-body text-center">
              <h2 class="text-2xl font-bold text-base-content mb-2">
                <%= if all_collected?(@session) do %>
                  {gettext("🎉 Congratulations! All cards collected!")}
                <% else %>
                  {gettext("Game Over!")}
                <% end %>
              </h2>
              <p class="text-lg text-base-content mb-4">
                {gettext("Final Score: %{score} points", score: @session.score)}
              </p>
              <button phx-click="reset_game" class="btn btn-primary">
                <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> {gettext("Play Again")}
              </button>
            </div>
          </div>
        <% end %>

        <%!-- Card Grid --%>
        <div class={[
          "grid gap-2 sm:gap-3 mx-auto",
          grid_cols_class(board_size(@game))
        ]}>
          <%= for {card_state, index} <- Enum.with_index(card_states(@session)) do %>
            <button
              phx-click="flip_card"
              phx-value-position={index}
              disabled={card_state == :collected or card_state == :flipped or game_over?(@session)}
              class={[
                "aspect-[3/4] rounded-xl font-bold transition-all duration-300 flex items-center justify-center relative overflow-hidden",
                card_state == :hidden &&
                  "bg-gradient-to-br from-primary to-primary/70 text-primary-content hover:from-primary/90 hover:to-primary/60 shadow-md hover:shadow-lg hover:scale-105",
                card_state == :flipped &&
                  "bg-base-100 border-2 border-primary text-base-content shadow-lg scale-105",
                card_state == :collected &&
                  "bg-success/20 border-2 border-success text-success opacity-50 cursor-default",
                game_over?(@session) && card_state == :hidden && "opacity-60 cursor-not-allowed"
              ]}
            >
              <%= case card_state do %>
                <% :hidden -> %>
                  <span class="text-2xl sm:text-3xl">?</span>
                <% :flipped -> %>
                  <%= if @game.type == "kana_memory_cards" do %>
                    <% kana_char = kana_at_position(@session, index) %>
                    <span class="text-2xl sm:text-3xl lg:text-4xl">{kana_char}</span>
                  <% else %>
                    <% word =
                      word_at_position(@session, index, @game.memory_card_game.memory_card_game_words)

                    mcg = @game.memory_card_game

                    show_reading? =
                      not (mcg.pronunciation_required_for_collection or
                             mcg.meaning_or_pronunciation_required_for_collection)

                    show_meaning? =
                      not (mcg.meaning_required_for_collection or
                             mcg.meaning_or_pronunciation_required_for_collection) %>
                    <% meaning_text = Content.get_localized_meaning(word, @current_scope.locale) %>
                    <div class="text-center px-1">
                      <p class="text-sm sm:text-base lg:text-lg leading-tight">{word.text}</p>
                      <p :if={show_reading?} class="text-xs text-secondary mt-1 hidden sm:block">
                        {word.reading}
                      </p>
                      <p :if={show_meaning?} class="text-xs text-success mt-1 hidden sm:block">
                        {meaning_text}
                      </p>
                    </div>
                  <% end %>
                <% :collected -> %>
                  <.icon name="hero-check" class="w-6 h-6 sm:w-8 sm:h-8" />
              <% end %>
            </button>
          <% end %>
        </div>

        <%!-- Collection Input Modal --%>
        <%= if @show_input_modal do %>
          <div class="fixed inset-0 bg-black/50 z-50 flex items-start sm:items-center justify-center p-4 pt-16 sm:pt-4">
            <div class="bg-base-100 rounded-2xl shadow-xl max-w-md w-full p-6 max-h-[80vh] overflow-y-auto">
              <h3 class="text-xl font-bold text-base-content mb-2">
                {gettext("Match Found!")}
              </h3>
              <p class="text-secondary mb-4">
                {gettext("Enter the correct answer to collect these cards.")}
              </p>

              <%= if @game.type == "kana_memory_cards" do %>
                <% kana_char = @input_kana_char || "" %>
                <div class="card bg-primary/10 border border-primary/30 rounded-xl p-4 mb-4 text-center">
                  <p class="text-3xl font-bold text-base-content">{kana_char}</p>
                </div>
              <% else %>
                <% input_word =
                  Enum.find(
                    @game.memory_card_game.memory_card_game_words,
                    &(&1.word_id == @input_word_id)
                  )

                mcg = @game.memory_card_game

                show_reading? =
                  not (mcg.pronunciation_required_for_collection or
                         mcg.meaning_or_pronunciation_required_for_collection) %>
                <%= if input_word do %>
                  <div class="card bg-primary/10 border border-primary/30 rounded-xl p-4 mb-4 text-center">
                    <p class="text-lg font-bold text-base-content">{input_word.word.text}</p>
                    <p :if={show_reading?} class="text-sm text-secondary mt-1">
                      {input_word.word.reading}
                    </p>
                  </div>
                <% end %>
              <% end %>

              <%= if @input_error do %>
                <div class="alert alert-error mb-4">
                  <.icon name="hero-x-circle" class="w-5 h-5" />
                  <span>{@input_error}</span>
                </div>
              <% end %>

              <form phx-submit="submit_answer" class="space-y-3 mb-6">
                <%= if @game.type == "kana_memory_cards" do %>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-1">
                      {gettext("Romaji")}
                    </label>
                    <input
                      type="text"
                      id="reading-input"
                      name="reading"
                      value={@answer_reading}
                      phx-change={not @input_disabled && "update_answer"}
                      phx-value-field="reading"
                      disabled={@input_disabled}
                      class={[
                        "input input-bordered w-full text-base",
                        @input_disabled && "bg-base-200 opacity-60"
                      ]}
                      placeholder={gettext("Type the romaji...")}
                      phx-mounted={!@input_disabled && JS.focus(to: "#reading-input")}
                    />
                  </div>
                <% else %>
                  <% mcg = @game.memory_card_game %>
                  <%= if mcg.meaning_required_for_collection or mcg.meaning_or_pronunciation_required_for_collection do %>
                    <div>
                      <label class="block text-sm font-medium text-base-content mb-1">
                        {gettext("Meaning")}
                      </label>
                      <input
                        type="text"
                        id="meaning-input"
                        name="meaning"
                        value={@answer_meaning}
                        phx-change={not @input_disabled && "update_answer"}
                        phx-value-field="meaning"
                        disabled={@input_disabled}
                        class={[
                          "input input-bordered w-full text-base",
                          @input_disabled && "bg-base-200 opacity-60"
                        ]}
                        placeholder={gettext("Type the meaning...")}
                        phx-mounted={!@input_disabled && JS.focus(to: "#meaning-input")}
                      />
                    </div>
                  <% end %>
                  <%= if mcg.pronunciation_required_for_collection or mcg.meaning_or_pronunciation_required_for_collection do %>
                    <div>
                      <label class="block text-sm font-medium text-base-content mb-1">
                        {gettext("Pronunciation (reading)")}
                      </label>
                      <input
                        type="text"
                        id="pronunciation-input"
                        name="pronunciation"
                        value={@answer_pronunciation}
                        phx-change={not @input_disabled && "update_answer"}
                        phx-value-field="pronunciation"
                        disabled={@input_disabled}
                        class={[
                          "input input-bordered w-full text-base",
                          @input_disabled && "bg-base-200 opacity-60"
                        ]}
                        placeholder={gettext("Type the reading in hiragana...")}
                        phx-mounted={!@input_disabled && JS.focus(to: "#pronunciation-input")}
                      />
                    </div>
                  <% end %>
                <% end %>

                <div class="flex gap-3 justify-end pt-2">
                  <button
                    type="button"
                    phx-click="cancel_input"
                    disabled={@input_disabled}
                    class={["btn btn-ghost", @input_disabled && "opacity-50 cursor-not-allowed"]}
                  >
                    {gettext("Cancel")}
                  </button>
                  <button
                    type="submit"
                    disabled={@input_disabled}
                    class={["btn btn-primary", @input_disabled && "opacity-50 cursor-not-allowed"]}
                  >
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

  defp grid_cols_class(board_size) do
    case board_size do
      "4x4" -> "grid-cols-4 max-w-md"
      "5x4" -> "grid-cols-5 max-w-lg"
      "6x4" -> "grid-cols-6 max-w-lg"
      "6x5" -> "grid-cols-6 max-w-xl"
      "6x6" -> "grid-cols-6 max-w-lg"
      "8x8" -> "grid-cols-8 max-w-xl"
      "10x10" -> "grid-cols-10 max-w-2xl"
      _ -> "grid-cols-4 max-w-md"
    end
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

  defp word_at_position(session, position, memory_card_game_words) do
    cards_state = session.cards_state || %{}
    card_positions = cards_state["card_positions"] || []
    word_id = Enum.at(card_positions, position)

    Enum.find_value(memory_card_game_words, %{text: "?", reading: ""}, fn mgw ->
      if encode_word_id(mgw.word_id) == word_id do
        mgw.word
      end
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

  defp has_two_flipped?(session) do
    cards_state = session.cards_state || %{}
    flipped = cards_state["flipped_indices"] || []
    length(flipped) == 2
  end

  defp encode_word_id(word_id) do
    case Ecto.UUID.dump(word_id) do
      {:ok, _binary} -> word_id
      :error -> to_string(word_id)
    end
  end

  defp board_size(game) do
    case game.type do
      "kana_memory_cards" ->
        game.kana_memory_card_game.board_size

      _ ->
        game.memory_card_game.board_size
    end
  end

  defp kana_at_position(session, position) do
    cards_state = session.cards_state || %{}
    card_positions = cards_state["card_positions"] || []
    Enum.at(card_positions, position) || "?"
  end
end
