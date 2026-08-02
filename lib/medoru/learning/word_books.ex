defmodule Medoru.Learning.WordBooks do
  @moduledoc """
  Context module for Word Books - user-created vocabulary card collections.

  Provides CRUD operations, word management, and card presentation defaults.
  """

  import Ecto.Query
  alias Medoru.Repo
  alias Medoru.Accounts.{User, UserProfile}
  alias Medoru.Learning.{WordBook, WordBookWord, WordSet}
  alias Medoru.Content.Word

  @max_words WordBook.max_words()

  @background_options [
    {"plain", "Plain"},
    {"grid", "Grid"},
    {"dots", "Dots"},
    {"waves", "Waves"},
    {"sakura", "Sakura"},
    {"seigaiha", "Seigaiha"},
    {"asanoha", "Asanoha"},
    {"stripes", "Stripes"},
    {"gradient_dawn", "Gradient Dawn"},
    {"gradient_dusk", "Gradient Dusk"}
  ]

  @cover_options [
    {"sakura", "Sakura"},
    {"fuji", "Fuji"},
    {"torii", "Torii"},
    {"waves", "Waves"},
    {"lanterns", "Lanterns"},
    {"cat", "Cat"},
    {"crane", "Crane"},
    {"bamboo", "Bamboo"},
    {"koi", "Koi"},
    {"shoji", "Shoji"}
  ]

  @doc """
  Returns a paginated list of word books for a user.

  ## Options
    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 20)
    * `:search` - Filter by title or description (case-insensitive partial match)
    * `:sort_by` - Sort field: `:title`, `:inserted_at` (default: `:inserted_at`)
    * `:sort_order` - Sort order: `:asc`, `:desc` (default: `:desc`)
  """
  def list_user_word_books(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    search = Keyword.get(opts, :search)
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    query = from(wb in WordBook, where: wb.user_id == ^user_id)

    # Apply search filter
    query =
      if search && search != "" do
        search_term = "%#{search}%"

        from(wb in query,
          where: ilike(wb.title, ^search_term) or ilike(wb.description, ^search_term)
        )
      else
        query
      end

    # Apply sorting
    query =
      case {sort_by, sort_order} do
        {:title, :asc} -> from(wb in query, order_by: [asc: wb.title])
        {:title, :desc} -> from(wb in query, order_by: [desc: wb.title])
        {:inserted_at, :asc} -> from(wb in query, order_by: [asc: wb.inserted_at])
        {:inserted_at, :desc} -> from(wb in query, order_by: [desc: wb.inserted_at])
        _ -> from(wb in query, order_by: [desc: wb.inserted_at])
      end

    # Get total count
    total_count = Repo.aggregate(query, :count, :id)

    # Get paginated results
    word_books =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    total_pages = max(1, ceil(total_count / per_page))

    %{
      word_books: word_books,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Gets a single word book with preloaded words.

  Raises `Ecto.NoResultsError` if the word book does not exist.
  """
  def get_word_book!(id) do
    WordBook
    |> Repo.get!(id)
    |> Repo.preload(word_book_words: [word: [:word_kanjis]])
  end

  @doc """
  Gets a word book owned by the given user, with preloaded words.

  Returns `nil` if the word book does not exist or belongs to another user.
  """
  def get_user_word_book(user_id, book_id) do
    WordBook
    |> where([wb], wb.id == ^book_id and wb.user_id == ^user_id)
    |> preload(word_book_words: [word: [:word_kanjis]])
    |> Repo.one()
  end

  @doc """
  Gets a word book with paginated words.
  """
  def get_word_book_with_words_paginated(id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 30)
    word_type = Keyword.get(opts, :word_type)

    word_book = Repo.get!(WordBook, id)

    # Get paginated words with optional word_type filter
    words_query =
      from(w in Word,
        join: wbw in WordBookWord,
        on: wbw.word_id == w.id,
        where: wbw.word_book_id == ^id,
        order_by: [asc: wbw.position],
        preload: [:word_kanjis]
      )

    # Apply word_type filter if specified
    words_query =
      if word_type do
        from(w in words_query, where: w.word_type == ^word_type)
      else
        words_query
      end

    total_count = Repo.aggregate(words_query, :count, :id)

    words =
      words_query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    total_pages = max(1, ceil(total_count / per_page))

    {word_book, %{words: words, total_count: total_count, total_pages: total_pages}}
  end

  @doc """
  Returns the IDs of word books owned by the given user that contain the given word.
  """
  def list_book_ids_for_word(user_id, word_id) do
    WordBookWord
    |> join(:inner, [wbw], wb in assoc(wbw, :word_book))
    |> where([wbw, wb], wbw.word_id == ^word_id and wb.user_id == ^user_id)
    |> select([wbw, _wb], wbw.word_book_id)
    |> Repo.all()
  end

  @doc """
  Creates a new word book.
  """
  def create_word_book(attrs) do
    %WordBook{}
    |> WordBook.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a word book.
  """
  def update_word_book(%WordBook{} = word_book, attrs) do
    word_book
    |> WordBook.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a word book (cascades to word_book_words).
  """
  def delete_word_book(%WordBook{} = word_book) do
    Repo.delete(word_book)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking word book changes.
  """
  def change_word_book(%WordBook{} = word_book, attrs \\ %{}) do
    WordBook.changeset(word_book, attrs)
  end

  @doc """
  Adds a word to a word book.

  Returns `{:error, :max_words_reached}` if the book already has 100 words.
  """
  def add_word_to_book(%WordBook{} = word_book, word_id) do
    if word_book.word_count >= @max_words do
      {:error, :max_words_reached}
    else
      # Get next position
      max_position =
        from(wbw in WordBookWord,
          where: wbw.word_book_id == ^word_book.id,
          select: max(wbw.position)
        )
        |> Repo.one() || 0

      attrs = %{
        word_book_id: word_book.id,
        word_id: word_id,
        position: max_position + 1
      }

      Repo.transaction(fn ->
        # Insert word
        {:ok, _} =
          %WordBookWord{}
          |> WordBookWord.changeset(attrs)
          |> Repo.insert()

        # Update word count
        {:ok, updated_book} =
          word_book
          |> WordBook.update_word_count_changeset(word_book.word_count + 1)
          |> Repo.update()

        updated_book
      end)
    end
  end

  @doc """
  Removes a word from a word book.
  """
  def remove_word_from_book(%WordBook{} = word_book, word_id) do
    Repo.transaction(fn ->
      # Delete the word association
      {deleted, _} =
        from(wbw in WordBookWord,
          where: wbw.word_book_id == ^word_book.id and wbw.word_id == ^word_id
        )
        |> Repo.delete_all()

      if deleted > 0 do
        # Update word count
        {:ok, updated_book} =
          word_book
          |> WordBook.update_word_count_changeset(word_book.word_count - 1)
          |> Repo.update()

        # Reorder remaining words to fill gap
        reorder_words_sequential(word_book.id)

        updated_book
      else
        word_book
      end
    end)
  end

  @doc """
  Reorders words in a word book by their IDs.

  Takes a list of word IDs in the desired order.
  """
  def reorder_words(%WordBook{} = word_book, word_ids) do
    Repo.transaction(fn ->
      word_ids
      |> Enum.with_index()
      |> Enum.each(fn {word_id, index} ->
        from(wbw in WordBookWord,
          where: wbw.word_book_id == ^word_book.id and wbw.word_id == ^word_id
        )
        |> Repo.update_all(set: [position: index])
      end)
    end)
  end

  @doc """
  Creates a new word book from a word set.

  The book title and description are copied from the word set, and all words
  are added in their word-set order. Duplicate words are skipped (only unique
  word_ids are added).

  Returns `{:error, :no_words}` if the word set has no words.
  Returns `{:error, :max_words_exceeded}` if the word set contains more words
  than a word book allows.
  """
  def create_word_book_from_word_set(user_id, word_set_id) do
    word_set =
      WordSet
      |> Repo.get!(word_set_id)
      |> Repo.preload(:word_set_words)

    word_ids =
      word_set.word_set_words
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.word_id)
      |> Enum.uniq()

    cond do
      word_ids == [] ->
        {:error, :no_words}

      length(word_ids) > @max_words ->
        {:error, :max_words_exceeded}

      true ->
        book_attrs = %{
          title: word_set.name,
          description: word_set.description || "",
          user_id: user_id,
          word_count: 0
        }

        Repo.transaction(fn ->
          {:ok, word_book} = create_word_book(book_attrs)

          now = DateTime.utc_now()

          word_book_words =
            Enum.with_index(word_ids, fn word_id, index ->
              %{
                word_book_id: word_book.id,
                word_id: word_id,
                position: index,
                inserted_at: now,
                updated_at: now
              }
            end)

          {inserted_count, _} = Repo.insert_all(WordBookWord, word_book_words)

          word_book
          |> WordBook.update_word_count_changeset(inserted_count)
          |> Repo.update!()
        end)
    end
  end

  @doc """
  Splits a "/" separated example-sentences string into a list of examples.

  Returns an empty list for `nil` or blank input.
  """
  def split_examples(nil), do: []

  def split_examples(text) when is_binary(text) do
    text
    |> String.split("/")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Builds the default front/back card configuration for a user.

  Meaning and example locales are pre-checked from the user's profile
  (`show_english_meanings`, `show_bulgarian_meanings`, `show_japanese_meanings`).
  Users without a profile default to English only.
  """
  def default_side_config(%User{} = user) do
    locales = meaning_locales(user)

    %{
      front: %{
        "show_reading" => true,
        "meanings" => locales,
        "examples" => locales
      },
      back: %{
        "show_reading" => true,
        "meanings" => locales,
        "example_count" => 1
      }
    }
  end

  @doc """
  Returns the preset card background options as `{key, label, path}` tuples.
  """
  def background_options do
    Enum.map(@background_options, fn {key, label} ->
      {key, label, "/images/word_book/backgrounds/#{key}.svg"}
    end)
  end

  @doc """
  Returns the preset cover image options as `{key, label, path}` tuples.
  """
  def cover_options do
    Enum.map(@cover_options, fn {key, label} ->
      {key, label, "/images/word_book/covers/#{key}.svg"}
    end)
  end

  @doc """
  Returns the cover images usable as card backgrounds, as
  `{prefixed_key, label, path}` tuples. Keys are prefixed with
  `"cover:"` because some cover keys collide with background keys.
  """
  def cover_background_options do
    Enum.map(cover_options(), fn {key, label, path} -> {"cover:#{key}", label, path} end)
  end

  @doc """
  Resolves a stored card background key (plain background key or a
  `"cover:"`-prefixed cover key) to its static path.
  """
  def background_path(nil), do: nil
  def background_path(""), do: nil

  def background_path("cover:" <> key) do
    Enum.find_value(cover_options(), fn {k, _label, path} -> if k == key, do: path end)
  end

  def background_path(key) do
    Enum.find_value(background_options(), fn {k, _label, path} -> if k == key, do: path end)
  end

  # Locales enabled in the user's profile; defaults to English when the
  # profile is missing or no locale flags are enabled.
  defp meaning_locales(%User{} = user) do
    case get_profile(user) do
      nil ->
        ["en"]

      profile ->
        locales =
          [
            {"en", profile.show_english_meanings},
            {"bg", profile.show_bulgarian_meanings},
            {"ja", profile.show_japanese_meanings}
          ]
          |> Enum.filter(fn {_locale, enabled} -> enabled end)
          |> Enum.map(fn {locale, _enabled} -> locale end)

        case locales do
          [] -> ["en"]
          locales -> locales
        end
    end
  end

  # Handles loaded, unloaded, and nil profile associations.
  defp get_profile(%User{profile: %UserProfile{} = profile}), do: profile

  defp get_profile(%User{profile: %Ecto.Association.NotLoaded{}} = user) do
    case Repo.preload(user, :profile) do
      %User{profile: %UserProfile{} = profile} -> profile
      _ -> nil
    end
  end

  defp get_profile(%User{}), do: nil

  # Helper to reorder words sequentially (0, 1, 2, ...)
  defp reorder_words_sequential(word_book_id) do
    word_book_words =
      from(wbw in WordBookWord,
        where: wbw.word_book_id == ^word_book_id,
        order_by: [asc: wbw.position]
      )
      |> Repo.all()

    word_book_words
    |> Enum.with_index()
    |> Enum.each(fn {wbw, index} ->
      wbw
      |> WordBookWord.reorder_changeset(index)
      |> Repo.update!()
    end)
  end
end
