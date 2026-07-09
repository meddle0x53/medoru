defmodule MedoruWeb.NavigationHelpers do
  @moduledoc """
  Convenience helpers for generating human-readable resource paths.
  """

  use MedoruWeb, :verified_routes

  def word_path(word), do: ~p"/words/#{word.text}"
  def word_conjugations_path(word), do: ~p"/words/#{word.text}/conjugations"
  def kanji_path(kanji), do: ~p"/kanji/#{kanji.character}"
end
