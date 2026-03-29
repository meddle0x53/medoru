defmodule Medoru.Grammar.FormDetector do
  @moduledoc """
  Detects Japanese word forms (conjugations) using database lookups.

  Instead of pattern matching on suffixes, we look up conjugated forms
  from the word_conjugations table. This is more accurate and handles
  irregular verbs properly.
  """

  import Ecto.Query
  alias Medoru.Repo
  alias Medoru.Content.{WordConjugation, GrammarForm}

  @doc """
  Detects the form of a word by looking up its conjugations in the database.

  Returns a list of possible form names (since one conjugated form might
  match multiple grammar forms, e.g., potential and passive can be the same).

  ## Examples

      iex> detect_form("食べて")
      ["te-form"]

      iex> detect_form("食べない")
      ["nai-form"]
  """
  def detect_form(text) when is_binary(text) do
    WordConjugation
    |> where([wc], wc.conjugated_form == ^text)
    |> join(:inner, [wc], gf in assoc(wc, :grammar_form))
    |> select([wc, gf], gf.name)
    |> Repo.all()
  end

  def detect_form(_), do: []

  @doc """
  Gets the dictionary form (base form) of a conjugated word.

  ## Examples

      iex> get_dictionary_form("食べて")
      %{text: "食べる", word_type: "verb"}

      iex> get_dictionary_form("大きく")
      %{text: "大きい", word_type: "adjective"}
  """
  def get_dictionary_form(conjugated_text) when is_binary(conjugated_text) do
    WordConjugation
    |> where([wc], wc.conjugated_form == ^conjugated_text)
    |> join(:inner, [wc], w in assoc(wc, :word))
    |> select([wc, w], %{text: w.text, word_type: w.word_type, word_id: w.id})
    |> limit(1)
    |> Repo.one()
  end

  def get_dictionary_form(_), do: nil

  @doc """
  Checks if a word text matches a specific grammar form.

  ## Examples

      iex> matches_form?("食べて", "te-form")
      true

      iex> matches_form?("食べて", "nai-form")
      false
  """
  def matches_form?(text, form_name) when is_binary(text) and is_binary(form_name) do
    form_name in detect_form(text)
  end

  def matches_form?(_, _), do: false

  @doc """
  Checks if a word text matches any of the given grammar forms.

  ## Examples

      iex> matches_any_form?("食べない", ["nai-form", "nakatta-form"])
      true
  """
  def matches_any_form?(text, form_names) when is_list(form_names) do
    detected_forms = detect_form(text)
    Enum.any?(form_names, &(&1 in detected_forms))
  end

  @doc """
  Gets all conjugated forms for a word.

  ## Examples

      iex> list_conjugations("食べる")
      [
        %{form: "te-form", text: "食べて"},
        %{form: "nai-form", text: "食べない"},
        ...
      ]
  """
  def list_conjugations(word_text) when is_binary(word_text) do
    WordConjugation
    |> join(:inner, [wc], w in assoc(wc, :word))
    |> join(:inner, [wc], gf in assoc(wc, :grammar_form))
    |> where([wc, w], w.text == ^word_text)
    |> select([wc, w, gf], %{
      form: gf.name,
      form_display: gf.display_name,
      text: wc.conjugated_form,
      reading: wc.reading
    })
    |> Repo.all()
  end

  def list_conjugations(_), do: []

  @doc """
  Finds words that match a given conjugated form.

  Returns a list of tuples with the dictionary form and grammar form.

  ## Examples

      iex> find_matching_words("たべて")
      [{"食べる", "te-form"}]
  """
  def find_matching_words(conjugated_text) when is_binary(conjugated_text) do
    WordConjugation
    |> where([wc], wc.conjugated_form == ^conjugated_text)
    |> join(:inner, [wc], w in assoc(wc, :word))
    |> join(:inner, [wc], gf in assoc(wc, :grammar_form))
    |> select([wc, w, gf], {w.text, gf.name, gf.display_name})
    |> Repo.all()
  end

  def find_matching_words(_), do: []

  @doc """
  Gets all available forms for a word type from the database.
  """
  def available_forms(word_type) do
    GrammarForm
    |> where([gf], gf.word_type == ^word_type)
    |> select([gf], gf.name)
    |> Repo.all()
  end

  @doc """
  Pre-loads all conjugations for efficient lookup.

  Returns a map of conjugated_form => [%{word_id, form_name, ...}]
  """
  def preload_conjugations do
    WordConjugation
    |> join(:inner, [wc], gf in assoc(wc, :grammar_form))
    |> select([wc, gf], {wc.conjugated_form, wc.word_id, gf.name})
    |> Repo.all()
    |> Enum.group_by(
      fn {form, _, _} -> form end,
      fn {_, word_id, form_name} -> %{word_id: word_id, form: form_name} end
    )
  end
end
