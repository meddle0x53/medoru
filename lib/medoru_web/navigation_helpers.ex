defmodule MedoruWeb.NavigationHelpers do
  @moduledoc """
  Convenience helpers for generating human-readable resource paths.
  """

  use MedoruWeb, :verified_routes

  def word_path(word), do: ~p"/words/#{word.text}"
  def word_conjugations_path(word), do: ~p"/words/#{word.text}/conjugations"
  def kanji_path(kanji), do: ~p"/kanji/#{kanji.character}"

  def classroom_path(classroom), do: ~p"/classrooms/#{classroom.slug}"

  def custom_lesson_path(classroom, lesson),
    do: ~p"/classrooms/#{classroom.slug}/custom-lessons/#{lesson.slug}"

  def custom_lesson_test_path(classroom, lesson),
    do: ~p"/classrooms/#{classroom.slug}/custom-lessons/#{lesson.slug}/test"

  def custom_lesson_complete_path(classroom, lesson),
    do: ~p"/classrooms/#{classroom.slug}/custom-lessons/#{lesson.slug}/complete"

  def classroom_test_path(classroom, test),
    do: ~p"/classrooms/#{classroom.slug}/tests/#{test.slug}"

  def classroom_test_results_path(classroom, test),
    do: ~p"/classrooms/#{classroom.slug}/tests/#{test.slug}/results"

  def classroom_game_path(classroom, game),
    do: ~p"/classrooms/#{classroom.slug}/games/#{game.slug}"

  def classroom_game_rankings_path(classroom, game),
    do: ~p"/classrooms/#{classroom.slug}/games/#{game.slug}/rankings"
end
