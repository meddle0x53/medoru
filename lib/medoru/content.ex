defmodule Medoru.Content do
  @moduledoc """
  The Content context handles kanji, readings, words, and lessons.
  """
  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Content.{Kanji, KanjiReading, Word, WordKanji}

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
end
