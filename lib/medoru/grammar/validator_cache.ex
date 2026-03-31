defmodule Medoru.Grammar.ValidatorCache do
  @moduledoc """
  ETS-based cache for grammar validation to reduce database queries.

  Stores:
  - Word dictionary forms (key: {text, word_type}) -> word_id
  - Conjugated forms (key: {form, word_type, field}) -> {word_id, grammar_form_name}

  Uses ETS with read_concurrency for fast concurrent reads.
  """

  use GenServer

  alias Medoru.Repo
  alias Medoru.Content.{Word, WordConjugation, GrammarForm}

  import Ecto.Query

  @table :grammar_validator_cache
  @cache_ttl :timer.minutes(10)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Looks up a word by its dictionary form (text + word_type).
  Returns word_id or nil.
  """
  def lookup_dictionary_form(text, word_type) do
    ensure_table_exists()

    case :ets.lookup(@table, {:word, text, word_type}) do
      [{_, word_id}] -> word_id
      [] -> nil
    end
  end

  @doc """
  Looks up a conjugated form by text, word_type, and grammar form name.
  Checks both conjugated_form and reading fields.
  Returns {word_id, form_name} or nil.
  """
  def lookup_conjugated_form(text, word_type, allowed_forms, field) do
    ensure_table_exists()

    # Build a list of possible form keys to check
    keys =
      if allowed_forms == [] do
        # Check all forms
        forms = get_grammar_forms_for_type(word_type)
        Enum.map(forms, &{:conjugation, text, word_type, &1, field})
      else
        Enum.map(allowed_forms, &{:conjugation, text, word_type, &1, field})
      end

    # Check cache for any match
    Enum.find_value(keys, fn key ->
      case :ets.lookup(@table, key) do
        [{_, {word_id, form_name}}] -> {word_id, form_name}
        [] -> nil
      end
    end)
  end

  @doc """
  Warms the cache by loading all words and conjugations for a word type.
  Call this before validation to ensure cache is populated.
  """
  def warm_cache(word_type) do
    GenServer.call(__MODULE__, {:warm_cache, word_type}, 30_000)
  end

  @doc """
  Clears the entire cache.
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @doc """
  Returns cache statistics.
  """
  def stats do
    ensure_table_exists()
    info = :ets.info(@table)

    %{
      size: info[:size],
      memory: info[:memory]
    }
  end

  # Ensures the ETS table exists, creating it if necessary
  # This handles cases where the GenServer hasn't started yet
  defp ensure_table_exists do
    case :ets.whereis(@table) do
      :undefined ->
        # Table doesn't exist yet, create it as a public table
        # This is safe because ETS tables are process-independent
        :ets.new(@table, [
          :set,
          :public,
          :named_table,
          read_concurrency: true
        ])

        :ok

      _ ->
        :ok
    end
  end

  # Server callbacks

  @impl true
  def init(_) do
    # Create a public table so any process can write to it
    # This is necessary because get_grammar_forms_for_type/1 may be called
    # from any process and needs to insert cache entries
    table =
      :ets.new(@table, [
        :set,
        :public,
        :named_table,
        read_concurrency: true
      ])

    # Schedule periodic cache clearing to prevent memory bloat
    schedule_cache_clear()

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:warm_cache, word_type}, _from, state) do
    count = load_words_for_type(word_type)
    conj_count = load_conjugations_for_type(word_type)

    {:reply, %{words: count, conjugations: conj_count}, state}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:clear_cache, state) do
    :ets.delete_all_objects(@table)
    schedule_cache_clear()
    {:noreply, state}
  end

  defp schedule_cache_clear do
    Process.send_after(self(), :clear_cache, @cache_ttl)
  end

  # Private functions

  defp load_words_for_type(word_type) do
    words =
      Word
      |> where([w], w.word_type == ^word_type)
      |> select([w], {w.text, w.id})
      |> Repo.all()

    entries =
      Enum.map(words, fn {text, id} ->
        {{:word, text, word_type}, id}
      end)

    :ets.insert(@table, entries)
    length(entries)
  end

  defp load_conjugations_for_type(word_type) do
    conjugations =
      WordConjugation
      |> join(:inner, [wc], w in assoc(wc, :word))
      |> join(:inner, [wc], gf in assoc(wc, :grammar_form))
      |> where([wc, w, _gf], w.word_type == ^word_type)
      |> select([wc, w, gf], {
        wc.conjugated_form,
        wc.reading,
        wc.alternative_forms,
        w.id,
        gf.name
      })
      |> Repo.all()

    entries =
      Enum.flat_map(conjugations, fn {conj_form, reading, alt_forms, word_id, form_name} ->
        base_entries = [
          {{:conjugation, conj_form, word_type, form_name, :conjugated_form},
           {word_id, form_name}},
          {{:conjugation, reading, word_type, form_name, :reading}, {word_id, form_name}}
        ]

        # Add entries for alternative forms
        alt_entries =
          Enum.map(alt_forms || [], fn alt_form ->
            {{:conjugation, alt_form, word_type, form_name, :conjugated_form},
             {word_id, form_name}}
          end)

        base_entries ++ alt_entries
      end)

    # Filter out entries with nil keys (some conjugations might not have readings)
    entries = Enum.reject(entries, fn {{_, text, _, _, _}, _} -> is_nil(text) end)

    :ets.insert(@table, entries)
    div(length(entries), 2)
  end

  defp get_grammar_forms_for_type(word_type) do
    ensure_table_exists()
    # This is cached separately since it rarely changes
    case :ets.lookup(@table, {:grammar_forms, word_type}) do
      [{_, forms}] ->
        forms

      [] ->
        forms =
          GrammarForm
          |> where([gf], gf.word_type == ^word_type)
          |> select([gf], gf.name)
          |> Repo.all()

        :ets.insert(@table, {{:grammar_forms, word_type}, forms})
        forms
    end
  end
end
