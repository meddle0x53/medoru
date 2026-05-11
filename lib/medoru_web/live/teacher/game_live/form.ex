defmodule MedoruWeb.Teacher.GameLive.Form do
  @moduledoc """
  LiveView for creating and editing memory card games.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Games
  alias Medoru.Learning.WordSets

  defp board_sizes do
    [
      {"4x4 (16 cards, 8 words)", "4x4"},
      {"6x6 (36 cards, 18 words)", "6x6"},
      {"8x8 (64 cards, 32 words)", "8x8"},
      {"10x10 (100 cards, 50 words)", "10x10"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    word_sets = WordSets.list_user_word_sets(user.id, per_page: 100).word_sets

    {:ok,
     socket
     |> assign(:page_title, gettext("Create Game"))
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:search_loading, false)
     |> assign(:selected_words, [])
     |> assign(:form_errors, %{})
     |> assign(:word_sets, word_sets)
     |> assign(:selected_word_set_id, "")}
  end

  @impl true
  def handle_params(%{"classroom_id" => classroom_id, "id" => id}, _url, socket) do
    # Edit mode
    user = socket.assigns.current_scope.current_user
    game = Games.get_game!(id)
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != user.id or game.classroom_id != classroom_id do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to edit this game."))
       |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=games")}
    else
      mcg = game.memory_card_game

      selected_words =
        (mcg.memory_card_game_words || [])
        |> Enum.sort_by(& &1.position)
        |> Enum.map(fn mgw ->
          %{
            word_id: mgw.word_id,
            word: mgw.word,
            points: mgw.points
          }
        end)

      word_sets = WordSets.list_user_word_sets(user.id, per_page: 100).word_sets

      {:noreply,
       socket
       |> assign(:page_title, gettext("Edit Game"))
       |> assign(:classroom, classroom)
       |> assign(:game, game)
       |> assign(:mode, :edit)
       |> assign(:name, game.name)
       |> assign(:board_size, mcg.board_size)
       |> assign(:max_attempts, Integer.to_string(mcg.max_attempts))
       |> assign(:max_players, Integer.to_string(game.max_players))
       |> assign(:meaning_required, mcg.meaning_required_for_collection)
       |> assign(:pronunciation_required, mcg.pronunciation_required_for_collection)
       |> assign(:meaning_or_pronunciation, mcg.meaning_or_pronunciation_required_for_collection)
       |> assign(:selected_words, selected_words)
       |> assign(:word_sets, word_sets)
       |> assign(:selected_word_set_id, "")}
    end
  end

  @impl true
  def handle_params(%{"classroom_id" => classroom_id}, _url, socket) do
    # New mode
    user = socket.assigns.current_scope.current_user
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != user.id do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to create games in this classroom."))
       |> push_navigate(to: ~p"/teacher/classrooms")}
    else
      word_sets = WordSets.list_user_word_sets(user.id, per_page: 100).word_sets

      {:noreply,
       socket
       |> assign(:classroom, classroom)
       |> assign(:game, nil)
       |> assign(:mode, :new)
       |> assign(:name, "")
       |> assign(:board_size, "4x4")
       |> assign(:max_attempts, "10")
       |> assign(:max_players, "1")
       |> assign(:meaning_required, false)
       |> assign(:pronunciation_required, false)
       |> assign(:meaning_or_pronunciation, false)
       |> assign(:word_sets, word_sets)
       |> assign(:selected_word_set_id, "")}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)

    if query == "" do
      {:noreply,
       socket
       |> assign(:search_query, "")
       |> assign(:search_results, [])
       |> assign(:search_loading, false)}
    else
      Process.send_after(self(), {:do_search, query}, 200)

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_loading, true)}
    end
  end

  @impl true
  def handle_event("add_word", %{"word_id" => word_id}, socket) do
    selected = socket.assigns.selected_words

    if Enum.any?(selected, &(&1.word_id == word_id)) do
      {:noreply, put_flash(socket, :error, gettext("Word already selected."))}
    else
      word = Content.get_word!(word_id)

      new_word = %{
        word_id: word.id,
        word: word,
        points: 1
      }

      socket =
        if socket.assigns.form_errors[:words] do
          assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :words))
        else
          socket
        end

      {:noreply,
       socket
       |> assign(:selected_words, selected ++ [new_word])
       |> assign(:search_query, "")
       |> assign(:search_results, [])}
    end
  end

  @impl true
  def handle_event("remove_word", %{"word_id" => word_id}, socket) do
    selected =
      Enum.reject(socket.assigns.selected_words, &(&1.word_id == word_id))

    socket =
      if socket.assigns.form_errors[:words] do
        assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :words))
      else
        socket
      end

    {:noreply, assign(socket, :selected_words, selected)}
  end

  @impl true
  def handle_event("update_points", %{"word_id" => word_id, "points" => points}, socket) do
    points =
      case Integer.parse(points) do
        {n, _} when n > 0 -> n
        _ -> 1
      end

    selected =
      Enum.map(socket.assigns.selected_words, fn sw ->
        if sw.word_id == word_id do
          %{sw | points: points}
        else
          sw
        end
      end)

    socket =
      if socket.assigns.form_errors[:words] do
        assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :words))
      else
        socket
      end

    {:noreply, assign(socket, :selected_words, selected)}
  end

  @impl true
  def handle_event("select_word_set", %{"word_set_id" => word_set_id}, socket) do
    {:noreply, assign(socket, :selected_word_set_id, word_set_id)}
  end

  @impl true
  def handle_event("import_from_word_set", _params, socket) do
    word_set_id = socket.assigns.selected_word_set_id
    selected_words = socket.assigns.selected_words
    board_size = socket.assigns.board_size

    if word_set_id == "" or is_nil(word_set_id) do
      {:noreply, put_flash(socket, :error, gettext("Please select a word set first."))}
    else
      needed = Games.MemoryCardGame.words_needed(board_size)
      current_count = length(selected_words)
      missing = needed - current_count

      if missing <= 0 do
        {:noreply, put_flash(socket, :info, gettext("You already have enough words selected."))}
      else
        # Get words from the word set, ordered by position
        word_set = WordSets.get_word_set!(word_set_id)

        # Filter out words already selected
        existing_ids = Enum.map(selected_words, & &1.word_id)

        new_words =
          word_set.word_set_words
          |> Enum.reject(fn wsw -> wsw.word_id in existing_ids end)
          |> Enum.take(missing)
          |> Enum.map(fn wsw ->
            %{
              word_id: wsw.word_id,
              word: wsw.word,
              points: 1
            }
          end)

        if new_words == [] do
          {:noreply, put_flash(socket, :error, gettext("No new words available in this word set."))}
        else
          socket =
            socket
            |> assign(:selected_words, selected_words ++ new_words)
            |> put_flash(:info, gettext("Imported %{count} words from word set.", count: length(new_words)))

          {:noreply, socket}
        end
      end
    end
  end

  @impl true
  def handle_event("update_field", %{} = params, socket) do
    field = params["field"] || ""

    # When input has a name attribute, the value comes under that name.
    # Otherwise it comes under "value".
    value = params[field] || params["value"] || ""

    socket =
      case field do
        "name" -> assign(socket, :name, value)
        "board_size" -> assign(socket, :board_size, value)
        "max_attempts" -> assign(socket, :max_attempts, value)
        "max_players" -> assign(socket, :max_players, value)
        _ -> socket
      end

    # Clear the error for this field when user types
    error_field =
      case field do
        "name" -> :name
        "board_size" -> :board_size
        "max_attempts" -> :max_attempts
        "max_players" -> :max_players
        _ -> nil
      end

    socket =
      if error_field && socket.assigns.form_errors[error_field] do
        assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, error_field))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_condition", %{"condition" => condition}, socket) do
    socket =
      case condition do
        "meaning_required" ->
          assign(socket, :meaning_required, not socket.assigns.meaning_required)

        "pronunciation_required" ->
          assign(socket, :pronunciation_required, not socket.assigns.pronunciation_required)

        "meaning_or_pronunciation" ->
          assign(socket, :meaning_or_pronunciation, not socket.assigns.meaning_or_pronunciation)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    classroom = socket.assigns.classroom
    user = socket.assigns.current_scope.current_user

    name = String.trim(socket.assigns.name)
    board_size = socket.assigns.board_size
    max_attempts = parse_int(socket.assigns.max_attempts)
    max_players = parse_int(socket.assigns.max_players)
    selected_words = socket.assigns.selected_words

    # Validation
    errors = %{}

    errors =
      if name == "" do
        Map.put(errors, :name, gettext("Name is required"))
      else
        errors
      end

    required_words = Medoru.Games.MemoryCardGame.words_needed(board_size)

    errors =
      if length(selected_words) != required_words do
        Map.put(errors, :words,
          gettext("You must select exactly %{count} words for a %{size} board",
            count: required_words,
            size: board_size
          )
        )
      else
        errors
      end

    errors =
      if max_attempts < 1 do
        Map.put(errors, :max_attempts, gettext("Must be at least 1"))
      else
        errors
      end

    if map_size(errors) > 0 do
      {:noreply, assign(socket, :form_errors, errors)}
    else
      attrs = %{
        "name" => name,
        "max_players" => max_players,
        "memory_card_game" => %{
          "board_size" => board_size,
          "max_attempts" => max_attempts,
          "meaning_required_for_collection" => socket.assigns.meaning_required,
          "pronunciation_required_for_collection" => socket.assigns.pronunciation_required,
          "meaning_or_pronunciation_required_for_collection" => socket.assigns.meaning_or_pronunciation
        }
      }

      word_ids_with_points = Enum.map(selected_words, &{&1.word_id, &1.points})

      result =
        case socket.assigns.mode do
          :new ->
            Games.create_memory_card_game(classroom.id, user.id, attrs, word_ids_with_points)

          :edit ->
            Games.update_memory_card_game(socket.assigns.game, user.id, attrs, word_ids_with_points)
        end

      case result do
        {:ok, _game} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Game saved successfully."))
           |> push_navigate(to: ~p"/teacher/classrooms/#{classroom.id}?tab=games")}

        {:error, :not_authorized} ->
          {:noreply, put_flash(socket, :error, gettext("Not authorized."))}

        {:error, %Ecto.Changeset{} = changeset} ->
          errors =
            Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
              Gettext.dgettext(MedoruWeb.Gettext, "errors", msg, opts)
            end)

          {:noreply, assign(socket, :form_errors, errors)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to save game: %{reason}", reason: inspect(reason)))}
      end
    end
  end

  @impl true
  def handle_info({:do_search, query}, socket) do
    if socket.assigns.search_query == query do
      results = Content.search_words(query, limit: 10)
      existing_ids = Enum.map(socket.assigns.selected_words, & &1.word_id)
      filtered = Enum.reject(results, fn word -> word.id in existing_ids end)

      {:noreply,
       socket
       |> assign(:search_results, filtered)
       |> assign(:search_loading, false)}
    else
      {:noreply, socket}
    end
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> 0
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/classrooms/#{@classroom.id}?tab=games"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Games")}
          </.link>
          <h1 class="text-2xl sm:text-3xl font-bold text-base-content">
            <%= if @mode == :new do %>
              {gettext("Create Memory Card Game")}
            <% else %>
              {gettext("Edit Memory Card Game")}
            <% end %>
          </h1>
        </div>

        <div class="space-y-6">
          <%!-- Basic Info --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-base-content mb-4">{gettext("Basic Info")}</h2>
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-base-content mb-1">
                    {gettext("Game Name")}
                  </label>
                  <form phx-change="update_field" phx-value-field="name" class="contents">
                    <input
                      type="text"
                      name="name"
                      value={@name}
                      phx-debounce="300"
                      class="input input-bordered w-full"
                      placeholder={gettext("e.g., N5 Vocabulary Challenge")}
                    />
                  </form>
                  <%= if @form_errors[:name] do %>
                    <p class="text-error text-sm mt-1">{@form_errors[:name]}</p>
                  <% end %>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-1">
                      {gettext("Max Players")}
                    </label>
                    <form phx-change="update_field" phx-value-field="max_players" class="contents">
                      <input
                        type="number"
                        name="max_players"
                        value={@max_players}
                        min="1"
                        max="10"
                        class="input input-bordered w-full"
                      />
                    </form>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-1">
                      {gettext("Board Size")}
                    </label>
                    <form phx-change="update_field" phx-value-field="board_size" class="contents">
                      <select
                        name="board_size"
                        class="select select-bordered w-full"
                      >
                        <%= for {label, value} <- board_sizes() do %>
                          <option value={value} selected={@board_size == value}>{label}</option>
                        <% end %>
                      </select>
                    </form>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Words Selection --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <h2 class="card-title text-base-content">
                  {gettext("Words")}
                  <span class="badge badge-ghost ml-2">
                    {length(@selected_words)} / {Medoru.Games.MemoryCardGame.words_needed(@board_size)}
                  </span>
                </h2>
              </div>

              <%= if @form_errors[:words] do %>
                <p class="text-error text-sm mb-4">{@form_errors[:words]}</p>
              <% end %>

              <%!-- Search --%>
              <div class="relative mb-4">
                <.icon
                  name="hero-magnifying-glass"
                  class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-secondary"
                />
                <form phx-change="search" class="contents">
                  <input
                    type="text"
                    name="query"
                    value={@search_query}
                    phx-debounce="300"
                    class="input input-bordered w-full pl-10"
                    placeholder={gettext("Search words to add...")}
                  />
                </form>
                <%= if @search_loading do %>
                  <div class="absolute right-3 top-1/2 -translate-y-1/2">
                    <div class="loading loading-spinner loading-sm"></div>
                  </div>
                <% end %>
              </div>

              <%!-- Search Results --%>
              <%= if @search_results != [] do %>
                <div class="border border-base-300 rounded-lg overflow-hidden mb-4 max-h-60 overflow-y-auto">
                  <%= for word <- @search_results do %>
                    <button
                      phx-click="add_word"
                      phx-value-word_id={word.id}
                      class="w-full text-left px-4 py-3 hover:bg-base-200 transition-colors border-b border-base-200 last:border-b-0"
                    >
                      <div class="flex items-center justify-between">
                        <div>
                          <span class="font-medium text-base-content">{word.text}</span>
                          <span class="text-secondary text-sm ml-2">{word.reading}</span>
                        </div>
                        <span class="text-secondary text-sm">{word.meaning}</span>
                      </div>
                    </button>
                  <% end %>
                </div>
              <% end %>

              <%!-- Import from Word Set --%>
              <%= if @word_sets != [] do %>
                <div class="border border-base-300 rounded-lg p-4 mb-4 bg-base-50">
                  <p class="text-sm text-secondary mb-2">
                    {gettext("Import words from a word set to fill missing slots.")}
                  </p>
                  <form phx-change="select_word_set" class="contents">
                    <div class="flex items-center gap-2">
                      <select
                        name="word_set_id"
                        class="select select-bordered select-sm flex-1"
                      >
                        <option value="">{gettext("-- Select a word set --")}</option>
                        <%= for ws <- @word_sets do %>
                          <option value={ws.id} selected={@selected_word_set_id == ws.id}>
                            {ws.name} ({ws.word_count} {gettext("words")})
                          </option>
                        <% end %>
                      </select>
                      <button
                        type="button"
                        phx-click="import_from_word_set"
                        disabled={@selected_word_set_id == ""}
                        class={["btn btn-secondary btn-sm", @selected_word_set_id == "" && "opacity-50 cursor-not-allowed"]}
                      >
                        <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-1" />
                        {gettext("Import")}
                      </button>
                    </div>
                  </form>
                </div>
              <% end %>

              <%!-- Selected Words --%>
              <%= if @selected_words != [] do %>
                <div class="space-y-2">
                  <%= for sw <- @selected_words do %>
                    <div class="flex items-center justify-between p-3 bg-base-200 rounded-lg">
                      <div>
                        <span class="font-medium text-base-content">{sw.word.text}</span>
                        <span class="text-secondary text-sm ml-2">{sw.word.reading}</span>
                        <span class="text-secondary text-sm ml-2">{sw.word.meaning}</span>
                      </div>
                      <div class="flex items-center gap-2">
                        <form phx-change="update_points" phx-value-word_id={sw.word_id} class="contents">
                          <div class="flex items-center gap-1">
                            <span class="text-sm text-secondary">{gettext("Points")}:</span>
                            <input
                              type="number"
                              name="points"
                              value={sw.points}
                              min="1"
                              class="input input-bordered input-sm w-20"
                            />
                          </div>
                        </form>
                        <button
                          phx-click="remove_word"
                          phx-value-word_id={sw.word_id}
                          class="btn btn-ghost btn-sm btn-circle text-error"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <p class="text-secondary text-center py-4">
                  {gettext("No words selected yet. Search and add words above.")}
                </p>
              <% end %>
            </div>
          </div>

          <%!-- Game Rules --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-base-content mb-4">{gettext("Game Rules")}</h2>
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-base-content mb-1">
                    {gettext("Max Attempts")}
                  </label>
                  <form phx-change="update_field" phx-value-field="max_attempts" class="contents">
                    <input
                      type="number"
                      name="max_attempts"
                      value={@max_attempts}
                      min="1"
                      class="input input-bordered w-full sm:w-48"
                    />
                  </form>
                  <p class="text-secondary text-sm mt-1">
                    {gettext("How many times a student can flip two cards.")}
                  </p>
                  <%= if @form_errors[:max_attempts] do %>
                    <p class="text-error text-sm mt-1">{@form_errors[:max_attempts]}</p>
                  <% end %>
                </div>

                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Collection Condition")}
                  </label>
                  <p class="text-secondary text-sm mb-3">
                    {gettext("When two matching cards are found, what must the student do to collect them?")}
                  </p>
                  <div class="space-y-2">
                    <label class="flex items-center gap-3 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={@meaning_required}
                        phx-click="toggle_condition"
                        phx-value-condition="meaning_required"
                        class="checkbox checkbox-primary"
                      />
                      <span class="text-base-content">{gettext("Require correct meaning")}</span>
                    </label>
                    <label class="flex items-center gap-3 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={@pronunciation_required}
                        phx-click="toggle_condition"
                        phx-value-condition="pronunciation_required"
                        class="checkbox checkbox-primary"
                      />
                      <span class="text-base-content">{gettext("Require correct pronunciation")}</span>
                    </label>
                    <label class="flex items-center gap-3 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={@meaning_or_pronunciation}
                        phx-click="toggle_condition"
                        phx-value-condition="meaning_or_pronunciation"
                        class="checkbox checkbox-primary"
                      />
                      <span class="text-base-content">{gettext("Either meaning OR pronunciation (not both)")}</span>
                    </label>
                  </div>
                  <%= if not @meaning_required and not @pronunciation_required and not @meaning_or_pronunciation do %>
                    <p class="text-sm text-secondary mt-2">
                      {gettext("No condition selected — cards will be collected automatically when matched.")}
                    </p>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%!-- Actions --%>
          <div class="flex gap-3">
            <button phx-click="save" class="btn btn-primary">
              <.icon name="hero-check" class="w-4 h-4 mr-1" />
              <%= if @mode == :new do %>
                {gettext("Create Game")}
              <% else %>
                {gettext("Save Changes")}
              <% end %>
            </button>
            <.link
              navigate={~p"/teacher/classrooms/#{@classroom.id}?tab=games"}
              class="btn btn-ghost"
            >
              {gettext("Cancel")}
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
