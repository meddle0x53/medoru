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
    Lesson,
    LessonWord,
    KanjiReadingExtractor
  }

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
  Gets a single kanji by character.

  Returns `nil` if the Kanji does not exist.

  ## Examples

      iex> get_kanji_by_character("日")
      %Kanji{}

      iex> get_kanji_by_character("invalid")
      nil

  """
  def get_kanji_by_character(character) do
    Repo.get_by(Kanji, character: character)
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
    %KanjiReading{}
    |> KanjiReading.changeset(attrs)
    |> Repo.insert()
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
    |> order_by([w], asc: w.usage_frequency)
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
    |> order_by([w], asc: w.usage_frequency)
    |> Repo.all()
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

  By default, words are sorted by usage_frequency (ascending) to show the most
  common words first. This is optimal for learning as you encounter the most
  useful vocabulary early.

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
    sort_by = Keyword.get(opts, :sort_by, :usage_frequency)
    sort_order = Keyword.get(opts, :sort_order, :asc)

    # Build base query
    query = Word

    # Apply difficulty filter
    query = if difficulty, do: where(query, difficulty: ^difficulty), else: query

    # Apply search filter (case-insensitive ILIKE for PostgreSQL)
    query =
      if search && search != "" do
        search_term = "%#{search}%"

        where(
          query,
          [w],
          ilike(w.text, ^search_term) or
            ilike(w.reading, ^search_term) or
            ilike(w.meaning, ^search_term)
        )
      else
        query
      end

    # Get total count for pagination
    total_count = query |> select([w], count(w.id)) |> Repo.one()
    total_pages = ceil(total_count / per_page)

    # Apply sorting
    query = order_by(query, [w], [{^sort_order, ^sort_by}])

    # Apply pagination
    offset = (page - 1) * per_page
    query = query |> limit(^per_page) |> offset(^offset)

    words = Repo.all(query)

    %{
      words: words,
      total_count: total_count,
      total_pages: total_pages,
      current_page: page,
      per_page: per_page
    }
  end

  @doc """
  Returns the list of words containing a specific kanji.

  ## Examples

      iex> list_words_by_kanji(kanji_id)
      [%Word{}, ...]

  """
  def list_words_by_kanji(kanji_id) do
    Word
    |> join(:inner, [w], wk in WordKanji, on: wk.word_id == w.id)
    |> where([w, wk], wk.kanji_id == ^kanji_id)
    |> order_by([w], asc: w.usage_frequency)
    |> Repo.all()
  end

  @doc """
  Returns words containing a specific kanji, grouped by reading, with pagination.

  Returns a map where keys are reading strings and values are lists of words.
  Each reading group is sorted by usage frequency.

  ## Examples

      iex> list_words_by_kanji_grouped_by_reading(kanji_id, page: 1, per_page: 20)
      %{"ニチ" => [%Word{}, ...], "ひ" => [%Word{}, ...]}

  """
  def list_words_by_kanji_grouped_by_reading(kanji_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    offset = (page - 1) * per_page

    # Get total count for pagination
    total_count =
      WordKanji
      |> where(kanji_id: ^kanji_id)
      |> select([wk], count(wk.id))
      |> Repo.one()

    # Get paginated word_kanjis with preloaded data
    word_kanjis =
      WordKanji
      |> where(kanji_id: ^kanji_id)
      |> order_by([wk], asc: wk.word_id)
      |> limit(^per_page)
      |> offset(^offset)
      |> preload([:word, :kanji_reading])
      |> Repo.all()

    # Group by reading (kanji_reading.reading or "kun"/"on" if no specific reading)
    grouped =
      word_kanjis
      |> Enum.group_by(fn wk ->
        case wk.kanji_reading do
          nil -> "misc"
          reading -> reading.reading
        end
      end)
      |> Enum.map(fn {reading, wks} ->
        # Sort words within each group by frequency
        sorted_words =
          wks
          |> Enum.map(& &1.word)
          |> Enum.sort_by(& &1.usage_frequency)

        {reading, sorted_words}
      end)
      |> Enum.into(%{})

    %{
      groups: grouped,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: ceil(total_count / per_page)
    }
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
  Returns an `%Ecto.Changeset{}` for tracking word kanji changes.

  ## Examples

      iex> change_word_kanji(word_kanji)
      %Ecto.Changeset{data: %WordKanji{}}

  """
  def change_word_kanji(%WordKanji{} = word_kanji, attrs \\ %{}) do
    WordKanji.changeset(word_kanji, attrs)
  end

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
end
