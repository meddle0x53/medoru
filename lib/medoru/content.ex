defmodule Medoru.Content do
  @moduledoc """
  The Content context handles kanji, readings, words, and lessons.
  """
  import Ecto.Query, warn: false
  alias Medoru.Repo

  alias Medoru.Content.{
    Kanji,
    KanjiReading,
    Word,
    WordKanji,
    WordRelation,
    WordConjugation,
    Lesson,
    LessonWord,
    KanjiReadingExtractor,
    CustomLesson,
    CustomLessonWord
  }

  alias Medoru.Learning.{UserEnglishProgress, UserProgress, WordSet}

  # Kanji Functions

  @doc """
  Returns the list of all kanji.
  """
  def list_kanji do
    Repo.all(Kanji)
  end

  @doc """
  Returns the list of kanji filtered by JLPT level (1-5).

  ## Examples

      iex> list_kanji_by_level(5)
      [%Kanji{}, ...]

  """
  def list_kanji_by_level(jlpt_level) when jlpt_level in 1..5 do
    Kanji
    |> where(jlpt_level: ^jlpt_level)
    |> order_by([k], asc: k.frequency)
    |> Repo.all()
  end

  @doc """
  Returns the list of kanji filtered by Japanese school grade level (1-6).

  ## Examples

      iex> list_kanji_by_school_level(1)
      [%Kanji{}, ...]

  """
  def list_kanji_by_school_level(level) when level in 1..6 do
    Kanji
    |> where(school_level: ^level)
    |> order_by([k], asc: k.school_level, asc: k.frequency)
    |> Repo.all()
  end

  @doc """
  Returns kanji that contain the given radical.
  """
  def list_kanji_by_radical(radical) when is_binary(radical) do
    Kanji
    |> where([k], ^radical in k.radicals)
    |> order_by([k], asc: k.frequency)
    |> Repo.all()
  end

  @doc """
  Gets a single kanji by ID.

  Raises `Ecto.NoResultsError` if the Kanji does not exist.

  ## Examples

      iex> get_kanji!(123)
      %Kanji{}

      iex> get_kanji!(456)
      ** (Ecto.NoResultsError)

  """
  def get_kanji!(id), do: Repo.get!(Kanji, id)

  @doc """
  Gets a single kanji by ID.

  Returns `nil` if the kanji does not exist.

  ## Examples

      iex> get_kanji("123e4567-e89b-12d3-a456-426614174000")
      %Kanji{}

      iex> get_kanji("non-existent-id")
      nil

  """
  def get_kanji(id), do: Repo.get(Kanji, id)

  @doc """
  Gets a single kanji by character.

  Returns `nil` if the Kanji does not exist.

  ## Examples

      iex> get_kanji_by_character("日")
      %Kanji{}

      iex> get_kanji_by_character("invalid")
      nil

  """
  def get_kanji_by_character(character) do
    Kanji
    |> where(character: ^character)
    |> preload(:kanji_readings)
    |> Repo.one()
  end

  @doc """
  Gets a single kanji with all its readings preloaded.

  Raises `Ecto.NoResultsError` if the Kanji does not exist.

  ## Examples

      iex> get_kanji_with_readings!(123)
      %Kanji{kanji_readings: [%KanjiReading{}, ...]}

  """
  def get_kanji_with_readings!(id) do
    Kanji
    |> where(id: ^id)
    |> preload(:kanji_readings)
    |> Repo.one!()
  end

  @doc """
  Gets a single kanji by its character with all its readings preloaded.

  Raises `Ecto.NoResultsError` if the Kanji does not exist.
  """
  def get_kanji_with_readings_by_character!(character) do
    Kanji
    |> where(character: ^character)
    |> preload(:kanji_readings)
    |> Repo.one!()
  end

  @doc """
  Creates a kanji.

  ## Examples

      iex> create_kanji(%{character: "日", meanings: ["sun", "day"], stroke_count: 4, jlpt_level: 5})
      {:ok, %Kanji{}}

      iex> create_kanji(%{character: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_kanji(attrs \\ %{}) do
    %Kanji{}
    |> Kanji.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a kanji with its readings in a single transaction.

  ## Examples

      iex> create_kanji_with_readings(%{character: "日", ...}, [%{reading_type: :on, ...}, ...])
      {:ok, %Kanji{kanji_readings: [%KanjiReading{}, ...]}}

  """
  def create_kanji_with_readings(kanji_attrs, readings_attrs) do
    Repo.transaction(fn ->
      kanji =
        case create_kanji(kanji_attrs) do
          {:ok, kanji} -> kanji
          {:error, changeset} -> Repo.rollback(changeset)
        end

      readings =
        Enum.map(readings_attrs, fn reading_attrs ->
          reading_attrs = Map.put(reading_attrs, :kanji_id, kanji.id)

          case create_kanji_reading(reading_attrs) do
            {:ok, reading} -> reading
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)

      %{kanji | kanji_readings: readings}
    end)
  end

  @doc """
  Updates a kanji.

  ## Examples

      iex> update_kanji(kanji, %{meanings: ["sun", "day", "Japan"]})
      {:ok, %Kanji{}}

      iex> update_kanji(kanji, %{character: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_kanji(%Kanji{} = kanji, attrs) do
    kanji
    |> Kanji.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a kanji and all its associated readings.

  ## Examples

      iex> delete_kanji(kanji)
      {:ok, %Kanji{}}

      iex> delete_kanji(kanji)
      {:error, %Ecto.Changeset{}}

  """
  def delete_kanji(%Kanji{} = kanji) do
    Repo.delete(kanji)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking kanji changes.

  ## Examples

      iex> change_kanji(kanji)
      %Ecto.Changeset{data: %Kanji{}}

  """
  def change_kanji(%Kanji{} = kanji, attrs \\ %{}) do
    Kanji.changeset(kanji, attrs)
  end

  # KanjiReading Functions

  @doc """
  Returns the list of all kanji readings.
  """
  def list_kanji_readings do
    Repo.all(KanjiReading)
  end

  @doc """
  Returns the list of readings for a specific kanji.

  ## Examples

      iex> list_readings_for_kanji(kanji_id)
      [%KanjiReading{}, ...]

  """
  def list_readings_for_kanji(kanji_id) do
    KanjiReading
    |> where(kanji_id: ^kanji_id)
    |> order_by([r], asc: r.reading_type)
    |> Repo.all()
  end

  @doc """
  Gets a single kanji reading.

  Raises `Ecto.NoResultsError` if the KanjiReading does not exist.

  ## Examples

      iex> get_kanji_reading!(123)
      %KanjiReading{}

      iex> get_kanji_reading!(456)
      ** (Ecto.NoResultsError)

  """
  def get_kanji_reading!(id), do: Repo.get!(KanjiReading, id)

  @doc """
  Creates a kanji reading.

  ## Examples

      iex> create_kanji_reading(%{reading_type: :on, reading: "ニチ", romaji: "nichi", kanji_id: 123})
      {:ok, %KanjiReading{}}

      iex> create_kanji_reading(%{reading_type: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_kanji_reading(attrs \\ %{}) do
    attrs =
      if is_nil(attrs["position"]) and is_nil(attrs[:position]) do
        kanji_id = attrs["kanji_id"] || attrs[:kanji_id]
        next_position = next_kanji_reading_position(kanji_id)

        position_key =
          if Enum.any?(attrs, fn {k, _} -> is_binary(k) end), do: "position", else: :position

        Map.put(attrs, position_key, next_position)
      else
        attrs
      end

    %KanjiReading{}
    |> KanjiReading.changeset(attrs)
    |> Repo.insert()
  end

  defp next_kanji_reading_position(nil), do: 0

  defp next_kanji_reading_position(kanji_id) do
    max_position =
      KanjiReading
      |> where([r], r.kanji_id == ^kanji_id)
      |> select([r], max(r.position))
      |> Repo.one()

    (max_position || 0) + 1
  end

  @doc """
  Updates a kanji reading.

  ## Examples

      iex> update_kanji_reading(kanji_reading, %{usage_notes: "Formal reading"})
      {:ok, %KanjiReading{}}

      iex> update_kanji_reading(kanji_reading, %{reading_type: :invalid})
      {:error, %Ecto.Changeset{}}

  """
  def update_kanji_reading(%KanjiReading{} = kanji_reading, attrs) do
    kanji_reading
    |> KanjiReading.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a kanji reading.

  ## Examples

      iex> delete_kanji_reading(kanji_reading)
      {:ok, %KanjiReading{}}

      iex> delete_kanji_reading(kanji_reading)
      {:error, %Ecto.Changeset{}}

  """
  def delete_kanji_reading(%KanjiReading{} = kanji_reading) do
    Repo.delete(kanji_reading)
  end

  @doc """
  Reorders a kanji's readings by assigning positions based on the given ordered list of reading IDs.
  """
  def reorder_kanji_readings(kanji_id, reading_ids) when is_list(reading_ids) do
    reading_ids
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {reading_id, index}, multi ->
      Ecto.Multi.update_all(
        multi,
        {:position, reading_id},
        fn _ ->
          from(r in KanjiReading,
            where: r.id == ^reading_id and r.kanji_id == ^kanji_id
          )
        end,
        set: [position: index]
      )
    end)
    |> Repo.transaction()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking kanji reading changes.

  ## Examples

      iex> change_kanji_reading(kanji_reading)
      %Ecto.Changeset{data: %KanjiReading{}}

  """
  def change_kanji_reading(%KanjiReading{} = kanji_reading, attrs \\ %{}) do
    KanjiReading.changeset(kanji_reading, attrs)
  end

  # Word Functions

  @doc """
  Returns the list of all words.
  """
  def list_words do
    Word
    |> order_by([w], asc: w.sort_score)
    |> Repo.all()
  end

  @doc """
  Returns the list of words filtered by difficulty level (1-5).

  ## Examples

      iex> list_words_by_difficulty(5)
      [%Word{}, ...]

  """
  def list_words_by_difficulty(difficulty) when difficulty in 1..5 do
    Word
    |> where(difficulty: ^difficulty)
    |> order_by([w], asc: w.sort_score)
    |> Repo.all()
  end

  @doc """
  Searches words by text, reading, or meaning.

  ## Options

    * `:limit` - Maximum number of results (default: 10)

  ## Examples

      iex> search_words("日本")
      [%Word{}, ...]

      iex> search_words("nihon", limit: 5)
      [%Word{}, ...]

  """
  def search_words(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    include_mature = Keyword.get(opts, :include_mature, true)

    if String.trim(query) == "" do
      []
    else
      query_lower = String.downcase(query)
      search_term = "%#{query}%"

      # First, get exact matches on text or reading (highest priority)
      # This ensures exact matches are never cut off by the limit
      exact_matches =
        Word
        |> where(
          [w],
          w.text == ^query or w.reading == ^query
        )
        |> Repo.all()

      # Then get partial matches, excluding exact matches to avoid duplicates
      exact_ids = Enum.map(exact_matches, & &1.id)
      partial_limit = max(limit * 5, 100)

      partial_matches =
        if length(exact_matches) >= limit do
          # If we have enough exact matches, don't need partials
          []
        else
          Word
          |> where(
            [w],
            w.id not in ^exact_ids and
              (ilike(w.text, ^search_term) or
                 ilike(w.reading, ^search_term) or
                 ilike(w.meaning, ^search_term))
          )
          |> limit(^partial_limit)
          |> Repo.all()
        end

      # Combine and filter mature content if needed
      words = exact_matches ++ partial_matches

      words =
        if include_mature do
          words
        else
          Enum.reject(words, & &1.mature)
        end

      Enum.sort_by(words, fn word ->
        meaning_lower = String.downcase(word.meaning || "")
        text_lower = String.downcase(word.text || "")
        reading_lower = String.downcase(word.reading || "")

        # Check for exact matches in text or reading (highest priority)
        exact_text = text_lower == query_lower
        exact_reading = reading_lower == query_lower
        exact_meaning = meaning_lower == query_lower

        # Check for "starts with" matches
        starts_text = String.starts_with?(text_lower, query_lower)
        starts_reading = String.starts_with?(reading_lower, query_lower)
        starts_meaning = String.starts_with?(meaning_lower, query_lower)

        # Priority (lower number = higher priority):
        # 0: Exact match on text (e.g., "一" for query "一")
        # 1: Exact match on reading (e.g., "いち" for query "いち")
        # 2: Exact match on meaning
        # 3: Starts with on text/reading
        # 4: Starts with on meaning
        # 5: Contains match
        priority =
          cond do
            exact_text -> 0
            exact_reading -> 1
            exact_meaning -> 2
            starts_text or starts_reading -> 3
            starts_meaning -> 4
            true -> 5
          end

        # For tie-breaking within exact matches:
        # - Shorter text is better (exact match "一" beats "一日")
        # - Higher usage frequency is better
        text_len = String.length(word.text || "")

        # Within same priority:
        # - Shorter text length (for exact matches)
        # - Higher usage frequency is better
        # - Lower sort_score is better
        {priority, text_len, -(word.usage_frequency || 0), word.sort_score || 999_999}
      end)
      |> Enum.take(limit)
    end
  end

  @doc """
  Searches words by query and filters by word type (verb, adjective, noun, etc.)

  ## Options

    * `:limit` - Maximum number of results (default: 20)

  ## Examples

      iex> search_words_by_type("tabe", "verb")
      [%Word{text: "食べる"}, ...]

      iex> search_words_by_type("ookii", "adjective", limit: 5)
      [%Word{text: "大きい"}, ...]
  """
  def search_words_by_type(query, word_type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    if String.trim(query) == "" or is_nil(word_type) do
      []
    else
      search_term = "%#{query}%"

      Word
      |> where(
        [w],
        w.word_type == ^word_type and
          (ilike(w.text, ^search_term) or
             ilike(w.reading, ^search_term) or
             ilike(w.meaning, ^search_term))
      )
      |> order_by([w], desc: w.usage_frequency)
      |> limit(^limit)
      |> Repo.all()
    end
  end

  @doc """
  Searches kanji by character, meanings, or readings.

  ## Options

    * `:limit` - Maximum number of results (default: 10)

  ## Examples

      iex> search_kanji("日")
      [%Kanji{}, ...]

      iex> search_kanji("sun", limit: 5)
      [%Kanji{}, ...]

  """
  def search_kanji(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    if String.trim(query) == "" do
      []
    else
      search_term = "%#{query}%"

      Kanji
      |> join(:left, [k], kr in assoc(k, :kanji_readings), as: :readings)
      |> where(
        [k, readings: kr],
        ilike(k.character, ^search_term) or
          fragment("? = ANY(?)", ^query, k.meanings) or
          ilike(kr.reading, ^search_term) or
          ilike(kr.romaji, ^search_term)
      )
      |> order_by([k], asc: k.jlpt_level, desc: k.frequency)
      |> distinct([k], true)
      |> limit(^limit)
      |> preload(:kanji_readings)
      |> Repo.all()
    end
  end

  @doc """
  Returns paginated words with search and sorting capabilities.

  ## Options

    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 30)
    * `:search` - Search term for text, reading, or meaning (default: nil)
    * `:difficulty` - Filter by JLPT level 1-5 (default: nil)
    * `:sort_by` - Sort field: `:text`, `:reading`, `:meaning`, `:difficulty`, `:word_type`, `:inserted_at`, `:usage_frequency` (default: :usage_frequency)
    * `:sort_order` - Sort order: `:asc` or `:desc` (default: :asc)

  ## Learning Order (Default)

  By default, words are sorted by usage_frequency (ascending) showing most common words first
  and visual complexity. This shows the most common, simplest words first - optimal
  for learning: single kanji → kanji+kana → 2 kanji → complex patterns.

  ## Examples

      iex> list_words_paginated(page: 1, per_page: 30)
      %{words: [%Word{}, ...], total_count: 100, total_pages: 4}

      iex> list_words_paginated(search: "日本", difficulty: 5)
      %{words: [%Word{}, ...], total_count: 10, total_pages: 1}

  """
  def list_words_paginated(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 30)
    search = Keyword.get(opts, :search)
    difficulty = Keyword.get(opts, :difficulty)
    word_type = Keyword.get(opts, :word_type)
    learned_filter = Keyword.get(opts, :learned_filter)
    user_id = Keyword.get(opts, :user_id)
    include_mature = Keyword.get(opts, :include_mature, true)
    learning_language = Keyword.get(opts, :learning_language)

    search = if search, do: String.trim(search), else: search

    if search && search != "" do
      # Use search_words for matching and ranking, then filter/paginate in Elixir.
      # This preserves the exact-matches-first ordering from search_words.
      words = search_words(search, limit: 10_000, include_mature: include_mature)

      # Apply difficulty filter
      words =
        if difficulty do
          Enum.filter(words, &(&1.difficulty == difficulty))
        else
          words
        end

      # Apply word_type filter
      words =
        if word_type do
          Enum.filter(words, &(&1.word_type == word_type))
        else
          words
        end

      # Apply learned filter if specified and user_id is provided
      words =
        if learned_filter && user_id do
          learned_word_ids =
            learned_word_ids_query(user_id, learning_language)
            |> Repo.all()
            |> MapSet.new()

          case learned_filter do
            :learned ->
              Enum.filter(words, &MapSet.member?(learned_word_ids, &1.id))

            :unlearned ->
              Enum.reject(words, &MapSet.member?(learned_word_ids, &1.id))

            _ ->
              words
          end
        else
          words
        end

      total_count = length(words)
      total_pages = max(ceil(total_count / per_page), 1)
      offset = (page - 1) * per_page

      paginated_words =
        words
        |> Enum.drop(offset)
        |> Enum.take(per_page)

      %{
        words: paginated_words,
        total_count: total_count,
        total_pages: total_pages,
        current_page: min(page, total_pages),
        per_page: per_page
      }
    else
      # Base query for words
      query = Word

      # Apply difficulty filter
      # Apply mature content filter
      query = if include_mature, do: query, else: where(query, mature: false)

      # Apply difficulty filter
      query = if difficulty, do: where(query, difficulty: ^difficulty), else: query

      # Apply word_type filter
      query = if word_type, do: where(query, word_type: ^word_type), else: query

      # Apply learned filter if specified and user_id is provided
      query =
        if learned_filter && user_id do
          case {learned_filter, learning_language} do
            {:learned, "english"} ->
              from w in query,
                join: uep in UserEnglishProgress,
                on: uep.word_id == w.id and uep.user_id == ^user_id

            {:learned, _} ->
              from w in query,
                join: up in UserProgress,
                on: up.word_id == w.id and up.user_id == ^user_id

            {:unlearned, "english"} ->
              from w in query,
                left_join: uep in UserEnglishProgress,
                on: uep.word_id == w.id and uep.user_id == ^user_id,
                where: is_nil(uep.id)

            {:unlearned, _} ->
              from w in query,
                left_join: up in UserProgress,
                on: up.word_id == w.id and up.user_id == ^user_id,
                where: is_nil(up.id)

            _ ->
              query
          end
        else
          query
        end

      # Get total count
      total_count = query |> select([w], count(w.id)) |> Repo.one()
      total_pages = max(ceil(total_count / per_page), 1)
      offset = (page - 1) * per_page

      # Get words with sorting
      words =
        query
        |> order_by([w], asc: w.usage_frequency)
        |> limit(^per_page)
        |> offset(^offset)
        |> Repo.all()

      %{
        words: words,
        total_count: total_count,
        total_pages: total_pages,
        current_page: min(page, total_pages),
        per_page: per_page
      }
    end
  end

  defp learned_word_ids_query(user_id, "english") do
    UserEnglishProgress
    |> where([uep], uep.user_id == ^user_id)
    |> select([uep], uep.word_id)
  end

  defp learned_word_ids_query(user_id, _learning_language) do
    UserProgress
    |> where([up], up.user_id == ^user_id)
    |> select([up], up.word_id)
  end

  @doc """
  Returns the list of words containing a specific kanji.

  ## Examples

      iex> list_words_by_kanji(kanji_id)
      [%Word{}, ...]

  """
  def list_words_by_kanji(kanji_id, opts \\ []) do
    include_mature = Keyword.get(opts, :include_mature, true)

    query =
      Word
      |> join(:inner, [w], wk in WordKanji, on: wk.word_id == w.id)
      |> where([w, wk], wk.kanji_id == ^kanji_id)

    query = if include_mature, do: query, else: where(query, mature: false)

    query
    |> order_by([w], asc: w.sort_score)
    |> Repo.all()
  end

  @doc """
  Returns words containing a specific kanji, grouped by reading.

  Fetches all words from the database, then groups them by reading in memory.
  Each reading group has its own pagination (default 5 words per page).
  Known readings come first (on'yomi before kun'yomi), "misc" last.

  ## Examples

      iex> list_words_by_kanji_grouped_by_reading(kanji_id, reading_pages: %{"ひ" => 2}, per_page: 5)
      %{groups: [%{reading: "ひ", words: [...], page: 2, total_pages: 3, ...}], total_count: 25}

  """
  def list_words_by_kanji_grouped_by_reading(kanji_id, opts \\ []) do
    reading_pages = Keyword.get(opts, :reading_pages, %{})
    per_page = Keyword.get(opts, :per_page, 5)
    include_mature = Keyword.get(opts, :include_mature, true)

    # Get the kanji character for complexity sorting
    kanji = Repo.get!(Kanji, kanji_id)

    # Get ALL word_kanjis for this kanji - no DB pagination
    word_kanjis =
      WordKanji
      |> where(kanji_id: ^kanji_id)
      |> join(:inner, [wk], w in assoc(wk, :word))
      |> order_by([wk, w], asc: w.usage_frequency)
      |> preload([:word, :kanji_reading])
      |> Repo.all()

    word_kanjis =
      if include_mature do
        word_kanjis
      else
        Enum.reject(word_kanjis, & &1.word.mature)
      end

    total_count = length(word_kanjis)

    # Sort by frequency, then by composition complexity:
    # - words with just this kanji
    # - words with just this kanji + kana
    # - words with just this kanji + one another kanji
    # - words with just this kanji + another kanji + kana
    # - and so on (more other kanji = later)
    sorted_word_kanjis =
      Enum.sort_by(word_kanjis, fn wk ->
        word = wk.word
        {word.usage_frequency, word_complexity_key(word.text, kanji.character)}
      end)

    # Group by reading (kanji_reading.reading or "misc" if no specific reading)
    grouped =
      sorted_word_kanjis
      |> Enum.group_by(fn wk ->
        case wk.kanji_reading do
          nil -> "misc"
          reading -> reading.reading
        end
      end)

    # Sort groups: known readings first (on before kun), "misc" last
    sorted_groups =
      grouped
      |> Enum.sort_by(fn
        {"misc", _} ->
          {2, ""}

        {reading, wks} ->
          reading_type =
            case List.first(wks).kanji_reading do
              nil -> :on
              r -> r.reading_type
            end

          type_order = if reading_type == :on, do: 0, else: 1
          {type_order, reading}
      end)

    # Apply per-group pagination
    paginated_groups =
      Enum.map(sorted_groups, fn {reading, wks} ->
        page = Map.get(reading_pages, reading, 1)
        all_words = Enum.map(wks, & &1.word)
        total_in_group = length(all_words)
        total_pages = max(ceil(total_in_group / per_page), 1)
        page = min(page, total_pages)
        offset = (page - 1) * per_page

        words = Enum.slice(all_words, offset, per_page)

        %{
          reading: reading,
          words: words,
          total_count: total_in_group,
          page: page,
          per_page: per_page,
          total_pages: total_pages
        }
      end)

    %{
      groups: paginated_groups,
      total_count: total_count
    }
  end

  # Computes a sort key for word text relative to a target kanji character.
  # Lower tuple values sort earlier.
  # Priority:
  #   1. Just the target kanji (e.g. 山)
  #   2. Target kanji + kana, kanji before kana, shortest first (e.g. 山あ, 山あい)
  #   3. Target kanji + kana, kanji after kana, shortest first (e.g. あ山)
  #   4. Words with other kanji, fewer other kanji first, pure kanji before mixed
  defp word_complexity_key(text, target_kanji) do
    chars = String.to_charlist(text)

    kanji_count =
      Enum.count(chars, &kanji_char?/1)

    target_count = Enum.count(chars, fn cp -> <<cp::utf8>> == target_kanji end)
    other_kanji_count = kanji_count - target_count
    has_kana = Enum.any?(chars, &kana_char?/1)

    cond do
      # Just the target kanji — highest priority
      other_kanji_count == 0 and not has_kana ->
        {0, 0, 0, 0}

      # Target kanji + kana (no other kanji)
      other_kanji_count == 0 and has_kana ->
        kanji_first = kanji_before_kana?(text, target_kanji)
        # 0 when kanji is before kana (priority), 1 otherwise
        priority = if kanji_first, do: 0, else: 1
        {0, 1, priority, String.length(text)}

      # Words containing other kanji
      true ->
        {other_kanji_count, if(has_kana, do: 1, else: 0), 0, 0}
    end
  end

  defp kanji_char?(cp) do
    (cp >= 0x4E00 and cp <= 0x9FFF) or
      (cp >= 0x3400 and cp <= 0x4DBF)
  end

  defp kana_char?(cp) do
    (cp >= 0x3040 and cp <= 0x309F) or
      (cp >= 0x30A0 and cp <= 0x30FF) or
      cp == 0x30FC
  end

  defp kanji_before_kana?(text, target_kanji) do
    graphemes = String.graphemes(text)

    kanji_idx = Enum.find_index(graphemes, &(&1 == target_kanji))

    kana_idx =
      Enum.find_index(graphemes, fn g ->
        case String.to_charlist(g) do
          [cp] -> kana_char?(cp)
          _ -> false
        end
      end)

    kanji_idx != nil and kana_idx != nil and kanji_idx < kana_idx
  end

  @doc """
  Gets a single word by ID.

  Raises `Ecto.NoResultsError` if the Word does not exist.

  ## Examples

      iex> get_word!(123)
      %Word{}

      iex> get_word!(456)
      ** (Ecto.NoResultsError)

  """
  def get_word!(id), do: Repo.get!(Word, id)

  @doc """
  Gets a single word by ID.

  Returns `nil` if the word does not exist.

  ## Examples

      iex> get_word("123e4567-e89b-12d3-a456-426614174000")
      %Word{}

      iex> get_word("non-existent-id")
      nil

  """
  def get_word(id), do: Repo.get(Word, id)

  @doc """
  Gets a word by its English meaning.

  Returns `nil` if no word is found with that meaning.

  ## Examples

      iex> get_word_by_meaning("to eat")
      %Word{}

      iex> get_word_by_meaning("nonexistent")
      nil

  """
  def get_word_by_meaning(meaning) when is_binary(meaning) do
    Word
    |> where([w], w.meaning == ^meaning)
    |> limit(1)
    |> Repo.one()
  end

  def get_word_by_meaning(_), do: nil

  @doc """
  Gets a single word with its kanji and readings preloaded.

  Raises `Ecto.NoResultsError` if the Word does not exist.

  ## Examples

      iex> get_word_with_kanji!(123)
      %Word{word_kanjis: [%WordKanji{kanji: %Kanji{}, kanji_reading: %KanjiReading{}}, ...]}

  """
  def get_word_with_kanji!(id) do
    Word
    |> where(id: ^id)
    |> preload(word_kanjis: [:kanji, :kanji_reading])
    |> Repo.one!()
  end

  @doc """
  Gets a single word by its text with kanji and readings preloaded.

  Raises `Ecto.NoResultsError` if the Word does not exist.
  """
  def get_word_with_kanji_by_text!(text) do
    Word
    |> where(text: ^text)
    |> preload(word_kanjis: [:kanji, :kanji_reading])
    |> Repo.one!()
  end

  @doc """
  Gets a single word by its text.

  Raises `Ecto.NoResultsError` if the Word does not exist.
  """
  def get_word_by_text!(text) do
    Word
    |> where(text: ^text)
    |> Repo.one!()
  end

  @doc """
  Gets a single word with kanji, readings, and word relations preloaded.
  """
  def get_word_with_kanji_and_relations!(id) do
    Word
    |> where(id: ^id)
    |> preload(word_kanjis: [:kanji, :kanji_reading], word_relations: :related_word)
    |> Repo.one!()
  end

  @doc """
  Gets a word by its text.

  Returns `nil` if the Word does not exist.

  ## Examples

      iex> get_word_by_text("日本")
      %Word{}

      iex> get_word_by_text("invalid")
      nil

  """
  def get_word_by_text(text) do
    Repo.get_by(Word, text: text)
  end

  @doc """
  Finds words by their hiragana/katakana reading.
  Returns a list of words matching the reading.

  ## Examples

      iex> find_words_by_reading("けす")
      [%Word{text: "消す", reading: "けす"}, ...]

  """
  def find_words_by_reading(reading) when is_binary(reading) do
    Word
    |> where(reading: ^reading)
    |> order_by([w], asc: w.usage_frequency)
    |> Repo.all()
  end

  @doc """
  Gets a single word by its Japanese text, falling back to a case-insensitive
  meaning search. Returns the first match or `nil`.

  ## Examples

      iex> get_word_by_text_or_meaning("日本")
      %Word{}

      iex> get_word_by_text_or_meaning("Japan")
      %Word{text: "日本", meaning: "Japan"}

      iex> get_word_by_text_or_meaning("invalid")
      nil

  """
  def get_word_by_text_or_meaning(text) do
    case Repo.get_by(Word, text: text) do
      nil ->
        # 1. Exact meaning match — pick best by frequency / length
        exact_meaning_matches =
          Word
          |> where([w], w.meaning == ^text)
          |> Repo.all()

        case pick_best_word(exact_meaning_matches) do
          nil ->
            search = "%#{text}%"

            # 2. Fetch candidates for exact split match
            candidates =
              Word
              |> where([w], ilike(w.meaning, ^search))
              |> limit(50)
              |> Repo.all()

            split_matches =
              Enum.filter(candidates, fn word ->
                word.meaning
                |> String.split(["/", ","])
                |> Enum.map(&String.trim/1)
                |> Enum.any?(&(&1 == text))
              end)

            case pick_best_word(split_matches) do
              nil ->
                # 3. Pick best from all meaning-containing candidates
                pick_best_word(candidates)

              word ->
                word
            end

          word ->
            word
        end

      word ->
        word
    end
  end

  @doc """
  Gets a single word by its Japanese text, meaning, or conjugated form.
  Falls back through: exact text → meaning ILIKE → conjugated form / alternative forms.
  Returns the first match or `nil`.

  ## Examples

      iex> get_word_by_text_or_meaning_or_conjugation("日本")
      %Word{}

      iex> get_word_by_text_or_meaning_or_conjugation("Japan")
      %Word{text: "日本", meaning: "Japan"}

      iex> get_word_by_text_or_meaning_or_conjugation("わかった")
      %Word{text: "わかる"}

      iex> get_word_by_text_or_meaning_or_conjugation("invalid")
      nil

  """
  def get_word_by_text_or_meaning_or_conjugation(text) do
    case get_word_by_text_or_meaning(text) do
      nil ->
        conjugation_matches =
          WordConjugation
          |> where(
            [wc],
            wc.conjugated_form == ^text or wc.reading == ^text or
              fragment("? = ANY(?)", ^text, wc.alternative_forms)
          )
          |> join(:inner, [wc], w in assoc(wc, :word))
          |> select([wc, w], w)
          |> Repo.all()

        pick_best_word(conjugation_matches)

      word ->
        word
    end
  end

  # Tie-breaking for word lookup when multiple candidates match:
  # 1. Lowest usage_frequency (least common first)
  # 2. Shortest combined text + reading length
  # 3. First by insertion order (id)
  defp pick_best_word([]), do: nil

  defp pick_best_word(words) when is_list(words) do
    words
    |> Enum.sort_by(fn word ->
      text_len = String.length(word.text || "")
      reading_len = String.length(word.reading || "")
      {word.usage_frequency || 999_999, text_len + reading_len, word.id}
    end)
    |> List.first()
  end

  @doc """
  Creates a word.

  ## Examples

      iex> create_word(%{text: "日本", meaning: "Japan", reading: "にほん", difficulty: 5})
      {:ok, %Word{}}

      iex> create_word(%{text: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_word(attrs \\ %{}) do
    %Word{}
    |> Word.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a word with its kanji links in a single transaction.

  The kanji_links should be a list of maps with:
  - :position - position in word (0-indexed)
  - :kanji_id - the kanji ID
  - :kanji_reading_id - (optional) the specific reading ID

  ## Examples

      iex> create_word_with_kanji(%{text: "日本", ...}, [
      ...>   %{position: 0, kanji_id: nichi_id, kanji_reading_id: nichi_reading_id},
      ...>   %{position: 1, kanji_id: hon_id, kanji_reading_id: hon_reading_id}
      ...> ])
      {:ok, %Word{word_kanjis: [%WordKanji{}, ...]}}

  """
  def create_word_with_kanji(word_attrs, kanji_links) do
    Repo.transaction(fn ->
      word =
        case create_word(word_attrs) do
          {:ok, word} -> word
          {:error, changeset} -> Repo.rollback(changeset)
        end

      word_kanjis =
        Enum.map(kanji_links, fn link_attrs ->
          link_attrs = Map.put(link_attrs, :word_id, word.id)

          case create_word_kanji(link_attrs) do
            {:ok, word_kanji} -> word_kanji
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)

      %{word | word_kanjis: word_kanjis}
    end)
  end

  @doc """
  Updates a word.

  ## Examples

      iex> update_word(word, %{meaning: "new meaning"})
      {:ok, %Word{}}

      iex> update_word(word, %{text: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_word(%Word{} = word, attrs) do
    word
    |> Word.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a word and all its associated kanji links.

  ## Examples

      iex> delete_word(word)
      {:ok, %Word{}}

      iex> delete_word(word)
      {:error, %Ecto.Changeset{}}

  """
  def delete_word(%Word{} = word) do
    Repo.delete(word)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking word changes.

  ## Examples

      iex> change_word(word)
      %Ecto.Changeset{data: %Word{}}

  """
  def change_word(%Word{} = word, attrs \\ %{}) do
    Word.changeset(word, attrs)
  end

  # WordKanji Functions

  @doc """
  Returns the list of all word kanji links.
  """
  def list_word_kanjis do
    Repo.all(WordKanji)
  end

  @doc """
  Returns the list of kanji links for a specific word.

  ## Examples

      iex> list_kanji_for_word(word_id)
      [%WordKanji{}, ...]

  """
  def list_kanji_for_word(word_id) do
    WordKanji
    |> where(word_id: ^word_id)
    |> order_by([wk], asc: wk.position)
    |> preload([:kanji, :kanji_reading])
    |> Repo.all()
  end

  @doc """
  Gets a single word kanji link.

  Raises `Ecto.NoResultsError` if the WordKanji does not exist.

  ## Examples

      iex> get_word_kanji!(123)
      %WordKanji{}

      iex> get_word_kanji!(456)
      ** (Ecto.NoResultsError)

  """
  def get_word_kanji!(id), do: Repo.get!(WordKanji, id)

  @doc """
  Creates a word kanji link.

  ## Examples

      iex> create_word_kanji(%{position: 0, word_id: word_id, kanji_id: kanji_id})
      {:ok, %WordKanji{}}

      iex> create_word_kanji(%{position: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_word_kanji(attrs \\ %{}) do
    %WordKanji{}
    |> WordKanji.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a word kanji link.

  ## Examples

      iex> update_word_kanji(word_kanji, %{position: 1})
      {:ok, %WordKanji{}}

      iex> update_word_kanji(word_kanji, %{position: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_word_kanji(%WordKanji{} = word_kanji, attrs) do
    word_kanji
    |> WordKanji.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a word kanji link.

  ## Examples

      iex> delete_word_kanji(word_kanji)
      {:ok, %WordKanji{}}

      iex> delete_word_kanji(word_kanji)
      {:error, %Ecto.Changeset{}}

  """
  def delete_word_kanji(%WordKanji{} = word_kanji) do
    Repo.delete(word_kanji)
  end

  @doc """
  Deletes multiple word kanji associations for a given word.

  Returns `{:ok, count}` with the number of deleted records.

  ## Examples

      iex> delete_word_kanjis(word_id, [word_kanji_id1, word_kanji_id2])
      {:ok, 2}

  """
  def delete_word_kanjis(word_id, word_kanji_ids) when is_list(word_kanji_ids) do
    {count, _} =
      WordKanji
      |> where([wk], wk.word_id == ^word_id and wk.id in ^word_kanji_ids)
      |> Repo.delete_all()

    {:ok, count}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking word kanji changes.

  ## Examples

      iex> change_word_kanji(word_kanji)
      %Ecto.Changeset{data: %WordKanji{}}

  """
  def change_word_kanji(%WordKanji{} = word_kanji, attrs \\ %{}) do
    WordKanji.changeset(word_kanji, attrs)
  end

  @doc """
  Extracts kanji from a word's text and creates word_kanji associations.

  Only creates associations for kanji that:
  - Exist in the database
  - Are NOT already associated with this word

  Returns {:ok, [new_word_kanjis]} with only the newly created associations,
  or {:error, reason} if something went wrong.

  ## Examples

      iex> extract_and_link_kanji_for_word(%Word{text: "日本", reading: "にほん"})
      {:ok, [%WordKanji{kanji: %Kanji{character: "日"}}, %WordKanji{kanji: %Kanji{character: "本"}}]}

  """
  def extract_and_link_kanji_for_word(%Word{} = word) do
    # Get existing kanji characters already linked to this word
    existing_kanji_chars =
      WordKanji
      |> where([wk], wk.word_id == ^word.id)
      |> join(:inner, [wk], k in assoc(wk, :kanji))
      |> select([wk, k], k.character)
      |> Repo.all()
      |> MapSet.new()

    # Extract all kanji from word text with positions
    kanji_chars_with_positions = extract_kanji_from_text(word.text)

    # Filter out already existing kanji
    new_kanji_chars =
      Enum.reject(kanji_chars_with_positions, fn {char, _pos} ->
        MapSet.member?(existing_kanji_chars, char)
      end)

    if new_kanji_chars == [] do
      {:ok, []}
    else
      # Get kanji IDs for the new characters
      new_chars_list = Enum.map(new_kanji_chars, fn {char, _pos} -> char end)

      kanji_map =
        Kanji
        |> where([k], k.character in ^new_chars_list)
        |> preload(:kanji_readings)
        |> Repo.all()
        |> Map.new(fn k -> {k.character, k} end)

      # Try to extract readings from word
      extracted_readings =
        case word.reading do
          nil -> %{}
          "" -> %{}
          reading -> extract_all_kanji_readings(word.text, reading)
        end

      # Create word_kanji links for new kanji only
      new_word_kanjis =
        Enum.map(new_kanji_chars, fn {char, position} ->
          case Map.get(kanji_map, char) do
            nil ->
              # Kanji not found in database
              nil

            kanji ->
              # Try to find matching reading
              kanji_reading = Map.get(extracted_readings, char)

              reading_id =
                if kanji_reading do
                  Enum.find_value(kanji.kanji_readings, nil, fn r ->
                    if r.reading == kanji_reading, do: r.id, else: nil
                  end)
                else
                  nil
                end

              attrs = %{
                word_id: word.id,
                kanji_id: kanji.id,
                position: position,
                kanji_reading_id: reading_id
              }

              case create_word_kanji(attrs) do
                {:ok, word_kanji} -> word_kanji
                {:error, _} -> nil
              end
          end
        end)
        |> Enum.reject(&is_nil/1)

      {:ok, new_word_kanjis}
    end
  end

  # Extract kanji characters from text with their positions
  defp extract_kanji_from_text(text) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.filter(fn {char, _idx} ->
      KanjiReadingExtractor.kanji?(char)
    end)
  end

  # Word Relation Functions

  @doc """
  Returns approved relations for a word, grouped by relation type.

  The result is a map like:
    %{
      synonym: [%{id: ..., text: ..., reading: ..., meaning: ...} | %{text: "..."}],
      antonym: [...],
      expression: [...]
    }

  For linked words the map contains word data; for text-only expressions it
  contains `:text`.
  """
  def list_word_relations_for_word(word_id) do
    WordRelation
    |> where([wr], wr.word_id == ^word_id and wr.status == :approved)
    |> preload(:related_word)
    |> order_by([wr], asc: wr.inserted_at)
    |> Repo.all()
    |> Enum.group_by(& &1.relation_type)
    |> Map.new(fn {type, relations} ->
      {type,
       Enum.map(relations, fn relation ->
         if relation.related_word do
           %{
             id: relation.related_word.id,
             text: relation.related_word.text,
             reading: relation.related_word.reading,
             meaning: relation.related_word.meaning,
             word_type: relation.related_word.word_type,
             linked: true
           }
         else
           %{
             text: relation.expression_text,
             linked: false
           }
         end
       end)}
    end)
  end

  @doc """
  Returns all pending relations for a word.
  """
  def list_pending_word_relations_for_word(word_id) do
    WordRelation
    |> where([wr], wr.word_id == ^word_id and wr.status == :pending)
    |> preload(:related_word)
    |> order_by([wr], asc: wr.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns all word relation structs (approved, pending, or rejected) for a word.
  """
  def list_word_relations_for_word_structs(word_id) do
    WordRelation
    |> where([wr], wr.word_id == ^word_id)
    |> Repo.all()
  end

  @doc """
  Gets a single word relation.

  Raises `Ecto.NoResultsError` if the relation does not exist.
  """
  def get_word_relation!(id), do: Repo.get!(WordRelation, id)

  @doc """
  Creates a word relation.
  """
  def create_word_relation(attrs \\ %{}) do
    %WordRelation{}
    |> WordRelation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Approves a pending word relation. For synonyms and antonyms, also creates the
  inverse relation so the relationship is bidirectional.
  """
  def approve_word_relation(%WordRelation{status: :pending} = relation) do
    Repo.transaction(fn ->
      {:ok, approved} =
        relation
        |> WordRelation.changeset(%{status: :approved})
        |> Repo.update()

      if relation.relation_type in [:synonym, :antonym] and not is_nil(relation.related_word_id) do
        # Create the inverse relation unless it already exists.
        existing_inverse =
          WordRelation
          |> where(
            [wr],
            wr.word_id == ^relation.related_word_id and
              wr.related_word_id == ^relation.word_id and
              wr.relation_type == ^relation.relation_type and
              wr.status == :approved
          )
          |> Repo.one()

        if is_nil(existing_inverse) do
          {:ok, _inverse} =
            create_word_relation(%{
              word_id: relation.related_word_id,
              related_word_id: relation.word_id,
              relation_type: relation.relation_type,
              status: :approved
            })
        end
      end

      approved
    end)
  end

  @doc """
  Rejects a pending word relation by deleting it.
  """
  def reject_word_relation(%WordRelation{} = relation) do
    Repo.delete(relation)
  end

  @doc """
  Deletes a word relation. For synonyms and antonyms that link two words,
  also deletes the inverse approved relation so the relationship is removed
  from both sides.
  """
  def delete_word_relation(%WordRelation{} = relation) do
    Repo.transaction(fn ->
      if relation.relation_type in [:synonym, :antonym] and not is_nil(relation.related_word_id) do
        inverse_query =
          from(wr in WordRelation,
            where:
              wr.word_id == ^relation.related_word_id and
                wr.related_word_id == ^relation.word_id and
                wr.relation_type == ^relation.relation_type and
                wr.status == :approved
          )

        Repo.delete_all(inverse_query)
      end

      {:ok, deleted} = Repo.delete(relation)
      deleted
    end)
  end

  @doc """
  Finds a word by its Japanese text, returning only the fields needed for
  relation matching.
  """
  def find_word_for_relation(text) when is_binary(text) do
    trimmed = String.trim(text)

    Word
    |> where([w], w.text == ^trimmed)
    |> select([w], %{
      id: w.id,
      text: w.text,
      reading: w.reading,
      meaning: w.meaning,
      word_type: w.word_type
    })
    |> Repo.one()
  end

  def find_word_for_relation(_), do: nil

  # Lesson Functions

  @doc """
  Returns the list of all lessons ordered by difficulty and order_index.
  """
  def list_lessons do
    Lesson
    |> order_by([l], asc: l.difficulty, asc: l.order_index)
    |> preload(lesson_words: :word)
    |> Repo.all()
  end

  @doc """
  Returns the list of lessons filtered by difficulty level (1-5).

  ## Examples

      iex> list_lessons_by_difficulty(5)
      [%Lesson{}, ...]

  """
  def list_lessons_by_difficulty(difficulty) when difficulty in 1..5 do
    Lesson
    |> where(difficulty: ^difficulty)
    |> order_by([l], asc: l.order_index)
    |> preload(lesson_words: :word)
    |> Repo.all()
  end

  @doc """
  Returns paginated lessons with search capabilities.

  ## Options

    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 20)
    * `:search` - Search term for title (default: nil)
    * `:difficulty` - Filter by JLPT level 1-5 (default: nil)
    * `:lesson_type` - Filter by lesson type (default: nil)

  ## Sorting

  Lessons are sorted by:
  1. JLPT level (easiest N5 first)
  2. Word length (shorter words first - easier to learn)
  3. Order index (for consistent pagination)

  ## Examples

      iex> list_lessons_paginated(page: 1, per_page: 20)
      %{lessons: [%Lesson{}, ...], total_count: 100, total_pages: 5}

      iex> list_lessons_paginated(search: "日本", difficulty: 5)
      %{lessons: [%Lesson{}, ...], total_count: 10, total_pages: 1}

  """
  def list_lessons_paginated(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    search = Keyword.get(opts, :search)
    difficulty = Keyword.get(opts, :difficulty)
    lesson_type = Keyword.get(opts, :lesson_type)

    # Build base query
    query = Lesson

    # Apply filters
    query = if difficulty, do: where(query, difficulty: ^difficulty), else: query
    query = if lesson_type, do: where(query, lesson_type: ^lesson_type), else: query

    # Apply search filter (case-insensitive ILIKE for PostgreSQL)
    query =
      if search && search != "" do
        search_term = "%#{search}%"
        where(query, [l], ilike(l.title, ^search_term))
      else
        query
      end

    # Get total count for pagination
    total_count = query |> select([l], count(l.id)) |> Repo.one()
    total_pages = ceil(total_count / per_page)

    # Apply ordering:
    # 1. By difficulty (easiest N5 first - desc since 5 > 1)
    # 2. By order_index (lesson progression)
    # 3. By title length (shorter words first) as tiebreaker
    query =
      order_by(query, [l],
        desc: l.difficulty,
        asc: l.order_index,
        asc: fragment("LENGTH(?)", l.title)
      )

    # Apply pagination
    offset = (page - 1) * per_page
    query = query |> limit(^per_page) |> offset(^offset)

    # Preload associations
    lessons = query |> preload(lesson_words: :word) |> Repo.all()

    %{
      lessons: lessons,
      total_count: total_count,
      total_pages: total_pages,
      current_page: page,
      per_page: per_page
    }
  end

  @doc """
  Returns a list of lessons filtered by lesson type.

  ## Examples

      iex> list_lessons_by_type(:reading)
      [%Lesson{}, ...]

  """
  def list_lessons_by_type(lesson_type)
      when lesson_type in [:reading, :writing, :listening, :speaking, :grammar] do
    Lesson
    |> where(lesson_type: ^lesson_type)
    |> order_by([l], asc: l.difficulty, asc: l.order_index)
    |> preload(lesson_words: :word)
    |> Repo.all()
  end

  @doc """
  Gets a single lesson by ID.

  Raises `Ecto.NoResultsError` if the Lesson does not exist.

  ## Examples

      iex> get_lesson!(123)
      %Lesson{}

      iex> get_lesson!(456)
      ** (Ecto.NoResultsError)

  """
  def get_lesson!(id), do: Repo.get!(Lesson, id)

  @doc """
  Gets a single lesson with its words preloaded.

  Raises `Ecto.NoResultsError` if the Lesson does not exist.

  ## Examples

      iex> get_lesson_with_words!(123)
      %Lesson{lesson_words: [%LessonWord{word: %Word{}}, ...]}

  """
  def get_lesson_with_words!(id) do
    Lesson
    |> where(id: ^id)
    |> preload(lesson_words: [word: :word_kanjis])
    |> Repo.one!()
  end

  @doc """
  Gets a single lesson with full word data preloaded for learning.
  Preloads words, word_kanjis, kanji, and kanji_readings.

  Raises `Ecto.NoResultsError` if the Lesson does not exist.

  ## Examples

      iex> get_lesson_for_learning!(123)
      %Lesson{lesson_words: [%LessonWord{word: %Word{word_kanjis: [%WordKanji{kanji: %Kanji{}, kanji_reading: %KanjiReading{}}]}}, ...]}

  """
  def get_lesson_for_learning!(id) do
    Lesson
    |> where(id: ^id)
    |> preload(
      lesson_words: [
        word: [
          word_kanjis: [:kanji, :kanji_reading]
        ]
      ]
    )
    |> Repo.one!()
  end

  @doc """
  Creates a lesson.

  ## Examples

      iex> create_lesson(%{title: "Basic Kanji", description: "Learn...", difficulty: 5, order_index: 1})
      {:ok, %Lesson{}}

      iex> create_lesson(%{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_lesson(attrs \\ %{}) do
    %Lesson{}
    |> Lesson.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a lesson with its word links in a single transaction.

  The word_links should be a list of maps with:
  - :position - position in lesson (0-indexed)
  - :word_id - the word ID

  ## Examples

      iex> create_lesson_with_words(%{title: "Basic Vocabulary", ...}, [
      ...>   %{position: 0, word_id: word1_id},
      ...>   %{position: 1, word_id: word2_id}
      ...> ])
      {:ok, %Lesson{lesson_words: [%LessonWord{}, ...]}}

  """
  def create_lesson_with_words(lesson_attrs, word_links) do
    Repo.transaction(fn ->
      lesson =
        case create_lesson(lesson_attrs) do
          {:ok, lesson} -> lesson
          {:error, changeset} -> Repo.rollback(changeset)
        end

      lesson_words =
        Enum.map(word_links, fn link_attrs ->
          link_attrs = Map.put(link_attrs, :lesson_id, lesson.id)

          case create_lesson_word(link_attrs) do
            {:ok, lesson_word} -> lesson_word
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)

      %{lesson | lesson_words: lesson_words}
    end)
  end

  @doc """
  Updates a lesson.

  ## Examples

      iex> update_lesson(lesson, %{title: "Updated Title"})
      {:ok, %Lesson{}}

      iex> update_lesson(lesson, %{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_lesson(%Lesson{} = lesson, attrs) do
    lesson
    |> Lesson.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a lesson and all its associated kanji links.

  ## Examples

      iex> delete_lesson(lesson)
      {:ok, %Lesson{}}

      iex> delete_lesson(lesson)
      {:error, %Ecto.Changeset{}}

  """
  def delete_lesson(%Lesson{} = lesson) do
    Repo.delete(lesson)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lesson changes.

  ## Examples

      iex> change_lesson(lesson)
      %Ecto.Changeset{data: %Lesson{}}

  """
  def change_lesson(%Lesson{} = lesson, attrs \\ %{}) do
    Lesson.changeset(lesson, attrs)
  end

  # LessonWord Functions

  @doc """
  Returns the list of all lesson word links.
  """
  def list_lesson_words do
    Repo.all(LessonWord)
  end

  @doc """
  Returns the list of word links for a specific lesson.

  ## Examples

      iex> list_words_for_lesson(lesson_id)
      [%LessonWord{}, ...]

  """
  def list_words_for_lesson(lesson_id) do
    LessonWord
    |> where(lesson_id: ^lesson_id)
    |> order_by([lw], asc: lw.position)
    |> preload(:word)
    |> Repo.all()
  end

  @doc """
  Gets a single lesson word link.

  Raises `Ecto.NoResultsError` if the LessonWord does not exist.

  ## Examples

      iex> get_lesson_word!(123)
      %LessonWord{}

      iex> get_lesson_word!(456)
      ** (Ecto.NoResultsError)

  """
  def get_lesson_word!(id), do: Repo.get!(LessonWord, id)

  @doc """
  Creates a lesson word link.

  ## Examples

      iex> create_lesson_word(%{position: 0, lesson_id: lesson_id, word_id: word_id})
      {:ok, %LessonWord{}}

      iex> create_lesson_word(%{position: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_lesson_word(attrs \\ %{}) do
    %LessonWord{}
    |> LessonWord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a lesson word link.

  ## Examples

      iex> update_lesson_word(lesson_word, %{position: 1})
      {:ok, %LessonWord{}}

      iex> update_lesson_word(lesson_word, %{position: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_lesson_word(%LessonWord{} = lesson_word, attrs) do
    lesson_word
    |> LessonWord.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a lesson word link.

  ## Examples

      iex> delete_lesson_word(lesson_word)
      {:ok, %LessonWord{}}

      iex> delete_lesson_word(lesson_word)
      {:error, %Ecto.Changeset{}}

  """
  def delete_lesson_word(%LessonWord{} = lesson_word) do
    Repo.delete(lesson_word)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lesson word changes.

  ## Examples

      iex> change_lesson_word(lesson_word)
      %Ecto.Changeset{data: %LessonWord{}}

  """
  def change_lesson_word(%LessonWord{} = lesson_word, attrs \\ %{}) do
    LessonWord.changeset(lesson_word, attrs)
  end

  # Kanji Reading Extraction

  @doc """
  Extracts the reading for a kanji in a word by analyzing the word text and reading.

  This is useful when the word_kanji association doesn't have a linked reading.
  It works by comparing the kanji text with the hiragana/katakana reading.

  ## Examples

      iex> extract_kanji_reading("ついこの間", "ついこのあいだ", "間")
      "あいだ"
      
      iex> extract_kanji_reading("のし上がる", "のしあがる", "上")
      "あ"
  """
  def extract_kanji_reading(word_text, word_reading, kanji_character) do
    case KanjiReadingExtractor.extract_all_readings(word_text, word_reading) do
      {:ok, readings} -> Map.get(readings, kanji_character)
    end
  end

  @doc """
  Returns a map of all kanji readings for a word.

  ## Example

      iex> extract_all_kanji_readings("ついこの間", "ついこのあいだ")
      %{"間" => "あいだ"}
  """
  def extract_all_kanji_readings(word_text, word_reading) do
    case KanjiReadingExtractor.extract_all_readings(word_text, word_reading) do
      {:ok, readings} -> readings
    end
  end

  # ============================================================================
  # Custom Lesson Functions (Iteration 31)
  # ============================================================================

  alias Medoru.Classrooms.ClassroomCustomLesson

  @doc """
  Returns the list of custom lessons for a teacher.

  ## Examples

      iex> list_teacher_custom_lessons(teacher_id)
      [%CustomLesson{}, ...]

  """
  def list_teacher_custom_lessons(teacher_id, opts \\ []) do
    status = Keyword.get(opts, :status)

    CustomLesson
    |> where([cl], cl.creator_id == ^teacher_id)
    |> then(fn query ->
      if status do
        where(query, [cl], cl.status == ^status)
      else
        query
      end
    end)
    |> order_by([cl], desc: cl.inserted_at)
    |> preload(:grammar_lesson_steps)
    |> Repo.all()
  end

  @doc """
  Returns all custom lessons across all teachers for admin.
  Optionally filtered by status.
  """
  def list_all_custom_lessons(opts \\ []) do
    status = Keyword.get(opts, :status)

    CustomLesson
    |> then(fn query ->
      if status do
        where(query, [cl], cl.status == ^status)
      else
        query
      end
    end)
    |> preload([:creator])
    |> order_by([cl], desc: cl.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single custom lesson.

  Raises `Ecto.NoResultsError` if the CustomLesson does not exist.

  ## Examples

      iex> get_custom_lesson!(123)
      %CustomLesson{}

      iex> get_custom_lesson!(456)
      ** (Ecto.NoResultsError)

  """
  def get_custom_lesson!(id) do
    CustomLesson
    |> where(id: ^id)
    |> preload(:creator)
    |> Repo.one!()
  end

  @doc """
  Gets a single custom lesson with words preloaded.

  ## Examples

      iex> get_custom_lesson_with_words!(123)
      %CustomLesson{custom_lesson_words: [%CustomLessonWord{word: %Word{}}, ...]}

  """
  def get_custom_lesson_with_words!(id) do
    CustomLesson
    |> where(id: ^id)
    |> preload([:creator, custom_lesson_words: :word])
    |> Repo.one!()
  end

  @doc """
  Gets a single custom lesson with words and grammar steps preloaded.

  ## Examples

      iex> get_custom_lesson_with_lesson_data!(123)
      %CustomLesson{custom_lesson_words: [...], grammar_lesson_steps: [...]}

  """
  def get_custom_lesson_with_lesson_data!(id) do
    CustomLesson
    |> where(id: ^id)
    |> preload([:creator, :grammar_lesson_steps, custom_lesson_words: :word])
    |> Repo.one!()
  end

  @doc """
  Creates a custom lesson.

  ## Examples

      iex> create_custom_lesson(%{title: "Spring Vocabulary", creator_id: teacher_id})
      {:ok, %CustomLesson{}}

      iex> create_custom_lesson(%{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_custom_lesson(attrs \\ %{}) do
    %CustomLesson{}
    |> CustomLesson.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a new vocabulary custom lesson from a word set.

  The lesson title and description are copied from the word set, all words are
  added in their word-set order, and the lesson is created as a draft.

  Returns `{:error, :no_words}` if the word set has no words.
  Returns `{:error, :max_words_exceeded}` if the word set contains more words
  than a custom lesson allows.
  """
  def create_custom_lesson_from_word_set(user_id, word_set_id) do
    word_set =
      WordSet
      |> Repo.get!(word_set_id)
      |> Repo.preload(word_set_words: :word)

    word_ids =
      word_set.word_set_words
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.word_id)
      |> Enum.uniq()

    cond do
      word_ids == [] ->
        {:error, :no_words}

      length(word_ids) > CustomLesson.max_words() ->
        {:error, :max_words_exceeded}

      true ->
        lesson_attrs = %{
          title: word_set.name,
          description: word_set.description || "",
          lesson_type: "reading",
          lesson_subtype: "vocabulary",
          difficulty: 1,
          status: "draft",
          creator_id: user_id,
          word_count: 0
        }

        Repo.transaction(fn ->
          {:ok, lesson} = create_custom_lesson(lesson_attrs)

          now = DateTime.utc_now()

          lesson_words =
            Enum.with_index(word_ids, fn word_id, index ->
              %{
                custom_lesson_id: lesson.id,
                word_id: word_id,
                position: index,
                inserted_at: now,
                updated_at: now
              }
            end)

          {inserted_count, _} = Repo.insert_all(CustomLessonWord, lesson_words)

          lesson
          |> CustomLesson.update_word_count_changeset(inserted_count)
          |> Repo.update!()
        end)
    end
  end

  @doc """
  Updates a custom lesson.

  ## Examples

      iex> update_custom_lesson(custom_lesson, %{title: "Updated Title"})
      {:ok, %CustomLesson{}}

      iex> update_custom_lesson(custom_lesson, %{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_custom_lesson(%CustomLesson{} = custom_lesson, attrs) do
    custom_lesson
    |> CustomLesson.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a custom lesson.

  ## Examples

      iex> delete_custom_lesson(custom_lesson)
      {:ok, %CustomLesson{}}

      iex> delete_custom_lesson(custom_lesson)
      {:error, %Ecto.Changeset{}}

  """
  def delete_custom_lesson(%CustomLesson{} = custom_lesson) do
    Repo.delete(custom_lesson)
  end

  @doc """
  Publishes a custom lesson (changes status from draft to published).

  A lesson can only be marked as published if it has at least one active
  classroom publication.

  ## Examples

      iex> publish_custom_lesson(custom_lesson)
      {:ok, %CustomLesson{status: "published"}}

  """
  def publish_custom_lesson(%CustomLesson{} = custom_lesson) do
    if count_active_classroom_publications(custom_lesson.id) > 0 do
      custom_lesson
      |> CustomLesson.publish_changeset()
      |> Repo.update()
    else
      {:error, :not_published_to_classroom}
    end
  end

  @doc """
  Archives a custom lesson.

  ## Examples

      iex> archive_custom_lesson(custom_lesson)
      {:ok, %CustomLesson{status: "archived"}}

  """
  def archive_custom_lesson(%CustomLesson{} = custom_lesson) do
    custom_lesson
    |> CustomLesson.archive_changeset()
    |> Repo.update()
  end

  @doc """
  Unarchives a custom lesson.

  Restores to "published" status if the lesson has at least one active classroom
  publication; otherwise restores to "draft".

  ## Examples

      iex> unarchive_custom_lesson(custom_lesson)
      {:ok, %CustomLesson{status: "published"}}

  """
  def unarchive_custom_lesson(%CustomLesson{} = custom_lesson) do
    status =
      if count_active_classroom_publications(custom_lesson.id) > 0,
        do: "published",
        else: "draft"

    custom_lesson
    |> CustomLesson.unarchive_changeset(status)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking custom lesson changes.

  ## Examples

      iex> change_custom_lesson(custom_lesson)
      %Ecto.Changeset{data: %CustomLesson{}}

  """
  def change_custom_lesson(%CustomLesson{} = custom_lesson, attrs \\ %{}) do
    CustomLesson.changeset(custom_lesson, attrs)
  end

  # Custom Lesson Words

  @doc """
  Returns the list of words for a custom lesson.

  ## Examples

      iex> list_lesson_words(lesson_id)
      [%CustomLessonWord{word: %Word{}}, ...]

  """
  def list_lesson_words(lesson_id) do
    CustomLessonWord
    |> where([lw], lw.custom_lesson_id == ^lesson_id)
    |> order_by([lw], asc: lw.position)
    |> preload(word: [word_kanjis: :kanji])
    |> Repo.all()
  end

  @doc """
  Adds a word to a custom lesson.

  ## Examples

      iex> add_word_to_lesson(lesson_id, word_id, %{position: 0})
      {:ok, %CustomLessonWord{}}

  """
  def add_word_to_lesson(lesson_id, word_id, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:custom_lesson_id, lesson_id)
      |> Map.put(:word_id, word_id)

    current_count =
      CustomLessonWord
      |> where([lw], lw.custom_lesson_id == ^lesson_id)
      |> Repo.aggregate(:count, :id)

    if current_count >= CustomLesson.max_words() do
      {:error, :max_words_reached}
    else
      result =
        %CustomLessonWord{}
        |> CustomLessonWord.changeset(attrs)
        |> Repo.insert()

      # Update word count
      with {:ok, lesson_word} <- result do
        update_lesson_word_count(lesson_id)
        {:ok, lesson_word}
      end
    end
  end

  @doc """
  Removes a word from a custom lesson.

  ## Examples

      iex> remove_word_from_lesson(lesson_id, word_id)
      {:ok, %CustomLessonWord{}}

  """
  def remove_word_from_lesson(lesson_id, word_id) do
    lesson_word =
      CustomLessonWord
      |> where([lw], lw.custom_lesson_id == ^lesson_id and lw.word_id == ^word_id)
      |> Repo.one()

    case lesson_word do
      nil ->
        {:error, :not_found}

      lesson_word ->
        result = Repo.delete(lesson_word)

        with {:ok, _} <- result do
          update_lesson_word_count(lesson_id)
          # Reorder remaining words
          reorder_words_after_removal(lesson_id, lesson_word.position)
          result
        end
    end
  end

  @doc """
  Reorders words in a lesson based on the provided list of word IDs.

  ## Examples

      iex> reorder_lesson_words(lesson_id, [word_id_1, word_id_2, word_id_3])
      :ok

  """
  def reorder_lesson_words(lesson_id, word_ids_in_order) do
    word_ids_in_order
    |> Enum.with_index()
    |> Enum.each(fn {word_id, position} ->
      CustomLessonWord
      |> where([lw], lw.custom_lesson_id == ^lesson_id and lw.word_id == ^word_id)
      |> Repo.one()
      |> case do
        nil ->
          :ok

        lesson_word ->
          lesson_word
          |> CustomLessonWord.reorder_changeset(position)
          |> Repo.update()
      end
    end)

    :ok
  end

  @doc """
  Updates a custom lesson word's custom meaning and examples.

  ## Examples

      iex> update_custom_lesson_word(lesson_word, %{custom_meaning: "Custom definition", examples: ["Example 1"]})
      {:ok, %CustomLessonWord{}}

  """
  def update_custom_lesson_word(%CustomLessonWord{} = lesson_word, attrs) do
    lesson_word
    |> CustomLessonWord.update_changeset(attrs)
    |> Repo.update()
  end

  defp update_lesson_word_count(lesson_id) do
    count =
      CustomLessonWord
      |> where([lw], lw.custom_lesson_id == ^lesson_id)
      |> Repo.aggregate(:count, :id)

    lesson = get_custom_lesson!(lesson_id)

    lesson
    |> CustomLesson.update_word_count_changeset(count)
    |> Repo.update()
  end

  defp reorder_words_after_removal(lesson_id, removed_position) do
    CustomLessonWord
    |> where([lw], lw.custom_lesson_id == ^lesson_id and lw.position > ^removed_position)
    |> Repo.all()
    |> Enum.each(fn lesson_word ->
      lesson_word
      |> CustomLessonWord.reorder_changeset(lesson_word.position - 1)
      |> Repo.update()
    end)
  end

  # Publishing to Classrooms

  @doc """
  Publishes a custom lesson to a classroom.

  ## Examples

      iex> publish_lesson_to_classroom(lesson_id, classroom_id, teacher_id, %{due_date: ~D[2026-04-01]})
      {:ok, %ClassroomCustomLesson{}}

  """
  def publish_lesson_to_classroom(lesson_id, classroom_id, teacher_id, attrs \\ %{}) do
    # Verify teacher owns the classroom
    classroom = Medoru.Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      # Check if already published (any status)
      existing =
        ClassroomCustomLesson
        |> where(classroom_id: ^classroom_id, custom_lesson_id: ^lesson_id)
        |> Repo.one()

      result =
        case existing do
          nil ->
            # Get next order index for this classroom
            next_order_index = Medoru.Classrooms.get_next_lesson_order_index(classroom_id)

            # Create new published record
            attrs =
              attrs
              |> Map.put(:custom_lesson_id, lesson_id)
              |> Map.put(:classroom_id, classroom_id)
              |> Map.put(:published_by_id, teacher_id)
              |> Map.put(:order_index, next_order_index)

            %ClassroomCustomLesson{}
            |> ClassroomCustomLesson.publish_changeset(attrs)
            |> Repo.insert()

          %{status: "unpublished"} = classroom_lesson ->
            # Republish existing record - keep the original order_index
            classroom_lesson
            |> ClassroomCustomLesson.republish_changeset()
            |> Repo.update()

          _ ->
            {:error, :already_published}
        end

      with {:ok, classroom_lesson} <- result,
           %CustomLesson{} = lesson <- Repo.get(CustomLesson, lesson_id) do
        publish_custom_lesson(lesson)
        {:ok, classroom_lesson}
      else
        _ ->
          result
      end
    end
  end

  @doc """
  Unpublishes a lesson from a classroom.

  ## Examples

      iex> unpublish_lesson_from_classroom(classroom_lesson, teacher_id)
      {:ok, %ClassroomCustomLesson{}}

  """
  def unpublish_lesson_from_classroom(%ClassroomCustomLesson{} = classroom_lesson, teacher_id) do
    # Verify the teacher owns the classroom
    classroom = Medoru.Classrooms.get_classroom!(classroom_lesson.classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      result =
        classroom_lesson
        |> ClassroomCustomLesson.unpublish_changeset()
        |> Repo.update()

      with {:ok, _} <- result,
           %CustomLesson{} = lesson <- Repo.get(CustomLesson, classroom_lesson.custom_lesson_id),
           0 <- count_active_classroom_publications(classroom_lesson.custom_lesson_id) do
        lesson
        |> CustomLesson.changeset(%{status: "draft"})
        |> Repo.update()
      end

      result
    end
  end

  @doc """
  Republishes a previously unpublished lesson to a classroom.

  ## Examples

      iex> republish_lesson_to_classroom(classroom_lesson, teacher_id)
      {:ok, %ClassroomCustomLesson{}}

  """
  def republish_lesson_to_classroom(%ClassroomCustomLesson{} = classroom_lesson, teacher_id) do
    classroom = Medoru.Classrooms.get_classroom!(classroom_lesson.classroom_id)

    if classroom.teacher_id != teacher_id do
      {:error, :not_authorized}
    else
      result =
        classroom_lesson
        |> ClassroomCustomLesson.republish_changeset()
        |> Repo.update()

      with {:ok, _} <- result,
           %CustomLesson{} = lesson <- Repo.get(CustomLesson, classroom_lesson.custom_lesson_id) do
        publish_custom_lesson(lesson)
      end

      result
    end
  end

  @doc """
  Lists all custom lessons published to a classroom.

  ## Examples

      iex> list_classroom_custom_lessons(classroom_id)
      [%ClassroomCustomLesson{custom_lesson: %CustomLesson{}}, ...]

  """
  def list_classroom_custom_lessons(classroom_id, opts \\ []) do
    status = Keyword.get(opts, :status, "active")
    include_archived = Keyword.get(opts, :include_archived, false)
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    order_by = Keyword.get(opts, :order_by, :order_index)

    query =
      ClassroomCustomLesson
      |> where([ccl], ccl.classroom_id == ^classroom_id)
      |> then(fn q ->
        if status do
          where(q, [ccl], ccl.status == ^status)
        else
          q
        end
      end)
      |> join(:inner, [ccl], cl in assoc(ccl, :custom_lesson), as: :custom_lesson)
      |> then(fn q ->
        if include_archived do
          q
        else
          where(q, [custom_lesson: cl], cl.status != "archived")
        end
      end)
      |> then(fn q ->
        case order_by do
          :order_index -> order_by(q, [ccl], asc: ccl.order_index, asc: ccl.published_at)
          :published_at -> order_by(q, [ccl], desc: ccl.published_at)
          _ -> order_by(q, [ccl], asc: ccl.order_index)
        end
      end)
      |> preload(:custom_lesson)

    # Paginate
    paginated =
      query
      |> limit(^per_page)
      |> offset((^page - 1) * ^per_page)
      |> Repo.all()

    # Get total count
    total_count =
      query
      |> exclude(:order_by)
      |> exclude(:preload)
      |> exclude(:limit)
      |> exclude(:offset)
      |> select(count())
      |> Repo.one()

    %{
      lessons: paginated,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: ceil(total_count / per_page)
    }
  end

  @doc """
  Gets a classroom custom lesson by ID.

  ## Examples

      iex> get_classroom_custom_lesson!(id)
      %ClassroomCustomLesson{}

  """
  def get_classroom_custom_lesson!(id) do
    ClassroomCustomLesson
    |> where(id: ^id)
    |> preload([:custom_lesson, :classroom])
    |> Repo.one!()
  end

  @doc """
  Lists all classroom publications for a specific custom lesson.

  ## Examples

      iex> list_lesson_classroom_publications(lesson_id)
      [%ClassroomCustomLesson{}, ...]

      iex> list_lesson_classroom_publications(lesson_id, status: :active)
      [%ClassroomCustomLesson{}, ...]

  """
  def list_lesson_classroom_publications(lesson_id, opts \\ []) do
    status = Keyword.get(opts, :status)

    ClassroomCustomLesson
    |> where([ccl], ccl.custom_lesson_id == ^lesson_id)
    |> then(fn query ->
      if status do
        where(query, [ccl], ccl.status == ^status)
      else
        query
      end
    end)
    |> order_by([ccl], desc: ccl.published_at)
    |> preload(:classroom)
    |> Repo.all()
  end

  @doc """
  Returns the number of active classroom publications for a custom lesson.
  """
  def count_active_classroom_publications(lesson_id) do
    ClassroomCustomLesson
    |> where([ccl], ccl.custom_lesson_id == ^lesson_id and ccl.status == "active")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns all vocabulary custom lessons published to a classroom, preloaded with their words.

  Each lesson has `custom_lesson_words` ordered by position, and each word has
  `word_kanjis` preloaded (with their `kanji` and `kanji_reading`) so writing steps
  can be generated from real word contexts.
  """
  def list_classroom_vocabulary_lessons_with_words(classroom_id) do
    CustomLesson
    |> join(:inner, [cl], ccl in ClassroomCustomLesson, on: ccl.custom_lesson_id == cl.id)
    |> where([cl, ccl], ccl.classroom_id == ^classroom_id and ccl.status == "active")
    |> where([cl], cl.lesson_subtype == "vocabulary" and cl.status != "archived")
    |> order_by([cl], asc: cl.title)
    |> preload(custom_lesson_words: [word: [word_kanjis: [:kanji, :kanji_reading]]])
    |> Repo.all()
  end

  # ============================================================================
  # Localization Functions (Iteration 24B)
  # ============================================================================

  @doc """
  Gets the localized meaning for a word.

  Falls back to English if translation not available for the given locale.

  ## Examples

      iex> get_localized_meaning(word, "bg")
      "Япония"

      iex> get_localized_meaning(word, "en")
      "Japan"

  """
  def get_localized_meaning(%Word{} = word, locale) when locale in ["bg", "ja"] do
    word.translations
    |> Map.get(locale, %{})
    |> Map.get("meaning")
    |> case do
      nil -> word.meaning
      "" -> word.meaning
      meaning -> meaning
    end
  end

  def get_localized_meaning(%Word{} = word, _), do: word.meaning

  @doc """
  Gets the localized meanings for a kanji.

  Falls back to English if translation not available for the given locale.

  ## Examples

      iex> get_localized_kanji_meanings(kanji, "bg")
      ["слънце", "ден", "Япония"]

  """
  def get_localized_kanji_meanings(%Kanji{} = kanji, locale) when locale in ["bg", "ja"] do
    kanji.translations
    |> Map.get(locale, %{})
    |> Map.get("meanings")
    |> case do
      nil -> kanji.meanings
      [] -> kanji.meanings
      meanings -> meanings
    end
  end

  def get_localized_kanji_meanings(%Kanji{} = kanji, _), do: kanji.meanings

  @doc """
  Gets the localized title for a lesson.

  Falls back to English if translation not available.

  ## Examples

      iex> get_localized_lesson_title(lesson, "bg")
      "Числата 1-10"

  """
  def get_localized_lesson_title(%Lesson{} = lesson, locale) when locale in ["bg", "ja"] do
    lesson.translations
    |> Map.get(locale, %{})
    |> Map.get("title")
    |> case do
      nil -> lesson.title
      "" -> lesson.title
      title -> title
    end
  end

  def get_localized_lesson_title(%Lesson{} = lesson, _), do: lesson.title

  # Custom lessons don't have translations yet, just return the title
  def get_localized_lesson_title(%Medoru.Content.CustomLesson{} = lesson, _), do: lesson.title

  @doc """
  Gets the localized description for a lesson.

  Falls back to English if translation not available.

  ## Examples

      iex> get_localized_lesson_description(lesson, "bg")
      "Научете основните числа..."

  """
  def get_localized_lesson_description(%Lesson{} = lesson, locale) when locale in ["bg", "ja"] do
    lesson.translations
    |> Map.get(locale, %{})
    |> Map.get("description")
    |> case do
      nil -> lesson.description
      "" -> lesson.description
      description -> description
    end
  end

  def get_localized_lesson_description(%Lesson{} = lesson, _), do: lesson.description

  # Custom lessons don't have translations yet, just return the description
  def get_localized_lesson_description(%Medoru.Content.CustomLesson{} = lesson, _),
    do: lesson.description

  @doc """
  Checks if a word's meaning matches the query in the given locale.

  Used for answer validation in tests - compares against the user's
  current language preference.

  ## Examples

      iex> meaning_matches?(word, "Япония", "bg")
      true

      iex> meaning_matches?(word, "Japan", "en")
      true

  """
  def meaning_matches?(%Word{} = word, query, locale) when locale in ["bg", "ja"] do
    localized_meaning = get_localized_meaning(word, locale)

    # Normalize for comparison
    normalized_query = normalize_for_comparison(query)
    normalized_meaning = normalize_for_comparison(localized_meaning)

    # Check for exact match or containment
    normalized_meaning == normalized_query or
      String.contains?(normalized_meaning, normalized_query) or
      String.contains?(normalized_query, normalized_meaning)
  end

  def meaning_matches?(%Word{} = word, query, _locale) do
    # Default to English comparison
    normalized_query = normalize_for_comparison(query)
    normalized_meaning = normalize_for_comparison(word.meaning)

    normalized_meaning == normalized_query or
      String.contains?(normalized_meaning, normalized_query) or
      String.contains?(normalized_query, normalized_meaning)
  end

  defp normalize_for_comparison(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.trim()
    # Remove common punctuation
    |> String.replace(~r/[.,;:!?()\[\]]/, "")
  end

  defp normalize_for_comparison(_), do: ""

  @doc """
  Searches words using localized meaning for the given locale.

  When locale is "bg" or "ja", searches within translations JSONB column
  in addition to the English meaning field.

  ## Examples

      iex> search_words_localized("Япония", "bg", limit: 10)
      [%Word{}, ...]

  """
  def search_words_localized(query, locale, opts \\ [])

  def search_words_localized(query, locale, opts) when locale in ["bg", "ja"] do
    limit = Keyword.get(opts, :limit, 20)
    include_mature = Keyword.get(opts, :include_mature, true)

    if String.trim(query) == "" do
      []
    else
      search_term = "%#{query}%"

      query =
        Word
        |> where(
          [w],
          ilike(w.text, ^search_term) or
            ilike(w.reading, ^search_term) or
            ilike(w.meaning, ^search_term) or
            fragment("?->?->>? ILIKE ?", w.translations, ^locale, "meaning", ^search_term)
        )

      query = if include_mature, do: query, else: where(query, mature: false)

      query
      |> order_by([w], asc: w.sort_score)
      |> limit(^limit)
      |> Repo.all()
    end
  end

  def search_words_localized(query, _locale, opts) do
    # Fallback to regular search
    search_words(query, opts)
  end

  @doc """
  Searches kanji using localized meanings for the given locale.

  ## Examples

      iex> search_kanji_localized("слънце", "bg", limit: 10)
      [%Kanji{}, ...]

  """
  def search_kanji_localized(query, locale, opts \\ [])

  def search_kanji_localized(query, locale, opts) when locale in ["bg", "ja"] do
    limit = Keyword.get(opts, :limit, 10)

    if String.trim(query) == "" do
      []
    else
      # Search by character or in translations
      Kanji
      |> where(
        [k],
        ilike(k.character, ^query) or
          fragment("?->?->>? ILIKE ?", k.translations, ^locale, "meanings", ^"%#{query}%")
      )
      |> order_by([k], asc: k.jlpt_level, desc: k.frequency)
      |> limit(^limit)
      |> preload(:kanji_readings)
      |> Repo.all()
    end
  end

  def search_kanji_localized(query, _locale, opts) do
    search_kanji(query, opts)
  end

  # ============================================================================
  # Admin Stats Functions
  # ============================================================================

  @doc """
  Returns content statistics for admin dashboard.
  """
  def get_admin_stats do
    total_kanji = Repo.aggregate(Kanji, :count, :id)
    total_words = Repo.aggregate(Word, :count, :id)
    total_lessons = Repo.aggregate(Lesson, :count, :id)

    kanji_by_level =
      Kanji
      |> group_by([k], k.jlpt_level)
      |> select([k], {k.jlpt_level, count(k.id)})
      |> Repo.all()
      |> Enum.into(%{})

    words_by_difficulty =
      Word
      |> group_by([w], w.difficulty)
      |> select([w], {w.difficulty, count(w.id)})
      |> Repo.all()
      |> Enum.into(%{})

    lessons_by_difficulty =
      Lesson
      |> group_by([l], l.difficulty)
      |> select([l], {l.difficulty, count(l.id)})
      |> Repo.all()
      |> Enum.into(%{})

    %{
      total_kanji: total_kanji,
      total_words: total_words,
      total_lessons: total_lessons,
      kanji_by_level: kanji_by_level,
      words_by_difficulty: words_by_difficulty,
      lessons_by_difficulty: lessons_by_difficulty
    }
  end

  # ============================================================================
  # Grammar Forms Functions
  # ============================================================================

  alias Medoru.Content.GrammarForm

  @doc """
  Returns the list of grammar forms.

  ## Options
    * `:word_type` - Filter by word type ("verb", "adjective", "noun")
  """
  def list_grammar_forms(opts \\ []) do
    GrammarForm
    |> maybe_filter_by_word_type(opts[:word_type])
    |> order_by([gf], asc: gf.word_type, asc: gf.display_name)
    |> Repo.all()
  end

  defp maybe_filter_by_word_type(query, nil), do: query

  defp maybe_filter_by_word_type(query, word_type) do
    where(query, [gf], gf.word_type == ^word_type)
  end

  @doc """
  Gets a single grammar form.

  Raises `Ecto.NoResultsError` if the Grammar form does not exist.
  """
  def get_grammar_form!(id), do: Repo.get!(GrammarForm, id)

  @doc """
  Gets a single grammar form.

  Returns nil if the Grammar form does not exist.
  """
  def get_grammar_form(id), do: Repo.get(GrammarForm, id)

  @doc """
  Gets a grammar form by name and word type.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_grammar_form_by_name!(name, word_type) do
    GrammarForm
    |> where([gf], gf.name == ^name and gf.word_type == ^word_type)
    |> Repo.one!()
  end

  @doc """
  Gets a grammar form by name and word type.

  Returns nil if not found.
  """
  def get_grammar_form_by_name(name, word_type) do
    GrammarForm
    |> where([gf], gf.name == ^name and gf.word_type == ^word_type)
    |> Repo.one()
  end

  @doc """
  Creates a grammar form.
  """
  def create_grammar_form(attrs \\ %{}) do
    %GrammarForm{}
    |> GrammarForm.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a grammar form.
  """
  def update_grammar_form(%GrammarForm{} = grammar_form, attrs) do
    grammar_form
    |> GrammarForm.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a grammar form.
  """
  def delete_grammar_form(%GrammarForm{} = grammar_form) do
    Repo.delete(grammar_form)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking grammar form changes.
  """
  def change_grammar_form(%GrammarForm{} = grammar_form, attrs \\ %{}) do
    GrammarForm.changeset(grammar_form, attrs)
  end

  # ============================================================================
  # Grammar Definition Functions
  # ============================================================================

  alias Medoru.Content.GrammarDefinition

  @doc """
  Returns the list of grammar definitions with pagination and filtering.
  """
  def list_grammar_definitions(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 30)
    jlpt_level = Keyword.get(opts, :jlpt_level)
    search = Keyword.get(opts, :search)

    base_query = GrammarDefinition

    base_query =
      if jlpt_level && jlpt_level in 1..5 do
        where(base_query, jlpt_level: ^jlpt_level)
      else
        base_query
      end

    base_query =
      if search && search != "" do
        search_term = "%#{search}%"
        where(base_query, [g], ilike(g.title, ^search_term))
      else
        base_query
      end

    total_count = base_query |> select([g], count(g.id)) |> Repo.one()
    total_pages = max(1, ceil(total_count / per_page))
    offset = (page - 1) * per_page

    grammar_definitions =
      base_query
      |> order_by([g], asc: g.frequency, asc: g.jlpt_level, asc: g.title)
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    %{
      grammar_definitions: grammar_definitions,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Searches grammar definitions by title (case-insensitive).
  Returns a list of GrammarDefinition structs.
  """
  def search_grammar_definitions(search_term, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    search_query = "%#{search_term}%"

    GrammarDefinition
    |> where([g], ilike(g.title, ^search_query))
    |> order_by([g], asc: g.frequency, asc: g.jlpt_level, asc: g.title)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Looks up a grammar definition by title.

  Tries an exact case-insensitive match first, then falls back to a partial match.
  If multiple results are found, returns the one with the lowest frequency
  (most common), or the first result if frequencies are equal.

  Returns `nil` if no match is found.
  """
  def get_grammar_definition_by_title(title) do
    # Try exact case-insensitive match first
    exact_match =
      GrammarDefinition
      |> where([g], ilike(g.title, ^title))
      |> order_by([g], asc: g.frequency, asc: g.jlpt_level, asc: g.title)
      |> limit(1)
      |> Repo.one()

    if exact_match do
      exact_match
    else
      # Fall back to partial match
      search_query = "%#{title}%"

      GrammarDefinition
      |> where([g], ilike(g.title, ^search_query))
      |> order_by([g], asc: g.frequency, asc: g.jlpt_level, asc: g.title)
      |> limit(1)
      |> Repo.one()
    end
  end

  def get_grammar_definition!(id), do: Repo.get!(GrammarDefinition, id)

  def get_grammar_definition_by_slug(slug) do
    GrammarDefinition
    |> where(slug: ^slug)
    |> Repo.one()
  end

  def create_grammar_definition(attrs \\ %{}) do
    %GrammarDefinition{}
    |> GrammarDefinition.changeset(attrs)
    |> Repo.insert()
  end

  def update_grammar_definition(%GrammarDefinition{} = grammar_definition, attrs) do
    grammar_definition
    |> GrammarDefinition.changeset(attrs)
    |> Repo.update()
  end

  def delete_grammar_definition(%GrammarDefinition{} = grammar_definition) do
    Repo.delete(grammar_definition)
  end

  def change_grammar_definition(%GrammarDefinition{} = grammar_definition, attrs \\ %{}) do
    GrammarDefinition.changeset(grammar_definition, attrs)
  end

  # ============================================================================
  # Word Classes Functions
  # ============================================================================

  alias Medoru.Content.{WordClass, WordClassMembership}

  @doc """
  Returns the list of word classes.
  """
  def list_word_classes do
    WordClass
    |> order_by([wc], asc: wc.display_name)
    |> Repo.all()
  end

  @doc """
  Gets a single word class.

  Raises `Ecto.NoResultsError` if the Word class does not exist.
  """
  def get_word_class!(id), do: Repo.get!(WordClass, id)

  @doc """
  Gets a single word class.

  Returns nil if the Word class does not exist.
  """
  def get_word_class(id), do: Repo.get(WordClass, id)

  @doc """
  Gets a word class with its words preloaded.
  """
  def get_word_class_with_words!(id) do
    WordClass
    |> where([wc], wc.id == ^id)
    |> preload(:words)
    |> Repo.one!()
  end

  @doc """
  Creates a word class.
  """
  def create_word_class(attrs \\ %{}) do
    %WordClass{}
    |> WordClass.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a word class.
  """
  def update_word_class(%WordClass{} = word_class, attrs) do
    word_class
    |> WordClass.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a word class.
  """
  def delete_word_class(%WordClass{} = word_class) do
    Repo.delete(word_class)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking word class changes.
  """
  def change_word_class(%WordClass{} = word_class, attrs \\ %{}) do
    WordClass.changeset(word_class, attrs)
  end

  @doc """
  Adds a word to a word class.
  """
  def add_word_to_class(word_id, word_class_id) do
    %WordClassMembership{}
    |> WordClassMembership.changeset(%{word_id: word_id, word_class_id: word_class_id})
    |> Repo.insert()
  end

  @doc """
  Removes a word from a word class.
  """
  def remove_word_from_class(word_id, word_class_id) do
    WordClassMembership
    |> where([wcm], wcm.word_id == ^word_id and wcm.word_class_id == ^word_class_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      membership -> Repo.delete(membership)
    end
  end

  @doc """
  Lists words in a word class.
  """
  def list_words_in_class(word_class_id) do
    Word
    |> join(:inner, [w], wcm in WordClassMembership, on: wcm.word_id == w.id)
    |> where([w, wcm], wcm.word_class_id == ^word_class_id)
    |> order_by([w], asc: w.text)
    |> Repo.all()
  end

  @doc """
  Checks if a word is in a word class.
  """
  def word_in_class?(word_id, word_class_id) do
    WordClassMembership
    |> where([wcm], wcm.word_id == ^word_id and wcm.word_class_id == ^word_class_id)
    |> Repo.exists?()
  end

  @doc """
  Lists word classes for a word.
  """
  def list_word_classes_for_word(word_id) do
    WordClass
    |> join(:inner, [wc], wcm in WordClassMembership, on: wcm.word_class_id == wc.id)
    |> where([wc, wcm], wcm.word_id == ^word_id)
    |> order_by([wc], asc: wc.display_name)
    |> Repo.all()
  end

  # ============================================================================
  # Grammar Lesson Steps Functions
  # ============================================================================

  alias Medoru.Content.GrammarLessonStep

  @doc """
  Returns the list of grammar lesson steps for a custom lesson.
  """
  def list_grammar_lesson_steps(custom_lesson_id) do
    GrammarLessonStep
    |> where([gls], gls.custom_lesson_id == ^custom_lesson_id)
    |> order_by([gls], asc: gls.position)
    |> Repo.all()
  end

  @doc """
  Gets a single grammar lesson step.

  Raises `Ecto.NoResultsError` if the step does not exist.
  """
  def get_grammar_lesson_step!(id), do: Repo.get!(GrammarLessonStep, id)

  @doc """
  Creates a grammar lesson step.
  """
  def create_grammar_lesson_step(attrs \\ %{}) do
    %GrammarLessonStep{}
    |> GrammarLessonStep.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a grammar lesson step.
  """
  def update_grammar_lesson_step(%GrammarLessonStep{} = step, attrs) do
    step
    |> GrammarLessonStep.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a grammar lesson step.
  """
  def delete_grammar_lesson_step(%GrammarLessonStep{} = step) do
    Repo.delete(step)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking grammar lesson step changes.
  """
  def change_grammar_lesson_step(%GrammarLessonStep{} = step, attrs \\ %{}) do
    GrammarLessonStep.changeset(step, attrs)
  end

  @doc """
  Swaps the positions of two grammar lesson steps.
  """
  def swap_step_positions(%GrammarLessonStep{} = step1, %GrammarLessonStep{} = step2) do
    Repo.transaction(fn ->
      pos1 = step1.position
      pos2 = step2.position

      step1
      |> Ecto.Changeset.change(position: pos2)
      |> Repo.update!()

      step2
      |> Ecto.Changeset.change(position: pos1)
      |> Repo.update!()
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  @doc """
  Returns the list of classrooms that have published a given custom lesson.
  """
  def list_classroom_custom_lessons_for_lesson(custom_lesson_id) do
    ClassroomCustomLesson
    |> where([ccl], ccl.custom_lesson_id == ^custom_lesson_id)
    |> where([ccl], ccl.status == "active")
    |> Repo.all()
  end

  # ============================================================================
  # Word Conjugations Functions
  # ============================================================================

  @doc """
  Returns the list of word conjugations for a word.
  """
  def list_word_conjugations(word_id) do
    WordConjugation
    |> where([wc], wc.word_id == ^word_id)
    |> join(:inner, [wc], gf in assoc(wc, :grammar_form))
    |> order_by([wc, gf], asc: gf.word_type, asc: gf.display_name)
    |> preload(:grammar_form)
    |> Repo.all()
  end

  @doc """
  Gets a single word conjugation.

  Raises `Ecto.NoResultsError` if the conjugation does not exist.
  """
  def get_word_conjugation!(id), do: Repo.get!(WordConjugation, id)

  @doc """
  Creates a word conjugation.
  """
  def create_word_conjugation(attrs \\ %{}) do
    %WordConjugation{}
    |> WordConjugation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates multiple word conjugations in a batch.
  """
  def create_word_conjugations(conjugations) when is_list(conjugations) do
    Repo.transaction(fn ->
      Enum.map(conjugations, fn attrs ->
        case create_word_conjugation(attrs) do
          {:ok, conj} -> conj
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end)
  end

  @doc """
  Updates a word conjugation.
  """
  def update_word_conjugation(%WordConjugation{} = conjugation, attrs) do
    conjugation
    |> WordConjugation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a word conjugation.
  """
  def delete_word_conjugation(%WordConjugation{} = conjugation) do
    Repo.delete(conjugation)
  end

  @doc """
  Deletes all conjugations for a word.
  """
  def delete_word_conjugations(word_id) do
    WordConjugation
    |> where([wc], wc.word_id == ^word_id)
    |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking word conjugation changes.
  """
  def change_word_conjugation(%WordConjugation{} = conjugation, attrs \\ %{}) do
    WordConjugation.changeset(conjugation, attrs)
  end

  @doc """
  Finds a word conjugation by form text.
  """
  def find_conjugation_by_form(conjugated_form) do
    WordConjugation
    |> where([wc], wc.conjugated_form == ^conjugated_form)
    |> join(:inner, [wc], w in assoc(wc, :word))
    |> join(:inner, [wc], gf in assoc(wc, :grammar_form))
    |> select([wc, w, gf], %{
      word_id: w.id,
      word_text: w.text,
      word_type: w.word_type,
      grammar_form: gf.name,
      grammar_form_display: gf.display_name
    })
    |> Repo.all()
  end
end
