defmodule Medoru.Games do
  @moduledoc """
  The Games context.

  Handles game creation, management, and gameplay sessions for classrooms.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo

  alias Medoru.Classrooms

  alias Medoru.Games.{
    Game,
    MemoryCardGame,
    MemoryCardGameWord,
    MemoryCardSession,
    KanaFallingGame,
    KanaFallingSession,
    KanjiFallingGame,
    KanjiFallingSession
  }

  # ============================================================================
  # Game Queries
  # ============================================================================

  @doc """
  Returns the list of games for a classroom.

  ## Options

    * `:status` - filter by status (:draft or :published)
    * `:type` - filter by game type ("memory_cards")

  ## Examples

      iex> list_classroom_games(classroom_id)
      [%Game{}, ...]

      iex> list_classroom_games(classroom_id, status: :published)
      [%Game{}, ...]
  """
  def list_classroom_games(classroom_id, opts \\ []) do
    Game
    |> where([g], g.classroom_id == ^classroom_id)
    |> then(fn query ->
      case Keyword.get(opts, :status) do
        nil -> query
        status -> where(query, [g], g.status == ^status)
      end
    end)
    |> then(fn query ->
      case Keyword.get(opts, :type) do
        nil -> query
        type -> where(query, [g], g.type == ^type)
      end
    end)
    |> preload([
      :classroom,
      :memory_card_game,
      :kana_memory_card_game,
      :kana_falling_game,
      :kanji_falling_game
    ])
    |> order_by([g], asc: g.skill_level, desc: g.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns all published games across all classrooms a user has access to.

  Includes classrooms the user owns (as teacher) and classrooms
  they are an approved member of (as student).

  ## Examples

      iex> list_user_games(user_id)
      [%Game{classroom: %Classroom{}}, ...]
  """
  def list_user_games(user_id) do
    # Get classroom IDs the user is a teacher of
    teacher_ids =
      Classrooms.list_teacher_classrooms(user_id)
      |> Enum.map(& &1.id)

    # Get classroom IDs the user is an approved member of
    member_ids =
      Classrooms.list_student_classrooms(user_id)
      |> Enum.map(& &1.id)

    classroom_ids = Enum.uniq(teacher_ids ++ member_ids)

    if classroom_ids == [] do
      []
    else
      Game
      |> where([g], g.classroom_id in ^classroom_ids and g.status == :published)
      |> preload([
        :memory_card_game,
        :kana_memory_card_game,
        :kana_falling_game,
        :kanji_falling_game,
        classroom: [:teacher]
      ])
      |> order_by([g], asc: g.skill_level, desc: g.inserted_at)
      |> Repo.all()
    end
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)
  """
  def get_game!(id) do
    Game
    |> Repo.get!(id)
    |> Repo.preload(
      classroom: [:teacher],
      memory_card_game: [memory_card_game_words: [:word]],
      kana_memory_card_game: [],
      kana_falling_game: [],
      kanji_falling_game: []
    )
  end

  @doc """
  Gets a game with preloaded memory card data for playing.
  """
  def get_game_for_play!(id) do
    Game
    |> Repo.get!(id)
    |> Repo.preload(
      memory_card_game: [memory_card_game_words: [word: [:word_kanjis]]],
      kana_memory_card_game: [],
      kana_falling_game: [],
      kanji_falling_game: []
    )
  end

  # ============================================================================
  # Memory Card Game Creation & Updates
  # ============================================================================

  @doc """
  Creates a memory card game with associated words.

  ## Parameters

    * `classroom_id` - the classroom ID
    * `teacher_id` - the teacher's user ID (for authorization)
    * `attrs` - map with game attributes including nested memory_card_game attrs
    * `word_ids_with_points` - list of `{word_id, points}` tuples

  ## Examples

      iex> create_memory_card_game(classroom_id, teacher_id, %{name: "...", ...}, [{word_id, 1}, ...])
      {:ok, %Game{}}
  """
  def create_memory_card_game(classroom_id, teacher_id, attrs, word_ids_with_points) do
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      Repo.transaction(fn ->
        # Create base game
        game_attrs = %{
          name: attrs["name"] || attrs[:name],
          type: "memory_cards",
          status: :draft,
          max_players: attrs["max_players"] || attrs[:max_players] || 1,
          skill_level: attrs["skill_level"] || attrs[:skill_level] || 1,
          classroom_id: classroom_id
        }

        game =
          %Game{}
          |> Game.changeset(game_attrs)
          |> Repo.insert!()

        # Create memory card game config
        mcg_attrs = %{
          game_id: game.id,
          board_size:
            get_in(attrs, ["memory_card_game", "board_size"]) ||
              get_in(attrs, [:memory_card_game, :board_size]),
          max_attempts:
            get_in(attrs, ["memory_card_game", "max_attempts"]) ||
              get_in(attrs, [:memory_card_game, :max_attempts]),
          meaning_required_for_collection:
            get_bool(attrs, ["memory_card_game", "meaning_required_for_collection"]),
          pronunciation_required_for_collection:
            get_bool(attrs, ["memory_card_game", "pronunciation_required_for_collection"]),
          meaning_or_pronunciation_required_for_collection:
            get_bool(attrs, [
              "memory_card_game",
              "meaning_or_pronunciation_required_for_collection"
            ])
        }

        mcg =
          %MemoryCardGame{}
          |> MemoryCardGame.changeset(mcg_attrs)
          |> Repo.insert!()

        # Create word associations
        create_memory_card_game_words(mcg.id, word_ids_with_points)

        # Return preloaded game
        get_game!(game.id)
      end)
    end
  end

  @doc """
  Updates a memory card game and its word associations.
  """
  def update_memory_card_game(%Game{} = game, teacher_id, attrs, word_ids_with_points) do
    if game.classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      Repo.transaction(fn ->
        # Update base game
        game_attrs = %{
          name: attrs["name"] || attrs[:name],
          max_players: attrs["max_players"] || attrs[:max_players] || game.max_players,
          skill_level: attrs["skill_level"] || attrs[:skill_level] || game.skill_level
        }

        game =
          game
          |> Game.changeset(game_attrs)
          |> Repo.update!()

        # Update memory card game config
        mcg = Repo.get_by!(MemoryCardGame, game_id: game.id)

        mcg_attrs = %{
          board_size:
            get_in(attrs, ["memory_card_game", "board_size"]) ||
              get_in(attrs, [:memory_card_game, :board_size]) || mcg.board_size,
          max_attempts:
            get_in(attrs, ["memory_card_game", "max_attempts"]) ||
              get_in(attrs, [:memory_card_game, :max_attempts]) || mcg.max_attempts,
          meaning_required_for_collection:
            get_bool(
              attrs,
              ["memory_card_game", "meaning_required_for_collection"],
              mcg.meaning_required_for_collection
            ),
          pronunciation_required_for_collection:
            get_bool(
              attrs,
              ["memory_card_game", "pronunciation_required_for_collection"],
              mcg.pronunciation_required_for_collection
            ),
          meaning_or_pronunciation_required_for_collection:
            get_bool(
              attrs,
              ["memory_card_game", "meaning_or_pronunciation_required_for_collection"],
              mcg.meaning_or_pronunciation_required_for_collection
            )
        }

        mcg
        |> MemoryCardGame.changeset(mcg_attrs)
        |> Repo.update!()

        # Replace word associations
        Repo.delete_all(from w in MemoryCardGameWord, where: w.memory_card_game_id == ^mcg.id)
        create_memory_card_game_words(mcg.id, word_ids_with_points)

        get_game!(game.id)
      end)
    end
  end

  defp create_memory_card_game_words(mcg_id, word_ids_with_points) do
    word_ids_with_points
    |> Enum.with_index()
    |> Enum.each(fn {{word_id, points}, index} ->
      %MemoryCardGameWord{}
      |> MemoryCardGameWord.changeset(%{
        memory_card_game_id: mcg_id,
        word_id: word_id,
        points: points,
        position: index
      })
      |> Repo.insert!()
    end)
  end

  # ============================================================================
  # Kana Memory Card Game Creation & Updates
  # ============================================================================

  alias Medoru.Games.KanaMemoryCardGame

  @doc """
  Creates a kana memory card game with selected kana characters.

  ## Parameters

    * `classroom_id` - the classroom ID
    * `teacher_id` - the teacher's user ID (for authorization)
    * `attrs` - map with game attributes
    * `selected_kana` - list of kana character strings

  ## Examples

      iex> create_kana_memory_card_game(classroom_id, teacher_id, %{name: "...", ...}, ["あ", "い", ...])
      {:ok, %Game{}}
  """
  def create_kana_memory_card_game(classroom_id, teacher_id, attrs, selected_kana) do
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      board_size =
        get_in(attrs, ["memory_card_game", "board_size"]) ||
          get_in(attrs, [:memory_card_game, :board_size])

      kana_needed = KanaMemoryCardGame.kana_needed(board_size)

      if length(selected_kana) < kana_needed do
        {:error,
         %{selected_kana: ["at least #{kana_needed} kana required for #{board_size} board"]}}
      else
        Repo.transaction(fn ->
          game_attrs = %{
            name: attrs["name"] || attrs[:name],
            type: "kana_memory_cards",
            status: :draft,
            max_players: attrs["max_players"] || attrs[:max_players] || 1,
            skill_level: attrs["skill_level"] || attrs[:skill_level] || 1,
            classroom_id: classroom_id
          }

          game =
            %Game{}
            |> Game.changeset(game_attrs)
            |> Repo.insert!()

          kana_for_game = Enum.take_random(selected_kana, kana_needed)

          mcg_attrs = %{
            game_id: game.id,
            board_size: board_size,
            max_attempts:
              get_in(attrs, ["memory_card_game", "max_attempts"]) ||
                get_in(attrs, [:memory_card_game, :max_attempts]),
            require_reading: get_bool(attrs, ["memory_card_game", "require_reading"]),
            selected_kana: kana_for_game
          }

          %KanaMemoryCardGame{}
          |> KanaMemoryCardGame.changeset(mcg_attrs)
          |> Repo.insert!()

          get_game!(game.id)
        end)
      end
    end
  end

  @doc """
  Updates a kana memory card game and its selected kana.
  """
  def update_kana_memory_card_game(%Game{} = game, teacher_id, attrs, selected_kana) do
    if game.classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      board_size =
        get_in(attrs, ["memory_card_game", "board_size"]) ||
          get_in(attrs, [:memory_card_game, :board_size]) ||
          game.kana_memory_card_game.board_size

      kana_needed = KanaMemoryCardGame.kana_needed(board_size)

      if length(selected_kana) < kana_needed do
        {:error,
         %{selected_kana: ["at least #{kana_needed} kana required for #{board_size} board"]}}
      else
        Repo.transaction(fn ->
          game_attrs = %{
            name: attrs["name"] || attrs[:name] || game.name,
            max_players: attrs["max_players"] || attrs[:max_players] || game.max_players,
            skill_level: attrs["skill_level"] || attrs[:skill_level] || game.skill_level
          }

          game =
            game
            |> Game.changeset(game_attrs)
            |> Repo.update!()

          kmcg = Repo.get_by!(KanaMemoryCardGame, game_id: game.id)

          kana_for_game = Enum.take_random(selected_kana, kana_needed)

          kmcg_attrs = %{
            board_size: board_size,
            max_attempts:
              get_in(attrs, ["memory_card_game", "max_attempts"]) ||
                get_in(attrs, [:memory_card_game, :max_attempts]) || kmcg.max_attempts,
            require_reading:
              get_bool(
                attrs,
                ["memory_card_game", "require_reading"],
                kmcg.require_reading
              ),
            selected_kana: kana_for_game
          }

          kmcg
          |> KanaMemoryCardGame.changeset(kmcg_attrs)
          |> Repo.update!()

          get_game!(game.id)
        end)
      end
    end
  end

  defp get_bool(attrs, keys, default \\ false) do
    value = get_in(attrs, keys)

    case value do
      nil -> default
      "true" -> true
      "false" -> false
      true -> true
      false -> false
      _ -> default
    end
  end

  @doc """
  Publishes a game so students can see it.
  """
  def publish_game(game_id, teacher_id) do
    game = get_game!(game_id)
    classroom = Classrooms.get_classroom!(game.classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      game
      |> Game.publish_changeset()
      |> Repo.update()
    end
  end

  @doc """
  Unpublishes a game.
  """
  def unpublish_game(game_id, teacher_id) do
    game = get_game!(game_id)
    classroom = Classrooms.get_classroom!(game.classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      game
      |> Game.unpublish_changeset()
      |> Repo.update()
    end
  end

  @doc """
  Deletes a game and all associated data.
  """
  def delete_game(game_id, teacher_id) do
    game = get_game!(game_id)
    classroom = Classrooms.get_classroom!(game.classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      Repo.delete(game)
    end
  end

  # ============================================================================
  # Session Management
  # ============================================================================

  @doc """
  Gets or creates a memory card session for a user.

  If an in-progress session exists, returns it.
  Otherwise, creates a new session with shuffled cards.
  """
  def get_or_create_session(game_id, user_id) do
    case get_user_session(game_id, user_id) do
      %MemoryCardSession{status: :in_progress} = session ->
        {:ok, session}

      %MemoryCardSession{status: :completed} = _session ->
        # Remove old session points and delete it before starting fresh
        reset_session(game_id, user_id)
        create_typed_session(game_id, user_id)

      _ ->
        create_typed_session(game_id, user_id)
    end
  end

  defp create_typed_session(game_id, user_id) do
    game = get_game_for_play!(game_id)

    case game.type do
      "kana_memory_cards" -> create_kana_session(game_id, user_id)
      _ -> create_session(game_id, user_id)
    end
  end

  @doc """
  Gets the most recent session for a user and game.
  """
  def get_user_session(game_id, user_id) do
    game = Repo.get!(Game, game_id)

    case game.type do
      "kana_falling" ->
        KanaFallingSession
        |> where([s], s.game_id == ^game_id and s.user_id == ^user_id)
        |> order_by([s], desc: s.inserted_at)
        |> limit(1)
        |> Repo.one()

      "kanji_falling" ->
        KanjiFallingSession
        |> where([s], s.game_id == ^game_id and s.user_id == ^user_id)
        |> order_by([s], desc: s.inserted_at)
        |> limit(1)
        |> Repo.one()

      _ ->
        MemoryCardSession
        |> where([s], s.game_id == ^game_id and s.user_id == ^user_id)
        |> order_by([s], desc: s.inserted_at)
        |> limit(1)
        |> Repo.one()
    end
  end

  @doc """
  Creates a new memory card session with shuffled cards.
  """
  def create_session(game_id, user_id) do
    game = get_game_for_play!(game_id)
    mcg = game.memory_card_game

    word_ids =
      mcg.memory_card_game_words
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.word_id)

    card_positions = shuffle_cards(word_ids)

    attrs = %{
      game_id: game_id,
      user_id: user_id,
      status: :in_progress,
      score: 0,
      attempts_used: 0,
      max_attempts: mcg.max_attempts,
      cards_state: %{
        "card_positions" => card_positions,
        "collected_indices" => [],
        "flipped_indices" => []
      },
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %MemoryCardSession{}
    |> MemoryCardSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a new kana memory card session with shuffled kana cards.
  """
  def create_kana_session(game_id, user_id) do
    game = get_game_for_play!(game_id)
    kmcg = game.kana_memory_card_game

    kana_list = kmcg.selected_kana
    card_positions = shuffle_kana(kana_list)

    attrs = %{
      game_id: game_id,
      user_id: user_id,
      status: :in_progress,
      score: 0,
      attempts_used: 0,
      max_attempts: kmcg.max_attempts,
      cards_state: %{
        "card_positions" => card_positions,
        "collected_indices" => [],
        "flipped_indices" => []
      },
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %MemoryCardSession{}
    |> MemoryCardSession.changeset(attrs)
    |> Repo.insert()
  end

  defp shuffle_kana(kana_list) do
    kana_list
    |> Enum.flat_map(&[&1, &1])
    |> Enum.shuffle()
  end

  defp shuffle_cards(word_ids) do
    word_ids
    |> Enum.flat_map(&[&1, &1])
    |> Enum.shuffle()
    |> Enum.map(&encode_word_id/1)
  end

  defp encode_word_id(word_id) do
    case Ecto.UUID.dump(word_id) do
      {:ok, _binary} -> word_id
      :error -> to_string(word_id)
    end
  end

  @doc """
  Flips a card at the given position.

  Returns:
    * `{:ok, session, :flipped}` - card was flipped, waiting for second card
    * `{:ok, session, :no_match}` - two cards flipped but don't match
    * `{:ok, session, :collected, points}` - two matching cards collected directly
    * `{:needs_input, session, word_id}` - two matching cards but need pronunciation/meaning
    * `{:error, :game_over}` - no attempts remaining
    * `{:error, :invalid_position}` - position already collected or flipped
  """
  def flip_card(session_id, position) when is_integer(position) do
    session = Repo.get!(MemoryCardSession, session_id)

    if session.status != :in_progress do
      {:error, :game_over}
    else
      cards_state = session.cards_state
      card_positions = cards_state["card_positions"] || []
      collected = cards_state["collected_indices"] || []
      flipped = cards_state["flipped_indices"] || []

      cond do
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
            update_session_cards_state(session, %{
              "card_positions" => card_positions,
              "collected_indices" => collected,
              "flipped_indices" => new_flipped
            })
          end
      end
    end
  end

  defp handle_two_flipped(session, [pos1, pos2], card_positions, collected) do
    word1 = Enum.at(card_positions, pos1)
    word2 = Enum.at(card_positions, pos2)

    game = get_game_for_play!(session.game_id)
    mcg = game.memory_card_game

    if word1 == word2 do
      # Match found - check collection condition
      collection_type = MemoryCardGame.collection_type(mcg)

      if collection_type == :direct do
        # Direct collection
        points = get_word_points(mcg, word1)
        new_score = session.score + points
        new_collected = collected ++ [pos1, pos2]

        new_state = %{
          "card_positions" => card_positions,
          "collected_indices" => new_collected,
          "flipped_indices" => []
        }

        session
        |> update_session_with_score(new_state, new_score)
        |> case do
          {:ok, updated} -> {:ok, updated, :collected, points}
          error -> error
        end
      else
        # Need input - keep flipped but signal UI
        new_state = %{
          "card_positions" => card_positions,
          "collected_indices" => collected,
          "flipped_indices" => [pos1, pos2]
        }

        {:ok, updated} = update_session_cards_state(session, new_state)
        {:needs_input, updated, word1}
      end
    else
      # No match - consume attempt, keep cards flipped for reveal
      new_attempts = session.attempts_used + 1

      new_state = %{
        "card_positions" => card_positions,
        "collected_indices" => collected,
        "flipped_indices" => [pos1, pos2]
      }

      if new_attempts >= session.max_attempts do
        # Game over but keep cards flipped for reveal
        complete_session_with_state(session, new_state, new_attempts)
        |> case do
          {:ok, completed} -> {:ok, completed, :no_match}
          error -> error
        end
      else
        session
        |> MemoryCardSession.changeset(%{
          attempts_used: new_attempts,
          cards_state: new_state
        })
        |> Repo.update()
        |> case do
          {:ok, updated} -> {:ok, updated, :no_match}
          error -> error
        end
      end
    end
  end

  @doc """
  Closes any flipped cards that didn't match (after reveal delay).

  Returns:
    * `{:ok, session}` - cards closed
    * `{:error, reason}` - update failed
  """
  def close_flipped_cards(session_id) do
    session = Repo.get!(MemoryCardSession, session_id)
    cards_state = session.cards_state || %{}

    new_state = Map.put(cards_state, "flipped_indices", [])

    session
    |> MemoryCardSession.changeset(%{cards_state: new_state})
    |> Repo.update()
  end

  @doc """
  Cancels an input attempt after a matched pair was found.

  Consumes one attempt and closes the flipped cards, just like a wrong answer.

  Returns:
    * `{:ok, session, :cancelled}` - attempt consumed, cards closed
    * `{:ok, session, :game_over}` - no attempts remaining after cancel
    * `{:error, :game_over}` - session already completed
    * `{:error, :no_flipped_cards}` - fewer than 2 cards flipped
  """
  def cancel_input_attempt(session_id) do
    session = Repo.get!(MemoryCardSession, session_id)

    if session.status != :in_progress do
      {:error, :game_over}
    else
      cards_state = session.cards_state || %{}
      flipped = cards_state["flipped_indices"] || []

      if length(flipped) < 2 do
        {:error, :no_flipped_cards}
      else
        new_attempts = session.attempts_used + 1
        new_state = Map.put(cards_state, "flipped_indices", [])

        if new_attempts >= session.max_attempts do
          complete_session_with_state(session, new_state, new_attempts)
          |> case do
            {:ok, completed} -> {:ok, completed, :game_over}
            error -> error
          end
        else
          session
          |> MemoryCardSession.changeset(%{
            attempts_used: new_attempts,
            cards_state: new_state
          })
          |> Repo.update()
          |> case do
            {:ok, updated} -> {:ok, updated, :cancelled}
            error -> error
          end
        end
      end
    end
  end

  @doc """
  Submits a collection answer for pronunciation/meaning conditions.

  Returns:
    * `{:ok, session, :collected, points}` - answer correct, cards collected
    * `{:ok, session, :wrong_answer}` - answer wrong, attempt consumed
    * `{:error, :game_over}` - no attempts remaining after wrong answer
  """
  def submit_collection_answer(session_id, answer, locale \\ "en") do
    session = Repo.get!(MemoryCardSession, session_id)
    game = get_game_for_play!(session.game_id)
    mcg = game.memory_card_game

    cards_state = session.cards_state
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []
    flipped = cards_state["flipped_indices"] || []

    if length(flipped) != 2 do
      {:error, :no_flipped_cards}
    else
      [pos1, pos2] = flipped
      word_id = Enum.at(card_positions, pos1)
      word = Enum.find(mcg.memory_card_game_words, &(&1.word_id == word_id))

      collection_type = MemoryCardGame.collection_type(mcg)
      correct = validate_answer(word, answer, collection_type, locale)

      if correct do
        points = get_word_points(mcg, word_id)
        new_score = session.score + points
        new_collected = collected ++ [pos1, pos2]

        new_state = %{
          "card_positions" => card_positions,
          "collected_indices" => new_collected,
          "flipped_indices" => []
        }

        session
        |> update_session_with_score(new_state, new_score)
        |> case do
          {:ok, updated} -> {:ok, updated, :collected, points}
          error -> error
        end
      else
        new_attempts = session.attempts_used + 1

        new_state = %{
          "card_positions" => card_positions,
          "collected_indices" => collected,
          "flipped_indices" => []
        }

        if new_attempts >= session.max_attempts do
          complete_session_with_state(session, new_state, new_attempts)
          |> case do
            {:ok, completed} -> {:ok, completed, :wrong_answer}
            error -> error
          end
        else
          session
          |> MemoryCardSession.changeset(%{
            attempts_used: new_attempts,
            cards_state: new_state
          })
          |> Repo.update()
          |> case do
            {:ok, updated} -> {:ok, updated, :wrong_answer}
            error -> error
          end
        end
      end
    end
  end

  # ============================================================================
  # Kana Memory Card Gameplay
  # ============================================================================

  alias Medoru.Content.Kana

  @doc """
  Flips a kana card at the given position.

  Same return types as flip_card/2 but works with kana characters.
  """
  def flip_kana_card(session_id, position) when is_integer(position) do
    session = Repo.get!(MemoryCardSession, session_id)

    if session.status != :in_progress do
      {:error, :game_over}
    else
      cards_state = session.cards_state
      card_positions = cards_state["card_positions"] || []
      collected = cards_state["collected_indices"] || []
      flipped = cards_state["flipped_indices"] || []

      cond do
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
            handle_two_flipped_kana(session, new_flipped, card_positions, collected)
          else
            update_session_cards_state(session, %{
              "card_positions" => card_positions,
              "collected_indices" => collected,
              "flipped_indices" => new_flipped
            })
          end
      end
    end
  end

  defp handle_two_flipped_kana(session, [pos1, pos2], card_positions, collected) do
    kana1 = Enum.at(card_positions, pos1)
    kana2 = Enum.at(card_positions, pos2)

    game = get_game_for_play!(session.game_id)
    kmcg = game.kana_memory_card_game

    if kana1 == kana2 do
      if not kmcg.require_reading do
        # Direct collection
        new_score = session.score + 1
        new_collected = collected ++ [pos1, pos2]

        new_state = %{
          "card_positions" => card_positions,
          "collected_indices" => new_collected,
          "flipped_indices" => []
        }

        session
        |> update_session_with_score(new_state, new_score)
        |> case do
          {:ok, updated} -> {:ok, updated, :collected, 1}
          error -> error
        end
      else
        # Need input - keep flipped but signal UI
        new_state = %{
          "card_positions" => card_positions,
          "collected_indices" => collected,
          "flipped_indices" => [pos1, pos2]
        }

        {:ok, updated} = update_session_cards_state(session, new_state)
        {:needs_input, updated, kana1}
      end
    else
      # No match - consume attempt, keep cards flipped for reveal
      new_attempts = session.attempts_used + 1

      new_state = %{
        "card_positions" => card_positions,
        "collected_indices" => collected,
        "flipped_indices" => [pos1, pos2]
      }

      if new_attempts >= session.max_attempts do
        complete_session_with_state(session, new_state, new_attempts)
        |> case do
          {:ok, completed} -> {:ok, completed, :no_match}
          error -> error
        end
      else
        session
        |> MemoryCardSession.changeset(%{
          attempts_used: new_attempts,
          cards_state: new_state
        })
        |> Repo.update()
        |> case do
          {:ok, updated} -> {:ok, updated, :no_match}
          error -> error
        end
      end
    end
  end

  @doc """
  Submits a kana reading answer for collection.

  Returns:
    * `{:ok, session, :collected, points}` - answer correct, cards collected
    * `{:ok, session, :wrong_answer}` - answer wrong, attempt consumed
    * `{:error, :game_over}` - no attempts remaining after wrong answer
  """
  def submit_kana_answer(session_id, answer) do
    session = Repo.get!(MemoryCardSession, session_id)

    cards_state = session.cards_state
    card_positions = cards_state["card_positions"] || []
    collected = cards_state["collected_indices"] || []
    flipped = cards_state["flipped_indices"] || []

    if length(flipped) != 2 do
      {:error, :no_flipped_cards}
    else
      [pos1, pos2] = flipped
      kana_char = Enum.at(card_positions, pos1)
      answer_reading = String.trim(answer["reading"] || "")

      correct = validate_kana_answer(kana_char, answer_reading)

      if correct do
        new_score = session.score + 1
        new_collected = collected ++ [pos1, pos2]

        new_state = %{
          "card_positions" => card_positions,
          "collected_indices" => new_collected,
          "flipped_indices" => []
        }

        session
        |> update_session_with_score(new_state, new_score)
        |> case do
          {:ok, updated} -> {:ok, updated, :collected, 1}
          error -> error
        end
      else
        new_attempts = session.attempts_used + 1

        new_state = %{
          "card_positions" => card_positions,
          "collected_indices" => collected,
          "flipped_indices" => []
        }

        if new_attempts >= session.max_attempts do
          complete_session_with_state(session, new_state, new_attempts)
          |> case do
            {:ok, completed} -> {:ok, completed, :wrong_answer}
            error -> error
          end
        else
          session
          |> MemoryCardSession.changeset(%{
            attempts_used: new_attempts,
            cards_state: new_state
          })
          |> Repo.update()
          |> case do
            {:ok, updated} -> {:ok, updated, :wrong_answer}
            error -> error
          end
        end
      end
    end
  end

  defp validate_kana_answer(kana_char, answer_reading) do
    answer_reading != "" and
      case Kana.get_by_character(kana_char) do
        nil ->
          false

        kana ->
          String.downcase(answer_reading) ==
            String.downcase(List.first(kana.readings, %{romaji: ""}).romaji)
      end
  end

  defp validate_answer(word, answer, collection_type, locale) do
    answer_meaning = String.trim(answer["meaning"] || "")
    answer_pronunciation = String.trim(answer["pronunciation"] || "")

    word_meaning_default = String.trim(word.word.meaning || "")

    word_meaning_localized =
      String.trim(Medoru.Content.get_localized_meaning(word.word, locale) || "")

    word_reading = String.trim(word.word.reading || "")

    meaning_correct =
      answer_meaning != "" and
        (String.downcase(answer_meaning) == String.downcase(word_meaning_default) or
           String.downcase(answer_meaning) == String.downcase(word_meaning_localized))

    pronunciation_correct =
      answer_pronunciation != "" and
        String.downcase(answer_pronunciation) == String.downcase(word_reading)

    case collection_type do
      :meaning -> meaning_correct
      :pronunciation -> pronunciation_correct
      :meaning_or_pronunciation -> meaning_correct or pronunciation_correct
      :meaning_and_pronunciation -> meaning_correct and pronunciation_correct
      _ -> true
    end
  end

  defp get_word_points(mcg, word_id) do
    word_id_str = encode_word_id(word_id)

    Enum.find_value(mcg.memory_card_game_words, 1, fn mgw ->
      if encode_word_id(mgw.word_id) == word_id_str do
        mgw.points
      end
    end)
  end

  defp update_session_cards_state(session, cards_state) do
    session
    |> MemoryCardSession.changeset(%{cards_state: cards_state})
    |> Repo.update()
  end

  defp update_session_with_score(session, cards_state, score) do
    all_collected? =
      length(cards_state["collected_indices"] || []) ==
        length(cards_state["card_positions"] || [])

    if all_collected? do
      complete_session_with_state(session, cards_state, session.attempts_used, score)
    else
      session
      |> MemoryCardSession.changeset(%{
        score: score,
        cards_state: cards_state
      })
      |> Repo.update()
    end
  end

  defp complete_session_with_state(session, cards_state, attempts_used, score \\ nil) do
    score = score || session.score

    attrs = %{
      score: score,
      attempts_used: attempts_used,
      cards_state: cards_state,
      status: :completed,
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    result =
      session
      |> MemoryCardSession.complete_changeset(attrs)
      |> Repo.update()

    with {:ok, completed_session} <- result do
      # Add points to classroom membership
      game = Repo.get!(Game, session.game_id)
      Classrooms.add_points_to_member(game.classroom_id, session.user_id, score)

      {:ok, completed_session}
    end
  end

  @doc """
  Completes a session manually (e.g., when all cards collected).
  """
  def complete_session(session_id) do
    session = Repo.get!(MemoryCardSession, session_id)

    if session.status == :completed do
      {:ok, session}
    else
      complete_session_with_state(session, session.cards_state, session.attempts_used)
    end
  end

  @doc """
  Resets a user's session for a game.

  If the session was completed, removes points from classroom membership first.
  Then deletes the session so the user can start fresh.
  """
  def reset_session(game_id, user_id) do
    session = get_user_session(game_id, user_id)

    if session do
      if session.status == :completed and session.score > 0 do
        game = Repo.get!(Game, game_id)
        Classrooms.remove_member_points(game.classroom_id, user_id, session.score)
      end

      Repo.delete(session)
    else
      {:ok, nil}
    end
  end

  # ============================================================================
  # Kana Falling Games
  # ============================================================================

  @doc """
  Creates a kana falling game with kana selection.
  """
  def create_kana_falling_game(classroom_id, teacher_id, attrs, selected_kana) do
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      Repo.transaction(fn ->
        game_attrs = %{
          name: attrs["name"] || attrs[:name],
          type: "kana_falling",
          status: :draft,
          max_players: 1,
          skill_level: attrs["skill_level"] || attrs[:skill_level] || 1,
          classroom_id: classroom_id
        }

        game =
          %Game{}
          |> Game.changeset(game_attrs)
          |> Repo.insert!()

        kfg_attrs = %{
          game_id: game.id,
          initial_speed:
            parse_int(
              get_in(attrs, ["kana_falling_game", "initial_speed"]) ||
                get_in(attrs, [:kana_falling_game, :initial_speed]),
              1
            ),
          speed_increase_threshold:
            parse_int(
              get_in(attrs, ["kana_falling_game", "speed_increase_threshold"]) ||
                get_in(attrs, [:kana_falling_game, :speed_increase_threshold]),
              50
            ),
          lives:
            parse_int(
              get_in(attrs, ["kana_falling_game", "lives"]) ||
                get_in(attrs, [:kana_falling_game, :lives]),
              3
            ),
          extra_life_threshold:
            parse_int(
              get_in(attrs, ["kana_falling_game", "extra_life_threshold"]) ||
                get_in(attrs, [:kana_falling_game, :extra_life_threshold]),
              100
            ),
          points_per_kana:
            parse_int(
              get_in(attrs, ["kana_falling_game", "points_per_kana"]) ||
                get_in(attrs, [:kana_falling_game, :points_per_kana]),
              1
            ),
          selected_kana: selected_kana,
          background_image:
            get_in(attrs, ["kana_falling_game", "background_image"]) ||
              get_in(attrs, [:kana_falling_game, :background_image]),
          color_coded_rows:
            get_in(attrs, ["kana_falling_game", "color_coded_rows"]) ||
              get_in(attrs, [:kana_falling_game, :color_coded_rows]) || false
        }

        %KanaFallingGame{}
        |> KanaFallingGame.changeset(kfg_attrs)
        |> Repo.insert!()

        get_game!(game.id)
      end)
    end
  end

  @doc """
  Updates a kana falling game and its kana selection.
  """
  def update_kana_falling_game(%Game{} = game, teacher_id, attrs, selected_kana) do
    if game.classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      Repo.transaction(fn ->
        game_attrs = %{
          name: attrs["name"] || attrs[:name] || game.name,
          max_players: 1,
          skill_level: attrs["skill_level"] || attrs[:skill_level] || game.skill_level
        }

        game =
          game
          |> Game.changeset(game_attrs)
          |> Repo.update!()

        kfg = Repo.get_by!(KanaFallingGame, game_id: game.id)

        kfg_attrs = %{
          initial_speed:
            parse_int(
              get_in(attrs, ["kana_falling_game", "initial_speed"]) ||
                get_in(attrs, [:kana_falling_game, :initial_speed]),
              kfg.initial_speed
            ),
          speed_increase_threshold:
            parse_int(
              get_in(attrs, ["kana_falling_game", "speed_increase_threshold"]) ||
                get_in(attrs, [:kana_falling_game, :speed_increase_threshold]),
              kfg.speed_increase_threshold
            ),
          lives:
            parse_int(
              get_in(attrs, ["kana_falling_game", "lives"]) ||
                get_in(attrs, [:kana_falling_game, :lives]),
              kfg.lives
            ),
          extra_life_threshold:
            parse_int(
              get_in(attrs, ["kana_falling_game", "extra_life_threshold"]) ||
                get_in(attrs, [:kana_falling_game, :extra_life_threshold]),
              kfg.extra_life_threshold
            ),
          points_per_kana:
            parse_int(
              get_in(attrs, ["kana_falling_game", "points_per_kana"]) ||
                get_in(attrs, [:kana_falling_game, :points_per_kana]),
              kfg.points_per_kana
            ),
          selected_kana: selected_kana,
          background_image:
            get_in(attrs, ["kana_falling_game", "background_image"]) ||
              get_in(attrs, [:kana_falling_game, :background_image]) || kfg.background_image,
          color_coded_rows:
            get_in(attrs, ["kana_falling_game", "color_coded_rows"]) ||
              get_in(attrs, [:kana_falling_game, :color_coded_rows]) || kfg.color_coded_rows
        }

        kfg
        |> KanaFallingGame.changeset(kfg_attrs)
        |> Repo.update!()

        get_game!(game.id)
      end)
    end
  end

  @doc """
  Creates a completed kana falling session after game over.
  """
  def create_kana_falling_session(attrs) do
    %KanaFallingSession{}
    |> KanaFallingSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists kana falling sessions for rankings (best score per user).
  """
  def list_kana_falling_sessions(game_id) do
    best_session_ids =
      KanaFallingSession
      |> where([s], s.game_id == ^game_id)
      |> distinct([s], asc: s.user_id)
      |> order_by([s], asc: s.user_id, desc: s.score, asc: s.completed_at)
      |> select([s], s.id)

    KanaFallingSession
    |> where([s], s.id in subquery(best_session_ids))
    |> order_by([s], desc: s.score, asc: s.completed_at)
    |> preload(user: [:profile])
    |> Repo.all()
  end

  @doc """
  Gets the user's high score for a kana falling game.
  """
  def get_kana_falling_high_score(game_id, user_id) do
    KanaFallingSession
    |> where([s], s.game_id == ^game_id and s.user_id == ^user_id)
    |> select([s], max(s.score))
    |> Repo.one() || 0
  end

  # ============================================================================
  # Kanji Falling Games
  # ============================================================================

  @kanji_colors [
    "#1a1a1a",
    "#2d1b1b",
    "#1b2d1b",
    "#1b1b2d",
    "#2d2d1b",
    "#1b2d2d",
    "#2d1b2d",
    "#3d1a1a",
    "#1a3d1a",
    "#1a1a3d",
    "#3d3d1a",
    "#1a3d3d",
    "#3d1a3d",
    "#2a1a0a",
    "#0a1a2a",
    "#1a0a2a",
    "#2a2a0a",
    "#0a2a2a",
    "#2a0a1a",
    "#1a2a0a",
    "#0a1a1a",
    "#1a0a0a",
    "#0a0a1a",
    "#1a1a0a",
    "#0a1a0a",
    "#1a0a1a",
    "#2a1a1a",
    "#1a2a1a",
    "#1a1a2a",
    "#2a2a1a",
    "#1a2a2a",
    "#2a1a2a",
    "#3a1a1a",
    "#1a3a1a",
    "#1a1a3a",
    "#3a3a1a",
    "#1a3a3a",
    "#3a1a3a",
    "#2a0a0a",
    "#0a2a0a",
    "#0a0a2a",
    "#2a2a0a",
    "#0a2a2a",
    "#2a0a2a",
    "#1a1a1a",
    "#0a0a0a",
    "#2a2a2a",
    "#1a2a0a",
    "#0a1a2a",
    "#2a0a1a",
    "#1a0a2a",
    "#0a2a1a",
    "#2a1a0a",
    "#1a0a1a",
    "#0a1a0a",
    "#1a1a0a",
    "#0a0a1a",
    "#1a0a0a",
    "#0a1a1a",
    "#2a1a2a",
    "#1a2a1a",
    "#2a2a1a",
    "#1a1a2a"
  ]

  @doc """
  Creates a kanji falling game with kanji selection.
  """
  def create_kanji_falling_game(classroom_id, teacher_id, attrs, selected_kanji) do
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      selected_kanji = Enum.uniq(selected_kanji)

      Repo.transaction(fn ->
        game_attrs = %{
          name: attrs["name"] || attrs[:name],
          type: "kanji_falling",
          status: :draft,
          max_players: 1,
          skill_level: attrs["skill_level"] || attrs[:skill_level] || 1,
          classroom_id: classroom_id
        }

        game =
          %Game{}
          |> Game.changeset(game_attrs)
          |> Repo.insert!()

        kfg_attrs = %{
          game_id: game.id,
          initial_speed:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "initial_speed"]) ||
                get_in(attrs, [:kanji_falling_game, :initial_speed]),
              1
            ),
          speed_increase_threshold:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "speed_increase_threshold"]) ||
                get_in(attrs, [:kanji_falling_game, :speed_increase_threshold]),
              50
            ),
          lives:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "lives"]) ||
                get_in(attrs, [:kanji_falling_game, :lives]),
              3
            ),
          extra_life_threshold:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "extra_life_threshold"]) ||
                get_in(attrs, [:kanji_falling_game, :extra_life_threshold]),
              100
            ),
          points_per_kanji:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "points_per_kanji"]) ||
                get_in(attrs, [:kanji_falling_game, :points_per_kanji]),
              1
            ),
          selected_kanji: selected_kanji,
          reading_type:
            get_in(attrs, ["kanji_falling_game", "reading_type"]) ||
              get_in(attrs, [:kanji_falling_game, :reading_type]) || "any",
          keyboard_type:
            get_in(attrs, ["kanji_falling_game", "keyboard_type"]) ||
              get_in(attrs, [:kanji_falling_game, :keyboard_type]) || "hiragana",
          kanji_colors: assign_kanji_colors(selected_kanji),
          background_image:
            get_in(attrs, ["kanji_falling_game", "background_image"]) ||
              get_in(attrs, [:kanji_falling_game, :background_image])
        }

        case %KanjiFallingGame{}
             |> KanjiFallingGame.changeset(kfg_attrs)
             |> Repo.insert() do
          {:ok, _} -> get_game!(game.id)
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end
  end

  @doc """
  Updates a kanji falling game and its kanji selection.
  """
  def update_kanji_falling_game(%Game{} = game, teacher_id, attrs, selected_kanji) do
    if game.classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      selected_kanji = Enum.uniq(selected_kanji)

      Repo.transaction(fn ->
        game_attrs = %{
          name: attrs["name"] || attrs[:name] || game.name,
          max_players: 1,
          skill_level: attrs["skill_level"] || attrs[:skill_level] || game.skill_level
        }

        game =
          game
          |> Game.changeset(game_attrs)
          |> Repo.update!()

        kfg = Repo.get_by!(KanjiFallingGame, game_id: game.id)

        existing_chars = kfg.selected_kanji || []

        colors =
          if Enum.sort(existing_chars) == Enum.sort(selected_kanji) do
            kfg.kanji_colors || %{}
          else
            assign_kanji_colors(selected_kanji)
          end

        kfg_attrs = %{
          initial_speed:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "initial_speed"]) ||
                get_in(attrs, [:kanji_falling_game, :initial_speed]),
              kfg.initial_speed
            ),
          speed_increase_threshold:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "speed_increase_threshold"]) ||
                get_in(attrs, [:kanji_falling_game, :speed_increase_threshold]),
              kfg.speed_increase_threshold
            ),
          lives:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "lives"]) ||
                get_in(attrs, [:kanji_falling_game, :lives]),
              kfg.lives
            ),
          extra_life_threshold:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "extra_life_threshold"]) ||
                get_in(attrs, [:kanji_falling_game, :extra_life_threshold]),
              kfg.extra_life_threshold
            ),
          points_per_kanji:
            parse_int(
              get_in(attrs, ["kanji_falling_game", "points_per_kanji"]) ||
                get_in(attrs, [:kanji_falling_game, :points_per_kanji]),
              kfg.points_per_kanji
            ),
          selected_kanji: selected_kanji,
          reading_type:
            get_in(attrs, ["kanji_falling_game", "reading_type"]) ||
              get_in(attrs, [:kanji_falling_game, :reading_type]) || kfg.reading_type,
          keyboard_type:
            get_in(attrs, ["kanji_falling_game", "keyboard_type"]) ||
              get_in(attrs, [:kanji_falling_game, :keyboard_type]) || kfg.keyboard_type,
          kanji_colors: colors,
          background_image:
            get_in(attrs, ["kanji_falling_game", "background_image"]) ||
              get_in(attrs, [:kanji_falling_game, :background_image]) || kfg.background_image
        }

        case kfg
             |> KanjiFallingGame.changeset(kfg_attrs)
             |> Repo.update() do
          {:ok, _} -> get_game!(game.id)
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end
  end

  defp assign_kanji_colors(selected_kanji) do
    selected_kanji
    |> Enum.with_index()
    |> Enum.map(fn {char, index} ->
      color = Enum.at(@kanji_colors, rem(index, length(@kanji_colors)))
      {char, color}
    end)
    |> Map.new()
  end

  @doc """
  Creates a completed kanji falling session after game over.
  """
  def create_kanji_falling_session(attrs) do
    %KanjiFallingSession{}
    |> KanjiFallingSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists kanji falling sessions for rankings (best score per user).
  """
  def list_kanji_falling_sessions(game_id) do
    best_session_ids =
      KanjiFallingSession
      |> where([s], s.game_id == ^game_id)
      |> distinct([s], asc: s.user_id)
      |> order_by([s], asc: s.user_id, desc: s.score, asc: s.completed_at)
      |> select([s], s.id)

    KanjiFallingSession
    |> where([s], s.id in subquery(best_session_ids))
    |> order_by([s], desc: s.score, asc: s.completed_at)
    |> preload(user: [:profile])
    |> Repo.all()
  end

  @doc """
  Gets the user's high score for a kanji falling game.
  """
  def get_kanji_falling_high_score(game_id, user_id) do
    KanjiFallingSession
    |> where([s], s.game_id == ^game_id and s.user_id == ^user_id)
    |> select([s], max(s.score))
    |> Repo.one() || 0
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(_, default), do: default

  # ============================================================================
  # Rankings
  # ============================================================================

  @doc """
  Lists all sessions for a game, ordered by score descending.
  Used for rankings display.
  """
  def list_game_sessions(game_id) do
    best_session_ids =
      MemoryCardSession
      |> where([s], s.game_id == ^game_id and s.status == :completed)
      |> distinct([s], asc: s.user_id)
      |> order_by([s], asc: s.user_id, desc: s.score, asc: s.attempts_used, asc: s.completed_at)
      |> select([s], s.id)

    MemoryCardSession
    |> where([s], s.id in subquery(best_session_ids))
    |> order_by([s], desc: s.score, asc: s.attempts_used, asc: s.completed_at)
    |> preload(user: [:profile])
    |> Repo.all()
  end

  @doc """
  Gets the user's completed session for a game, if any.
  """
  def get_user_completed_session(game_id, user_id) do
    MemoryCardSession
    |> where([s], s.game_id == ^game_id and s.user_id == ^user_id)
    |> where([s], s.status == :completed)
    |> order_by([s], desc: s.score)
    |> limit(1)
    |> Repo.one()
  end
end
