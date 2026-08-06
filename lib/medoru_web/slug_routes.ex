defmodule MedoruWeb.SlugRoutes do
  @moduledoc """
  Helpers for LiveViews whose routes accept either a UUID or a slug.

  These functions mirror the existing `get_*!/1` context functions but fall back
  to slug-based lookups when the parameter is not a valid UUID.
  """

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Games
  alias Medoru.Tests

  @doc """
  Loads a classroom by ID or slug.
  """
  def load_classroom!(id_or_slug) do
    if uuid?(id_or_slug) do
      Classrooms.get_classroom!(id_or_slug)
    else
      Classrooms.get_classroom_by_slug!(id_or_slug)
    end
  end

  @doc """
  Loads a custom lesson by ID or slug.
  """
  def load_custom_lesson!(id_or_slug) do
    if uuid?(id_or_slug) do
      Content.get_custom_lesson!(id_or_slug)
    else
      Content.get_custom_lesson_by_slug!(id_or_slug)
    end
  end

  @doc """
  Loads a test by ID or slug.
  """
  def load_test!(id_or_slug) do
    if uuid?(id_or_slug) do
      Tests.get_test!(id_or_slug)
    else
      Tests.get_test_by_slug!(id_or_slug)
    end
  end

  @doc """
  Loads a classroom and a game by their respective IDs or slugs.

  Returns `{classroom, game}`. The caller is responsible for verifying that the
  game belongs to the classroom if needed.
  """
  def load_classroom_and_game!(classroom_id_or_slug, game_id_or_slug) do
    classroom = load_classroom!(classroom_id_or_slug)

    game =
      if uuid?(game_id_or_slug) do
        Games.get_game!(game_id_or_slug)
      else
        Games.get_game_by_slug!(classroom.id, game_id_or_slug)
      end

    {classroom, game}
  end

  # NOTE: `Ecto.UUID.cast/1` also accepts any raw 16-byte binary as an
  # already-dumped UUID, so a 16-character slug like "iv-grammar-notes" would
  # be misclassified as a UUID. Only accept canonical hex formats here.
  @uuid_format ~r/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/

  defp uuid?(value) when is_binary(value) do
    Regex.match?(@uuid_format, value) && Ecto.UUID.cast(value) != :error
  end

  defp uuid?(_), do: false
end
