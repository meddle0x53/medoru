defmodule MedoruWeb.RadicalHuntGameLive.Play do
  @moduledoc """
  LiveView for playing the Radical Hunt game.

  Game state is kept entirely in memory until game over.
  Only then is a session record created in the database.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Games
  alias MedoruWeb.PublicAccess

  embed_templates "*.html"

  @impl true
  def mount(%{"classroom_id" => classroom_id, "game_id" => game_id} = params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    return_to = params["return_to"]
    is_anonymous = is_nil(user)

    classroom = Classrooms.get_classroom!(classroom_id)
    game = Games.get_game_for_play!(game_id)

    has_access =
      if is_anonymous do
        PublicAccess.featured_classroom?(classroom_id)
      else
        Classrooms.is_approved_member?(classroom_id, user.id) or classroom.teacher_id == user.id
      end

    cond do
      game.classroom_id != classroom_id ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      game.status != :published ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      not has_access ->
        redirect_path =
          if is_anonymous, do: ~p"/auth/google", else: ~p"/classrooms/#{classroom_id}"

        {:ok, push_navigate(socket, to: redirect_path)}

      game.type != "radical_hunt" ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      true ->
        config = game.radical_hunt_game
        valid_kanji = Content.list_kanji_by_radical(config.radical)
        valid_characters = MapSet.new(valid_kanji, & &1.character)

        high_score =
          if is_anonymous, do: nil, else: Games.get_radical_hunt_high_score(game_id, user.id)

        sessions = if is_anonymous, do: [], else: Games.list_radical_hunt_sessions(game_id)

        socket =
          socket
          |> assign(:page_title, game.name)
          |> assign(:classroom, classroom)
          |> assign(:game, game)
          |> assign(:config, config)
          |> assign(:return_to, return_to)
          |> assign(:is_anonymous, is_anonymous)
          |> assign(:valid_characters, valid_characters)
          |> assign(:valid_kanji_count, length(valid_kanji))
          |> assign(:high_score, high_score)
          |> assign(:sessions, sessions)
          |> assign(:status, :ready)
          |> assign(:time_remaining, config.timeout_seconds)
          |> assign(:timer_ref, nil)
          |> assign(:input_value, "")
          |> assign(:found_kanji, [])
          |> assign(:last_result, nil)
          |> assign(:score, 0)
          |> assign(:is_mobile, nil)

        {:ok, socket}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    # Ignore stray ticks after game over
    if socket.assigns.status != :playing do
      {:noreply, socket}
    else
      time_remaining = socket.assigns.time_remaining - 1

      if time_remaining <= 0 do
        socket = end_game(socket)
        {:noreply, socket}
      else
        timer_ref = Process.send_after(self(), :tick, 1000)

        {:noreply,
         socket
         |> assign(:time_remaining, time_remaining)
         |> assign(:timer_ref, timer_ref)}
      end
    end
  end

  @impl true
  def handle_event("device_info", %{"is_mobile" => is_mobile}, socket) do
    {:noreply, assign(socket, :is_mobile, is_mobile)}
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    timer_ref = Process.send_after(self(), :tick, 1000)

    {:noreply,
     socket
     |> assign(:status, :playing)
     |> assign(:timer_ref, timer_ref)
     |> assign(:time_remaining, socket.assigns.config.timeout_seconds)
     |> assign(:found_kanji, [])
     |> assign(:score, 0)
     |> assign(:last_result, nil)
     |> assign(:input_value, "")
     |> push_event("request_fullscreen", %{})}
  end

  @impl true
  def handle_event("start_game_fullscreen", _params, socket) do
    timer_ref = Process.send_after(self(), :tick, 1000)

    {:noreply,
     socket
     |> assign(:status, :playing)
     |> assign(:timer_ref, timer_ref)
     |> assign(:time_remaining, socket.assigns.config.timeout_seconds)
     |> assign(:found_kanji, [])
     |> assign(:score, 0)
     |> assign(:last_result, nil)
     |> assign(:input_value, "")
     |> push_event("force_fullscreen", %{})}
  end

  @impl true
  def handle_event("submit_kanji", params, socket) do
    input = String.trim(params["kanji"] || "")

    cond do
      input == "" ->
        {:noreply, socket}

      String.length(input) != 1 ->
        {:noreply,
         socket
         |> assign(:last_result, :incorrect)
         |> assign(:input_value, "")}

      input in socket.assigns.found_kanji ->
        {:noreply,
         socket
         |> assign(:last_result, :already_found)
         |> assign(:input_value, "")}

      input in socket.assigns.valid_characters ->
        found_kanji = [input | socket.assigns.found_kanji]
        score = fibonacci_score(length(found_kanji))

        {:noreply,
         socket
         |> assign(:found_kanji, found_kanji)
         |> assign(:score, score)
         |> assign(:last_result, :correct)
         |> assign(:input_value, "")}

      true ->
        {:noreply,
         socket
         |> assign(:last_result, :incorrect)
         |> assign(:input_value, "")}
    end
  end

  @impl true
  def handle_event("play_again", _params, socket) do
    # Cancel any lingering timer
    if socket.assigns[:timer_ref], do: Process.cancel_timer(socket.assigns.timer_ref)

    {:noreply,
     socket
     |> assign(:status, :ready)
     |> assign(:time_remaining, socket.assigns.config.timeout_seconds)
     |> assign(:timer_ref, nil)
     |> assign(:found_kanji, [])
     |> assign(:last_result, nil)
     |> assign(:score, 0)
     |> assign(:input_value, "")
     |> push_event("exit_fullscreen", %{})}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:timer_ref], do: Process.cancel_timer(socket.assigns.timer_ref)
    :ok
  end

  defp end_game(socket) do
    if socket.assigns[:timer_ref], do: Process.cancel_timer(socket.assigns.timer_ref)

    user = socket.assigns.current_scope.current_user
    game = socket.assigns.game
    score = socket.assigns.score
    found_kanji = socket.assigns.found_kanji

    # Save session for authenticated users (always save so rankings show up)
    sessions =
      if user do
        now = DateTime.utc_now()

        _ =
          Games.create_radical_hunt_session(%{
            game_id: game.id,
            user_id: user.id,
            status: "completed",
            score: score,
            kanji_found: found_kanji,
            started_at: DateTime.add(now, -game.radical_hunt_game.timeout_seconds, :second),
            completed_at: now
          })

        Games.list_radical_hunt_sessions(game.id)
      else
        socket.assigns.sessions
      end

    high_score =
      if user do
        Games.get_radical_hunt_high_score(game.id, user.id)
      else
        socket.assigns.high_score
      end

    socket
    |> assign(:status, :game_over)
    |> assign(:timer_ref, nil)
    |> assign(:time_remaining, 0)
    |> assign(:score, score)
    |> assign(:found_kanji, found_kanji)
    |> assign(:last_result, nil)
    |> assign(:input_value, "")
    |> assign(:sessions, sessions)
    |> assign(:high_score, high_score)
    |> push_event("exit_fullscreen", %{})
  end

  # Fibonacci scoring: 1, 1, 2, 3, 5, 8, ...
  # Sum of first N Fibonacci numbers
  # Fibonacci point for a specific index (1-based)
  # 1 → 1, 2 → 1, 3 → 2, 4 → 3, 5 → 5, 6 → 8...
  defp fibonacci_point_for_index(1), do: 1
  defp fibonacci_point_for_index(2), do: 1

  defp fibonacci_point_for_index(n) when n > 2 do
    do_fib_point(n, 1, 1)
  end

  defp do_fib_point(2, _a, b), do: b

  defp do_fib_point(n, a, b) do
    do_fib_point(n - 1, b, a + b)
  end

  # Total Fibonacci score for N found kanji
  defp fibonacci_score(0), do: 0
  defp fibonacci_score(1), do: 1
  defp fibonacci_score(2), do: 2

  defp fibonacci_score(n) when n > 2 do
    do_fib_sum(n, 1, 1, 2)
  end

  defp do_fib_sum(2, _a, _b, sum), do: sum

  defp do_fib_sum(n, a, b, sum) do
    next = a + b
    do_fib_sum(n - 1, b, next, sum + next)
  end

  defp format_time(seconds) do
    m = div(seconds, 60)
    s = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(m), 2, "0")}:#{String.pad_leading(Integer.to_string(s), 2, "0")}"
  end
end
