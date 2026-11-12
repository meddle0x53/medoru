defmodule Medoru.Tests.MeaningSegments do
  @moduledoc "Helpers for splitting and picking meaning segments of a localized meaning string."

  @doc """
  Splits a meaning string on "/" trimming each segment and dropping empties.
  """
  def split(meaning) when is_binary(meaning) do
    meaning
    |> String.split("/")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def split(_), do: []

  @doc "Returns a random segment count between 1 and 3."
  def random_count, do: :rand.uniform(3)

  @doc """
  Picks a random count of random distinct segments from a meaning string.

  Returns `{segments, indices}` where indices are sorted and index into `split(meaning)`.
  """
  def pick_random(meaning) do
    segments = split(meaning)
    count = random_count() |> min(length(segments))

    indices =
      segments
      |> Enum.with_index()
      |> Enum.take_random(count)
      |> Enum.map(&elem(&1, 1))
      |> Enum.sort()

    picked = pick_indices(meaning, indices)
    {picked, indices}
  end

  @doc "Returns the segments at the given indices, skipping out-of-range indices."
  def pick_indices(meaning, indices) when is_list(indices) do
    segments = split(meaning)
    total = length(segments)

    indices
    |> Enum.filter(&(is_integer(&1) and &1 >= 0 and &1 < total))
    |> Enum.map(&Enum.at(segments, &1))
  end

  @doc ~S(Joins segments with " / ".)
  def join(segments) when is_list(segments), do: Enum.join(segments, " / ")
end
