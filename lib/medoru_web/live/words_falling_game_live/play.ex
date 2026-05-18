defmodule MedoruWeb.WordsFallingGameLive.Play do
  @moduledoc """
  LiveView for playing the words falling typing game.

  Game state is kept entirely in memory (socket assigns) until game over.
  Only then is a session record created in the database.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Content.Kana
  alias Medoru.Games
  alias Medoru.Games.WordsFallingGame
  alias MedoruWeb.PublicAccess

  @death_row 20

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

      game.type != "words_falling" ->
        {:ok, push_navigate(socket, to: ~p"/classrooms/#{classroom_id}")}

      true ->
        config = game.words_falling_game

        high_score =
          if is_anonymous, do: nil, else: Games.get_words_falling_high_score(game_id, user.id)

        sessions = if is_anonymous, do: [], else: Games.list_words_falling_sessions(game.id)
        locale = socket.assigns.current_scope.locale || "en"

        socket =
          socket
          |> assign(:page_title, game.name)
          |> assign(:classroom, classroom)
          |> assign(:game, game)
          |> assign(:return_to, return_to)
          |> assign(:is_anonymous, is_anonymous)
          |> assign(:config, config)
          |> assign(:high_score, high_score)
          |> assign(:sessions, sessions)
          |> assign(:status, :ready)
          |> assign(:current_word, nil)
          |> assign(:score, 0)
          |> assign(:speed, config.initial_speed)
          |> assign(:lives, config.lives)
          |> assign(:max_lives, config.lives)
          |> assign(:next_speed_up_score, config.speed_increase_threshold)
          |> assign(:next_extra_life_score, config.extra_life_threshold)
          |> assign(:input_buffer, "")
          |> assign(:is_mobile, nil)
          |> assign(:word_pool, build_word_pool(config, locale))
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
    socket = spawn_word(socket)
    tick_ms = WordsFallingGame.speed_to_ms(socket.assigns.speed)

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
    socket = spawn_word(socket)
    tick_ms = WordsFallingGame.speed_to_ms(socket.assigns.speed)

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
    locale = socket.assigns.current_scope.locale || "en"

    {:noreply,
     socket
     |> assign(:status, :ready)
     |> assign(:current_word, nil)
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
     |> assign(:word_pool, build_word_pool(config, locale))}
  end

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.status != :playing do
      {:noreply, socket}
    else
      socket = move_word_down(socket)

      if socket.assigns.status == :game_over do
        {:noreply, socket}
      else
        tick_ms = WordsFallingGame.speed_to_ms(socket.assigns.speed)
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
    tick_ms = WordsFallingGame.speed_to_ms(socket.assigns.speed)
    timer_ref = Process.send_after(self(), :tick, tick_ms)
    assign(socket, status: :playing, timer_ref: timer_ref)
  end

  defp exit_game(socket) do
    if socket.assigns[:timer_ref] do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    config = socket.assigns.config
    locale = socket.assigns.current_scope.locale || "en"

    socket
    |> assign(:status, :ready)
    |> assign(:current_word, nil)
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
    |> assign(:word_pool, build_word_pool(config, locale))
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

  defp build_word_pool(config, locale) do
    colors = config.word_colors || %{}
    word_points = config.word_points || %{}
    kana_map = build_kana_romaji_map()

    config.selected_words
    |> Enum.map(fn word_id ->
      case Content.get_word(word_id) do
        nil ->
          nil

        word ->
          word_id_str = to_string(word_id)

          meanings =
            [word.meaning, Content.get_localized_meaning(word, locale)]
            |> Enum.reject(&is_nil/1)
            |> Enum.flat_map(&split_alternatives/1)
            |> Enum.map(&String.downcase(String.trim(&1)))
            |> Enum.uniq()

          readings_hiragana =
            if word.reading do
              word.reading
              |> split_alternatives()
              |> Enum.map(&String.trim/1)
              |> Enum.uniq()
            else
              []
            end

          readings_romaji =
            if word.reading do
              word.reading
              |> split_alternatives()
              |> Enum.map(fn reading ->
                reading
                |> String.trim()
                |> hiragana_to_romaji(kana_map)
              end)
              |> Enum.reject(&(&1 == ""))
              |> Enum.uniq()
            else
              []
            end

          %{
            id: word_id,
            char: word.text,
            meanings: meanings,
            readings: readings_hiragana,
            readings_romaji: readings_romaji,
            color: Map.get(colors, word_id_str, "#1a1a1a"),
            points: Map.get(word_points, word_id_str, 1)
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp split_alternatives(text) when is_binary(text) do
    text
    |> String.split("/")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_alternatives(_), do: []

  defp spawn_word(socket) do
    pool = socket.assigns.word_pool
    word = Enum.random(pool)

    socket
    |> assign(:current_word, Map.put(word, :row, 1))
    |> assign(:input_buffer, "")
  end

  defp move_word_down(socket) do
    current_word = socket.assigns.current_word
    new_row = current_word.row + 1

    highest_row = max(socket.assigns.highest_row_reached, new_row)
    socket = assign(socket, :highest_row_reached, highest_row)

    if new_row >= @death_row do
      lose_life(socket)
    else
      assign(socket, :current_word, %{current_word | row: new_row})
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
    current_word = socket.assigns.current_word

    answers_list = answers_for_buffer(buffer, current_word, socket.assigns.config)
    buffer_check = String.downcase(String.trim(buffer))

    cond do
      buffer_check in answers_list ->
        socket = correct_answer(socket)
        {:noreply, socket}

      Enum.any?(answers_list, &String.starts_with?(&1, buffer_check)) ->
        {:noreply, socket}

      true ->
        socket = wrong_answer(socket)
        {:noreply, socket}
    end
  end

  defp check_answer(socket) do
    buffer = socket.assigns.input_buffer
    current_word = socket.assigns.current_word

    answers_list = answers_for_buffer(buffer, current_word, socket.assigns.config)
    buffer_check = String.downcase(String.trim(buffer))

    if buffer_check in answers_list do
      correct_answer(socket)
    else
      wrong_answer(socket)
    end
  end

  defp answers_for_buffer(buffer, current_word, config) do
    game_mode = WordsFallingGame.game_mode_label(config.game_mode)

    case game_mode do
      :meaning ->
        current_word.meanings

      :reading ->
        if contains_hiragana?(buffer) do
          current_word.readings
        else
          current_word.readings_romaji
        end
    end
  end

  defp contains_hiragana?(str) do
    str
    |> String.to_charlist()
    |> Enum.any?(fn cp -> cp >= 0x3040 and cp <= 0x309F end)
  end

  defp build_kana_romaji_map do
    Kana.list_all()
    |> Enum.map(fn kana ->
      romaji = List.first(kana.readings, %{romaji: ""}).romaji
      {kana.character, String.downcase(romaji)}
    end)
    |> Map.new()
  end

  defp hiragana_to_romaji(hiragana, kana_map) do
    hiragana
    |> String.graphemes()
    |> Enum.reduce({"", nil}, fn char, {acc, prev} ->
      romaji = Map.get(kana_map, char, "")

      cond do
        char == "っ" ->
          {acc, "っ"}

        char in ["ゃ", "ゅ", "ょ"] and prev != nil ->
          vowel =
            case char do
              "ゃ" -> "a"
              "ゅ" -> "u"
              "ょ" -> "o"
            end

          base =
            case prev do
              "shi" -> "sh"
              "chi" -> "ch"
              "ji" -> "j"
              "tsu" -> "ts"
              other -> String.replace_trailing(other, "i", "")
            end

          combined =
            if base == String.replace_trailing(prev, "i", "") and
                 prev not in ["shi", "chi", "ji", "tsu"] do
              base <> "y" <> vowel
            else
              base <> vowel
            end

          prev_len = String.length(prev)
          acc_len = String.length(acc)
          new_acc = String.slice(acc, 0, max(acc_len - prev_len, 0)) <> combined
          {new_acc, nil}

        prev == "っ" ->
          consonant =
            case romaji do
              "chi" -> "t"
              "tsu" -> "t"
              "shi" -> "s"
              "ji" -> "j"
              "fu" -> "f"
              other -> String.first(other) || ""
            end

          {acc <> consonant <> romaji, romaji}

        true ->
          {acc <> romaji, romaji}
      end
    end)
    |> elem(0)
  end

  defp correct_answer(socket) do
    current_word = socket.assigns.current_word
    new_score = socket.assigns.score + current_word.points

    socket =
      socket
      |> assign(:score, new_score)
      |> assign(:input_buffer, "")

    socket =
      if new_score >= socket.assigns.next_speed_up_score and socket.assigns.speed < 10 do
        new_speed = socket.assigns.speed + 1

        socket
        |> assign(:speed, new_speed)
        |> assign(
          :next_speed_up_score,
          new_score + socket.assigns.config.speed_increase_threshold
        )
        |> assign(:highest_speed_reached, max(socket.assigns.highest_speed_reached, new_speed))
      else
        socket
      end

    socket =
      if new_score >= socket.assigns.next_extra_life_score and
           socket.assigns.lives < socket.assigns.max_lives do
        socket
        |> assign(:lives, socket.assigns.lives + 1)
        |> assign(:next_extra_life_score, new_score + socket.assigns.config.extra_life_threshold)
      else
        socket
      end

    socket = push_word_destroyed(socket)
    spawn_word(socket)
  end

  defp wrong_answer(socket) do
    current_word = socket.assigns.current_word
    new_row = current_word.row + 2

    socket =
      if new_row >= @death_row do
        lose_life(socket)
      else
        assign(socket, :current_word, %{current_word | row: new_row})
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
      push_word_destroyed(socket)
      game_over(socket)
    else
      socket = push_word_destroyed(socket)
      spawn_word(socket)
    end
  end

  defp push_word_destroyed(socket) do
    current_word = socket.assigns.current_word

    if current_word do
      push_event(socket, "kana_destroyed", %{
        char: current_word.char,
        row: current_word.row
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
    is_anonymous = socket.assigns.is_anonymous

    if is_anonymous do
      assign(socket, status: :game_over)
    else
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

      {:ok, _session} = Games.create_words_falling_session(attrs)

      high_score = Games.get_words_falling_high_score(game.id, user.id)
      sessions = Games.list_words_falling_sessions(game.id)

      assign(socket,
        status: :game_over,
        high_score: high_score,
        sessions: sessions
      )
    end
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

  def game_mode_label(mode) do
    case mode do
      0 -> gettext("Word Meaning")
      1 -> gettext("Word Reading")
      _ -> gettext("Unknown")
    end
  end
end
