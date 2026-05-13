defmodule MedoruWeb.KanaFallingGameLive.Play do
  @moduledoc """
  LiveView for playing the kana falling typing game.

  Game state is kept entirely in memory (socket assigns) until game over.
  Only then is a session record created in the database.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content.Kana
  alias Medoru.Games

  @death_row 20

  embed_templates "*.html"

  @impl true
  def mount(%{"classroom_id" => classroom_id, "game_id" => game_id}, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Verify user is an approved member of the classroom
    classroom = Classrooms.get_classroom!(classroom_id)
    game = Games.get_game_for_play!(game_id)

    cond do
      game.classroom_id != classroom_id ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      game.status != :published ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      not Classrooms.is_approved_member?(classroom_id, user.id) ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      game.type != "kana_falling" ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      true ->
        config = game.kana_falling_game
        high_score = Games.get_kana_falling_high_score(game_id, user.id)

        socket =
          socket
          |> assign(:page_title, game.name)
          |> assign(:classroom, classroom)
          |> assign(:game, game)
          |> assign(:config, config)
          |> assign(:high_score, high_score)
          |> assign(:status, :ready)
          |> assign(:current_kana, nil)
          |> assign(:score, 0)
          |> assign(:speed, config.initial_speed)
          |> assign(:lives, config.lives)
          |> assign(:max_lives, config.lives)
          |> assign(:next_speed_up_score, config.speed_increase_threshold)
          |> assign(:next_extra_life_score, config.extra_life_threshold)
          |> assign(:input_buffer, "")
          |> assign(:kana_pool, build_kana_pool(config.selected_kana))
          |> assign(:started_at, nil)
          |> assign(:highest_speed_reached, config.initial_speed)
          |> assign(:highest_row_reached, 0)
          |> assign(:lives_used, 0)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    socket = spawn_kana(socket)
    tick_ms = Games.KanaFallingGame.speed_to_ms(socket.assigns.speed)

    timer_ref = Process.send_after(self(), :tick, tick_ms)

    {:noreply,
     socket
     |> assign(:status, :playing)
     |> assign(:started_at, DateTime.utc_now())
     |> assign(:timer_ref, timer_ref)
     |> push_event("request_fullscreen", %{})}
  end

  @impl true
  def handle_event("key_pressed", %{"key" => key}, socket) do
    cond do
      key in ["p", "P"] and socket.assigns.status == :playing ->
        {:noreply, pause_game(socket)}

      key in ["p", "P"] and socket.assigns.status == :paused ->
        {:noreply, resume_game(socket)}

      key == "Escape" and socket.assigns.status in [:playing, :paused] ->
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
     |> assign(:current_kana, nil)
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
      socket = move_kana_down(socket)

      if socket.assigns.status == :game_over do
        {:noreply, socket}
      else
        tick_ms = Games.KanaFallingGame.speed_to_ms(socket.assigns.speed)
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
    tick_ms = Games.KanaFallingGame.speed_to_ms(socket.assigns.speed)
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
    |> assign(:current_kana, nil)
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
    # Cancel any pending timer when the LiveView terminates
    if socket.assigns[:timer_ref] do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    :ok
  end

  # ============================================================================
  # Game Logic
  # ============================================================================

  defp build_kana_pool(selected_kana) do
    all_kana = Kana.list_all()

    selected_kana
    |> Enum.map(fn char ->
      case Enum.find(all_kana, &(&1.character == char)) do
        nil -> nil
        kana -> %{char: kana.character, romaji: kana_romaji(kana)}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp kana_romaji(kana) do
    reading = List.first(kana.readings) || %{}
    String.downcase(reading[:romaji] || "")
  end

  defp spawn_kana(socket) do
    pool = socket.assigns.kana_pool
    kana = Enum.random(pool)

    socket
    |> assign(:current_kana, Map.put(kana, :row, 1))
    |> assign(:input_buffer, "")
  end

  defp move_kana_down(socket) do
    current_kana = socket.assigns.current_kana
    new_row = current_kana.row + 1

    highest_row = max(socket.assigns.highest_row_reached, new_row)
    socket = assign(socket, :highest_row_reached, highest_row)

    if new_row >= @death_row do
      lose_life(socket)
    else
      assign(socket, :current_kana, %{current_kana | row: new_row})
    end
  end

  defp handle_key(socket, key) do
    cond do
      key == "Backspace" ->
        buffer = socket.assigns.input_buffer
        new_buffer = String.slice(buffer, 0, max(String.length(buffer) - 1, 0))
        {:noreply, assign(socket, :input_buffer, new_buffer)}

      key == "Enter" ->
        socket =
          if socket.assigns.input_buffer == socket.assigns.current_kana.romaji do
            correct_answer(socket)
          else
            wrong_answer(socket)
          end
        {:noreply, socket}

      String.length(key) == 1 and key =~ ~r/^[a-zA-Z]$/ ->
        buffer = socket.assigns.input_buffer <> String.downcase(key)
        socket = assign(socket, :input_buffer, buffer)
        current_kana = socket.assigns.current_kana
        romaji = current_kana.romaji

        cond do
          buffer == romaji ->
            # Correct!
            socket = correct_answer(socket)
            {:noreply, socket}

          not String.starts_with?(romaji, buffer) ->
            # Wrong - buffer doesn't match prefix
            socket = wrong_answer(socket)
            {:noreply, socket}

          true ->
            # Still typing, wait for more
            {:noreply, socket}
        end

      true ->
        {:noreply, socket}
    end
  end

  defp correct_answer(socket) do
    config = socket.assigns.config
    new_score = socket.assigns.score + config.points_per_kana

    socket =
      socket
      |> assign(:score, new_score)
      |> assign(:input_buffer, "")

    # Check speed increase
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

    # Check extra life
    socket =
      if new_score >= socket.assigns.next_extra_life_score and socket.assigns.lives < socket.assigns.max_lives do
        socket
        |> assign(:lives, socket.assigns.lives + 1)
        |> assign(:next_extra_life_score, new_score + config.extra_life_threshold)
      else
        socket
      end

    # Spawn new kana
    spawn_kana(socket)
  end

  defp wrong_answer(socket) do
    current_kana = socket.assigns.current_kana
    new_row = current_kana.row + 2

    socket =
      if new_row >= @death_row do
        lose_life(socket)
      else
        assign(socket, :current_kana, %{current_kana | row: new_row})
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
      game_over(socket)
    else
      spawn_kana(socket)
    end
  end

  defp game_over(socket) do
    # Cancel timer
    if socket.assigns[:timer_ref] do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    # Save session
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

    {:ok, _session} = Games.create_kana_falling_session(attrs)

    # Refresh high score
    high_score = Games.get_kana_falling_high_score(game.id, user.id)

    # Get rankings
    sessions = Games.list_kana_falling_sessions(game.id)

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
    # Each row is 2.5% of the container height (40 rows = 100%)
    top = (row - 1) * 2.5
    "top: #{top}%;"
  end

  def speed_label(speed) do
    case speed do
      1 -> "Very Slow"
      2 -> "Slow"
      3 -> "Slow-Medium"
      4 -> "Medium"
      5 -> "Medium-Fast"
      6 -> "Fast"
      7 -> "Fast"
      8 -> "Very Fast"
      9 -> "Very Fast"
      10 -> "Extreme"
      _ -> "Unknown"
    end
  end
end
