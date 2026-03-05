defmodule Medoru.Content do
  @moduledoc """
  The Content context handles kanji, readings, words, and lessons.
  """
  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Content.{Kanji, KanjiReading}

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
end
