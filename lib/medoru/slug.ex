defmodule Medoru.Slug do
  @moduledoc """
  Helpers for generating URL-friendly slugs.

  Slugs are lower-case, ASCII alphanumeric, hyphen-separated strings.
  Titles that contain no ASCII word characters fall back to
  `<prefix>-<short_hash>` so every record can still have a usable slug.

  Collisions are resolved with sequential numeric suffixes (`-1`, `-2`, …).
  """

  @max_length 100

  @doc """
  Generates a base slug from the given text.

  ## Examples

      iex> Medoru.Slug.generate("Hello World")
      "hello-world"

      iex> Medoru.Slug.generate("こんにちは", "lesson")
      "lesson-9f86d08"
  """
  def generate(text, fallback_prefix \\ "item") when is_binary(text) do
    base =
      text
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")
      |> String.slice(0, @max_length)

    if base == "" do
      hash =
        :crypto.hash(:sha256, text)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 8)

      "#{fallback_prefix}-#{hash}"
    else
      base
    end
  end

  @doc """
  Ensures a slug is unique within a pre-fetched list of conflicting slugs.

  The list should contain slugs that match the base slug or the base slug
  followed by a sequential numeric suffix (e.g. `["foo", "foo-1", "foo-3"]`).

  ## Examples

      iex> Medoru.Slug.ensure_unique("foo", ["foo", "foo-1"])
      "foo-2"

      iex> Medoru.Slug.ensure_unique("foo", ["bar"])
      "foo"
  """
  def ensure_unique(base_slug, existing_slugs) when is_list(existing_slugs) do
    if base_slug not in existing_slugs do
      base_slug
    else
      find_next_suffix(base_slug, existing_slugs, 1)
    end
  end

  defp find_next_suffix(base_slug, existing_slugs, n) do
    candidate = "#{base_slug}-#{n}"

    if candidate not in existing_slugs do
      candidate
    else
      find_next_suffix(base_slug, existing_slugs, n + 1)
    end
  end

  @doc """
  Filters a list of slugs to only those that are the base slug or a
  sequential numeric variant of it.
  """
  def matching_existing(slugs, base_slug) when is_list(slugs) do
    pattern = ~r/^#{Regex.escape(base_slug)}(-\d+)?$/
    Enum.filter(slugs, &Regex.match?(pattern, &1))
  end
end
