defmodule MedoruWeb.KanjiFallingGameLive.Play do
  @moduledoc """
  LiveView for playing the kanji falling typing game.

  Game state is kept entirely in memory (socket assigns) until game over.
  Only then is a session record created in the database.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Games

  @death_row 20

  embed_templates "*.html"

  @impl true
  def mount(%{"classroom_id" => classroom_id, "game_id" => game_id}, _session, socket) do
    user = socket.assigns.current_scope.current_user

    classroom = Classrooms.get_classroom!(classroom_id)
    game = Games.get_game_for_play!(game_id)

    cond do
      game.classroom_id != classroom_id ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      game.status != :published ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      not Classrooms.is_approved_member?(classroom_id, user.id) ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      game.type != "kanji_falling" ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      true ->
        config = game.kanji_falling_game
        high_score = Games.get_kanji_falling_high_score(game_id, user.id)
        sessions = Games.list_kanji_falling_sessions(game_id)

        socket =
          socket
          |> assign(:page_title, game.name)
          |> assign(:classroom, classroom)
          |> assign(:game, game)
          |> assign(:config, config)
          |> assign(:high_score, high_score)
          |> assign(:sessions, sessions)
          |> assign(:status, :ready)
          |> assign(:current_kanji, nil)
          |> assign(:score, 0)
          |> assign(:speed, config.initial_speed)
          |> assign(:lives, config.lives)
          |> assign(:max_lives, config.lives)
          |> assign(:next_speed_up_score, config.speed_increase_threshold)
          |> assign(:next_extra_life_score, config.extra_life_threshold)
          |> assign(:input_buffer, "")
          |> assign(:is_mobile, nil)
          |> assign(:kanji_pool, build_kanji_pool(config.selected_kanji, config))
          |> assign(:started_at, nil)
          |> assign(:highest_speed_reached, config.initial_speed)
          |> assign(:highest_row_reached, 0)
          |> assign(:lives_used, 0)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("device_info", %{"is_mobile" => is_mobile}, socket) do
    {:noreply, assign(socket, :is_mobile, is_mobile)}
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    socket = spawn_kanji(socket)
    tick_ms = Games.KanjiFallingGame.speed_to_ms(socket.assigns.speed)

    timer_ref = Process.send_after(self(), :tick, tick_ms)

    {:noreply,
     socket
     |> assign(:status, :playing)
     |> assign(:started_at, DateTime.utc_now())
     |> assign(:timer_ref, timer_ref)
     |> push_event("request_fullscreen", %{})}
  end

  @impl true
  def handle_event("start_game_fullscreen", _params, socket) do
    socket = spawn_kanji(socket)
    tick_ms = Games.KanjiFallingGame.speed_to_ms(socket.assigns.speed)

    timer_ref = Process.send_after(self(), :tick, tick_ms)

    {:noreply,
     socket
     |> assign(:status, :playing)
     |> assign(:started_at, DateTime.utc_now())
     |> assign(:timer_ref, timer_ref)
     |> push_event("force_fullscreen", %{})}
  end

  @impl true
  def handle_event("key_pressed", %{"key" => key}, socket) do
    cond do
      key == "Escape" and socket.assigns.status == :playing ->
        {:noreply, pause_game(socket)}

      key == "Escape" and socket.assigns.status == :paused ->
        {:noreply, exit_game(socket)}

      socket.assigns.status == :playing ->
        handle_key(socket, key)

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("pause_game", _params, socket) do
    {:noreply, pause_game(socket)}
  end

  @impl true
  def handle_event("resume_game", _params, socket) do
    {:noreply, resume_game(socket)}
  end

  @impl true
  def handle_event("exit_game", _params, socket) do
    {:noreply, exit_game(socket)}
  end

  @impl true
  def handle_event("restart_game", _params, socket) do
    config = socket.assigns.config

    {:noreply,
     socket
     |> assign(:status, :ready)
     |> assign(:current_kanji, nil)
     |> assign(:score, 0)
     |> assign(:speed, config.initial_speed)
     |> assign(:lives, config.lives)
     |> assign(:next_speed_up_score, config.speed_increase_threshold)
     |> assign(:next_extra_life_score, config.extra_life_threshold)
     |> assign(:input_buffer, "")
     |> assign(:started_at, nil)
     |> assign(:highest_speed_reached, config.initial_speed)
     |> assign(:highest_row_reached, 0)
     |> assign(:lives_used, 0)
     |> assign(:timer_ref, nil)}
  end

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.status != :playing do
      {:noreply, socket}
    else
      socket = move_kanji_down(socket)

      if socket.assigns.status == :game_over do
        {:noreply, socket}
      else
        tick_ms = Games.KanjiFallingGame.speed_to_ms(socket.assigns.speed)
        timer_ref = Process.send_after(self(), :tick, tick_ms)
        {:noreply, assign(socket, :timer_ref, timer_ref)}
      end
    end
  end

  defp pause_game(socket) do
    if socket.assigns[:timer_ref] do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    assign(socket, status: :paused, timer_ref: nil)
  end

  defp resume_game(socket) do
    tick_ms = Games.KanjiFallingGame.speed_to_ms(socket.assigns.speed)
    timer_ref = Process.send_after(self(), :tick, tick_ms)
    assign(socket, status: :playing, timer_ref: timer_ref)
  end

  defp exit_game(socket) do
    if socket.assigns[:timer_ref] do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    config = socket.assigns.config

    socket
    |> assign(:status, :ready)
    |> assign(:current_kanji, nil)
    |> assign(:score, 0)
    |> assign(:speed, config.initial_speed)
    |> assign(:lives, config.lives)
    |> assign(:next_speed_up_score, config.speed_increase_threshold)
    |> assign(:next_extra_life_score, config.extra_life_threshold)
    |> assign(:input_buffer, "")
    |> assign(:started_at, nil)
    |> assign(:highest_speed_reached, config.initial_speed)
    |> assign(:highest_row_reached, 0)
    |> assign(:lives_used, 0)
    |> assign(:timer_ref, nil)
    |> push_event("exit_fullscreen", %{})
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:timer_ref] do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    :ok
  end

  # ============================================================================
  # Game Logic
  # ============================================================================

  defp build_kanji_pool(selected_kanji, config) do
    colors = config.kanji_colors || %{}

    selected_kanji
    |> Enum.map(fn char ->
      case Content.get_kanji_by_character(char) do
        nil ->
          nil

        kanji ->
          readings = kanji.kanji_readings || []

          filtered =
            case config.reading_type do
              "onyomi" -> Enum.filter(readings, &(&1.reading_type == :on))
              "kunyomi" -> Enum.filter(readings, &(&1.reading_type == :kun))
              _ -> readings
            end

          readings_hiragana =
            filtered
            |> Enum.map(fn r ->
              reading = r.reading
              reading = katakana_to_hiragana(reading)
              String.replace(reading, ".", "")
            end)
            |> Enum.uniq()

          readings_romaji =
            filtered
            |> Enum.map(fn r ->
              String.downcase(r.romaji || "")
            end)
            |> Enum.reject(&(&1 == ""))
            |> Enum.uniq()

          %{
            char: char,
            readings_hiragana: readings_hiragana,
            readings_romaji: readings_romaji,
            color: Map.get(colors, char, "#1a1a1a")
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp katakana_to_hiragana(str) do
    str
    |> String.to_charlist()
    |> Enum.map(fn cp ->
      if cp >= 0x30A1 and cp <= 0x30F6 do
        cp - 0x60
      else
        cp
      end
    end)
    |> List.to_string()
  end

  defp spawn_kanji(socket) do
    pool = socket.assigns.kanji_pool
    kanji = Enum.random(pool)

    socket
    |> assign(:current_kanji, Map.put(kanji, :row, 1))
    |> assign(:input_buffer, "")
  end

  defp move_kanji_down(socket) do
    current_kanji = socket.assigns.current_kanji
    new_row = current_kanji.row + 1

    highest_row = max(socket.assigns.highest_row_reached, new_row)
    socket = assign(socket, :highest_row_reached, highest_row)

    if new_row >= @death_row do
      lose_life(socket)
    else
      assign(socket, :current_kanji, %{current_kanji | row: new_row})
    end
  end

  defp handle_key(socket, key) do
    cond do
      key == "Backspace" ->
        buffer = socket.assigns.input_buffer
        new_buffer = String.slice(buffer, 0, max(String.length(buffer) - 1, 0))
        {:noreply, assign(socket, :input_buffer, new_buffer)}

      key == "Enter" ->
        socket = check_answer(socket)
        {:noreply, socket}

      String.length(key) == 1 ->
        buffer = socket.assigns.input_buffer <> key
        socket = assign(socket, :input_buffer, buffer)
        check_buffer(socket)

      true ->
        {:noreply, socket}
    end
  end

  defp check_buffer(socket) do
    buffer = socket.assigns.input_buffer
    current_kanji = socket.assigns.current_kanji

    readings_list =
      if contains_hiragana?(buffer) do
        current_kanji.readings_hiragana
      else
        current_kanji.readings_romaji
      end

    cond do
      buffer in readings_list ->
        socket = correct_answer(socket)
        {:noreply, socket}

      Enum.any?(readings_list, &String.starts_with?(&1, buffer)) ->
        {:noreply, socket}

      true ->
        socket = wrong_answer(socket)
        {:noreply, socket}
    end
  end

  defp check_answer(socket) do
    buffer = socket.assigns.input_buffer
    current_kanji = socket.assigns.current_kanji

    readings_list =
      if contains_hiragana?(buffer) do
        current_kanji.readings_hiragana
      else
        current_kanji.readings_romaji
      end

    if buffer in readings_list do
      correct_answer(socket)
    else
      wrong_answer(socket)
    end
  end

  defp contains_hiragana?(str) do
    str
    |> String.to_charlist()
    |> Enum.any?(fn cp -> cp >= 0x3040 and cp <= 0x309F end)
  end

  defp correct_answer(socket) do
    config = socket.assigns.config
    new_score = socket.assigns.score + config.points_per_kanji

    socket =
      socket
      |> assign(:score, new_score)
      |> assign(:input_buffer, "")

    socket =
      if new_score >= socket.assigns.next_speed_up_score and socket.assigns.speed < 10 do
        new_speed = socket.assigns.speed + 1

        socket
        |> assign(:speed, new_speed)
        |> assign(:next_speed_up_score, new_score + config.speed_increase_threshold)
        |> assign(:highest_speed_reached, max(socket.assigns.highest_speed_reached, new_speed))
      else
        socket
      end

    socket =
      if new_score >= socket.assigns.next_extra_life_score and
           socket.assigns.lives < socket.assigns.max_lives do
        socket
        |> assign(:lives, socket.assigns.lives + 1)
        |> assign(:next_extra_life_score, new_score + config.extra_life_threshold)
      else
        socket
      end

    socket = push_kanji_destroyed(socket)
    spawn_kanji(socket)
  end

  defp wrong_answer(socket) do
    current_kanji = socket.assigns.current_kanji
    new_row = current_kanji.row + 2

    socket =
      if new_row >= @death_row do
        lose_life(socket)
      else
        assign(socket, :current_kanji, %{current_kanji | row: new_row})
      end

    assign(socket, :input_buffer, "")
  end

  defp lose_life(socket) do
    new_lives = socket.assigns.lives - 1
    lives_used = socket.assigns.lives_used + 1

    socket =
      socket
      |> assign(:lives, new_lives)
      |> assign(:lives_used, lives_used)

    if new_lives <= 0 do
      push_kanji_destroyed(socket)
      game_over(socket)
    else
      socket = push_kanji_destroyed(socket)
      spawn_kanji(socket)
    end
  end

  defp push_kanji_destroyed(socket) do
    current_kanji = socket.assigns.current_kanji

    if current_kanji do
      push_event(socket, "kana_destroyed", %{
        char: current_kanji.char,
        row: current_kanji.row
      })
    else
      socket
    end
  end

  defp game_over(socket) do
    if socket.assigns[:timer_ref] do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    game = socket.assigns.game
    user = socket.assigns.current_scope.current_user
    started_at = socket.assigns.started_at
    now = DateTime.utc_now()

    attrs = %{
      game_id: game.id,
      user_id: user.id,
      status: "completed",
      score: socket.assigns.score,
      highest_speed_reached: socket.assigns.highest_speed_reached,
      lives_remaining: 0,
      lives_used: socket.assigns.lives_used,
      highest_row_reached: socket.assigns.highest_row_reached,
      started_at: started_at,
      completed_at: now
    }

    {:ok, _session} = Games.create_kanji_falling_session(attrs)

    high_score = Games.get_kanji_falling_high_score(game.id, user.id)
    sessions = Games.list_kanji_falling_sessions(game.id)

    assign(socket,
      status: :game_over,
      high_score: high_score,
      sessions: sessions
    )
  end

  # ============================================================================
  # Helpers for template
  # ============================================================================

  def row_position_css(row) do
    top = (row - 1) * 2.5
    "top: #{top}%;"
  end

  def speed_label(speed) do
    case speed do
      1 -> gettext("Very Slow")
      2 -> gettext("Slow")
      3 -> gettext("Slow-Medium")
      4 -> gettext("Medium")
      5 -> gettext("Medium-Fast")
      6 -> gettext("Fast")
      7 -> gettext("Fast")
      8 -> gettext("Very Fast")
      9 -> gettext("Very Fast")
      10 -> gettext("Extreme")
      _ -> gettext("Unknown")
    end
  end

  def reading_type_label(type) do
    case type do
      "any" -> gettext("Any reading")
      "onyomi" -> gettext("On'yomi only")
      "kunyomi" -> gettext("Kun'yomi only")
      _ -> type
    end
  end
end
