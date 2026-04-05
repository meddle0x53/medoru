defmodule Medoru.Learning.WordSets do
  @moduledoc """
  Context module for Word Sets - user-created collections of words.
  
  Provides CRUD operations, word management, and practice test integration.
  """

  import Ecto.Query
  alias Medoru.Repo
  alias Medoru.Learning.{WordSet, WordSetWord}
  alias Medoru.Content.Word
  alias Medoru.Tests

  @max_words WordSet.max_words()

  @doc """
  Returns a paginated list of word sets for a user.
  
  ## Options
    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 20)
    * `:search` - Filter by name (case-insensitive partial match)
    * `:sort_by` - Sort field: `:name`, `:inserted_at` (default: `:inserted_at`)
    * `:sort_order` - Sort order: `:asc`, `:desc` (default: `:desc`)
  """
  def list_user_word_sets(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    search = Keyword.get(opts, :search)
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    query =
      from(ws in WordSet,
        where: ws.user_id == ^user_id,
        preload: [:practice_test]
      )

    # Apply search filter
    query =
      if search && search != "" do
        search_term = "%#{search}%"
        from(ws in query, where: ilike(ws.name, ^search_term))
      else
        query
      end

    # Apply sorting
    query =
      case {sort_by, sort_order} do
        {:name, :asc} -> from(ws in query, order_by: [asc: ws.name])
        {:name, :desc} -> from(ws in query, order_by: [desc: ws.name])
        {:inserted_at, :asc} -> from(ws in query, order_by: [asc: ws.inserted_at])
        {:inserted_at, :desc} -> from(ws in query, order_by: [desc: ws.inserted_at])
        _ -> from(ws in query, order_by: [desc: ws.inserted_at])
      end

    # Get total count
    total_count = Repo.aggregate(query, :count, :id)

    # Get paginated results
    word_sets =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    total_pages = max(1, ceil(total_count / per_page))

    %{
      word_sets: word_sets,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Gets a single word set with preloaded words.
  
  Raises `Ecto.NoResultsError` if the word set does not exist.
  """
  def get_word_set!(id) do
    WordSet
    |> Repo.get!(id)
    |> Repo.preload(word_set_words: [word: [:word_kanjis]], practice_test: [test_steps: []])
  end

  @doc """
  Gets a word set with paginated words.
  """
  def get_word_set_with_words_paginated(id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 30)

    word_set =
      WordSet
      |> Repo.get!(id)
      |> Repo.preload(:practice_test)

    # Get paginated words
    words_query =
      from(w in Word,
        join: wsw in WordSetWord,
        on: wsw.word_id == w.id,
        where: wsw.word_set_id == ^id,
        order_by: [asc: wsw.position],
        preload: [:word_kanjis]
      )

    total_count = Repo.aggregate(words_query, :count, :id)

    words =
      words_query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    total_pages = max(1, ceil(total_count / per_page))

    {word_set, %{words: words, total_count: total_count, total_pages: total_pages}}
  end

  @doc """
  Creates a new word set.
  """
  def create_word_set(attrs) do
    %WordSet{}
    |> WordSet.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a word set.
  """
  def update_word_set(%WordSet{} = word_set, attrs) do
    word_set
    |> WordSet.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a word set and its associated practice test (hard delete).
  """
  def delete_word_set(%WordSet{} = word_set) do
    # Delete associated test first if exists
    if word_set.practice_test_id do
      case Tests.get_test(word_set.practice_test_id) do
        nil -> :ok
        test -> Tests.delete_test(test)
      end
    end

    # Delete word set (cascades to word_set_words)
    Repo.delete(word_set)
  end

  @doc """
  Adds a word to a word set.
  
  Returns `{:error, :max_words_reached}` if the set already has 100 words.
  """
  def add_word_to_set(%WordSet{} = word_set, word_id) do
    if word_set.word_count >= @max_words do
      {:error, :max_words_reached}
    else
      # Get next position
      max_position =
        from(wsw in WordSetWord, where: wsw.word_set_id == ^word_set.id, select: max(wsw.position))
        |> Repo.one() || 0

      attrs = %{
        word_set_id: word_set.id,
        word_id: word_id,
        position: max_position + 1
      }

      Repo.transaction(fn ->
        # Insert word
        {:ok, _} =
          %WordSetWord{}
          |> WordSetWord.changeset(attrs)
          |> Repo.insert()

        # Update word count
        {:ok, updated_set} =
          word_set
          |> WordSet.update_word_count_changeset(word_set.word_count + 1)
          |> Repo.update()

        updated_set
      end)
    end
  end

  @doc """
  Removes a word from a word set.
  """
  def remove_word_from_set(%WordSet{} = word_set, word_id) do
    Repo.transaction(fn ->
      # Delete the word association
      {deleted, _} =
        from(wsw in WordSetWord,
          where: wsw.word_set_id == ^word_set.id and wsw.word_id == ^word_id
        )
        |> Repo.delete_all()

      if deleted > 0 do
        # Update word count
        {:ok, updated_set} =
          word_set
          |> WordSet.update_word_count_changeset(word_set.word_count - 1)
          |> Repo.update()

        # Reorder remaining words to fill gap
        reorder_words_sequential(word_set.id)

        updated_set
      else
        word_set
      end
    end)
  end

  @doc """
  Reorders words in a word set by their IDs.
  
  Takes a list of word IDs in the desired order.
  """
  def reorder_words(word_set_id, word_ids) do
    Repo.transaction(fn ->
      word_ids
      |> Enum.with_index()
      |> Enum.each(fn {word_id, index} ->
        from(wsw in WordSetWord,
          where: wsw.word_set_id == ^word_set_id and wsw.word_id == ^word_id
        )
        |> Repo.update_all(set: [position: index])
      end)
    end)
  end

  @doc """
  Creates a practice test for a word set.
  
  ## Options
    * `:step_types` - List of step types to include (required)
    * `:max_steps_per_word` - Max questions per word (1-5, default: 3)
    * `:distractor_count` - Number of distractors per question (default: 3)
  """
  def create_practice_test(%WordSet{} = word_set, opts \\ []) do
    step_types = Keyword.fetch!(opts, :step_types)
    max_steps_per_word = Keyword.get(opts, :max_steps_per_word, 3)
    distractor_count = Keyword.get(opts, :distractor_count, 3)

    # Delete existing test if present
    if word_set.practice_test_id do
      case Tests.get_test(word_set.practice_test_id) do
        nil -> :ok
        old_test -> Tests.delete_test(old_test)
      end
    end

    # Load words for the set
    words =
      from(w in Word,
        join: wsw in WordSetWord,
        on: wsw.word_id == w.id,
        where: wsw.word_set_id == ^word_set.id,
        order_by: [asc: wsw.position],
        preload: [word_kanjis: :kanji]
      )
      |> Repo.all()

    # Generate test using WordSetTestGenerator
    Medoru.Tests.WordSetTestGenerator.generate_test(word_set, words,
      step_types: step_types,
      max_steps_per_word: max_steps_per_word,
      distractor_count: distractor_count
    )
  end

  @doc """
  Deletes the practice test associated with a word set (hard delete).
  """
  def delete_practice_test(%WordSet{} = word_set) do
    if word_set.practice_test_id do
      case Tests.get_test(word_set.practice_test_id) do
        nil ->
          {:ok, word_set}

        test ->
          Repo.transaction(fn ->
            {:ok, _} = Tests.delete_test(test)

            word_set
            |> WordSet.associate_test_changeset(nil)
            |> Repo.update!()
          end)
      end
    else
      {:ok, word_set}
    end
  end

  # Helper to reorder words sequentially (0, 1, 2, ...)
  defp reorder_words_sequential(word_set_id) do
    word_set_words =
      from(wsw in WordSetWord,
        where: wsw.word_set_id == ^word_set_id,
        order_by: [asc: wsw.position]
      )
      |> Repo.all()

    word_set_words
    |> Enum.with_index()
    |> Enum.each(fn {wsw, index} ->
      wsw
      |> WordSetWord.reorder_changeset(index)
      |> Repo.update!()
    end)
  end
end
