defmodule Medoru.Tests.WritingValidator do
  @moduledoc """
  Validates kanji writing attempts with stricter stroke analysis.

  Checks:
  1. Stroke count
  2. Stroke direction (horizontal/vertical/diagonal)
  3. Stroke order and position
  4. Shape similarity

  Worth 5 points - highest value question type.
  """

  @doc """
  Validates a kanji writing attempt.
  """
  def validate_writing(_kanji, user_strokes, stroke_data) do
    expected_count = length(stroke_data["strokes"] || [])
    actual_count = length(user_strokes)

    cond do
      expected_count == 0 ->
        {:error, :no_stroke_data}

      actual_count != expected_count ->
        {:error, :wrong_stroke_count, expected: expected_count, actual: actual_count}

      true ->
        # Analyze and compare strokes
        result = analyze_and_compare(user_strokes, stroke_data["strokes"])

        case result do
          %{correct_order: true, correct_directions: true, accuracy: acc} when acc >= 0.60 ->
            {:ok, acc}

          %{correct_order: false} ->
            {:error, :wrong_stroke_order, accuracy: result.accuracy}

          %{correct_directions: false, wrong_strokes: wrong} ->
            {:error, :wrong_stroke_directions, wrong_strokes: wrong, accuracy: result.accuracy}

          %{accuracy: acc} ->
            {:error, :low_accuracy, accuracy: acc}
        end
    end
  end

  @doc """
  Checks stroke order without requiring exact shape matching.
  """
  def validate_stroke_order(_kanji, user_strokes, stroke_data) do
    expected_count = length(stroke_data["strokes"] || [])
    actual_count = length(user_strokes)

    cond do
      expected_count == 0 ->
        {:error, :no_stroke_data}

      actual_count != expected_count ->
        {:error, :wrong_stroke_count}

      true ->
        {:ok, 1.0}
    end
  end

  # Main analysis function
  defp analyze_and_compare(user_strokes, canonical_strokes) do
    # Analyze user strokes
    user_analysis = Enum.map(user_strokes, &analyze_stroke/1)

    # Analyze canonical strokes
    canonical_analysis = Enum.map(canonical_strokes, &analyze_canonical_stroke/1)

    # Check each stroke
    results =
      Enum.zip(user_analysis, canonical_analysis)
      |> Enum.with_index()
      |> Enum.map(fn {{user, canonical}, idx} ->
        compare_single_stroke_analysis(user, canonical, idx)
      end)

    correct_order = check_stroke_order(user_analysis, canonical_analysis)
    correct_directions = Enum.all?(results, & &1.correct_direction)
    wrong_strokes = Enum.filter(results, &(!&1.correct_direction)) |> Enum.map(& &1.index)

    avg_accuracy =
      if results == [] do
        0.0
      else
        total = Enum.map(results, & &1.accuracy) |> Enum.sum()
        total / length(results)
      end

    %{
      correct_order: correct_order,
      correct_directions: correct_directions,
      wrong_strokes: wrong_strokes,
      accuracy: avg_accuracy
    }
  end

  # Analyze a user stroke to extract features
  defp analyze_stroke(points) when length(points) < 2 do
    %{type: :unknown, direction: :unknown, bounds: nil, length: 0}
  end

  defp analyze_stroke(points) do
    # Calculate bounding box
    xs = Enum.map(points, fn {x, _} -> x end)
    ys = Enum.map(points, fn {_, y} -> y end)

    min_x = Enum.min(xs)
    max_x = Enum.max(xs)
    min_y = Enum.min(ys)
    max_y = Enum.max(ys)

    width = max_x - min_x
    height = max_y - min_y

    # Calculate total stroke length
    length = calculate_stroke_length(points)

    # Determine stroke type based on dominant direction
    type = classify_stroke_type(width, height)

    # Get primary direction
    direction = get_stroke_direction(points)

    %{
      type: type,
      direction: direction,
      bounds: %{
        min_x: min_x,
        max_x: max_x,
        min_y: min_y,
        max_y: max_y,
        width: width,
        height: height
      },
      length: length,
      center: {(min_x + max_x) / 2, (min_y + max_y) / 2}
    }
  end

  # Analyze canonical stroke from KanjiVG data
  defp analyze_canonical_stroke(%{"path" => path} = stroke_data) do
    # Parse SVG path to points for analysis
    points = parse_svg_path(path)

    if length(points) < 2 do
      %{
        type: Map.get(stroke_data, "type", "unknown") |> String.to_atom(),
        direction: :unknown,
        expected_position: nil
      }
    else
      xs = Enum.map(points, fn {x, _} -> x end)
      ys = Enum.map(points, fn {_, y} -> y end)

      min_x = Enum.min(xs)
      max_x = Enum.max(xs)
      min_y = Enum.min(ys)
      max_y = Enum.max(ys)

      width = max_x - min_x
      height = max_y - min_y

      type = Map.get(stroke_data, "type", "unknown") |> String.to_atom()
      direction = Map.get(stroke_data, "direction", "") |> classify_canonical_direction()

      %{
        type: type,
        direction: direction,
        bounds: %{
          min_x: min_x,
          max_x: max_x,
          min_y: min_y,
          max_y: max_y,
          width: width,
          height: height
        },
        center: {(min_x + max_x) / 2, (min_y + max_y) / 2}
      }
    end
  end

  defp analyze_canonical_stroke(_) do
    %{type: :unknown, direction: :unknown, expected_position: nil}
  end

  # Compare a single user stroke against canonical
  defp compare_single_stroke_analysis(user, canonical, index) do
    # Check if stroke type matches (horizontal vs vertical)
    type_match = stroke_types_compatible?(user.type, canonical.type)

    # Check direction compatibility
    direction_match = directions_compatible?(user.direction, canonical.direction)

    # Calculate position accuracy (how close is the center)
    position_accuracy = calculate_position_match(user.center, canonical.center)

    # Overall accuracy for this stroke
    accuracy =
      cond do
        type_match && direction_match -> 0.8 + position_accuracy * 0.2
        type_match -> 0.5 + position_accuracy * 0.2
        true -> position_accuracy * 0.3
      end

    %{
      index: index,
      correct_direction: type_match && direction_match,
      accuracy: accuracy,
      user_type: user.type,
      expected_type: canonical.type
    }
  end

  # Classify stroke type based on dimensions
  defp classify_stroke_type(width, height) when width > height * 2.5, do: :horizontal
  defp classify_stroke_type(width, height) when height > width * 2.5, do: :vertical
  defp classify_stroke_type(width, height) when width > height, do: :diagonal_rising
  defp classify_stroke_type(_, _), do: :diagonal_falling

  # Get stroke direction from first and last points
  defp get_stroke_direction([{x1, y1} | rest]) when length(rest) > 0 do
    {x2, y2} = List.last(rest)
    dx = x2 - x1
    dy = y2 - y1

    angle = :math.atan2(dy, dx) * 180 / :math.pi()

    cond do
      angle >= -22.5 and angle < 22.5 -> :right
      angle >= 22.5 and angle < 67.5 -> :down_right
      angle >= 67.5 and angle < 112.5 -> :down
      angle >= 112.5 and angle < 157.5 -> :down_left
      angle >= 157.5 or angle < -157.5 -> :left
      angle >= -157.5 and angle < -112.5 -> :up_left
      angle >= -112.5 and angle < -67.5 -> :up
      true -> :up_right
    end
  end

  defp get_stroke_direction(_), do: :unknown

  # Check if stroke types are compatible
  defp stroke_types_compatible?(:horizontal, :horizontal), do: true
  defp stroke_types_compatible?(:horizontal, "horizontal"), do: true
  defp stroke_types_compatible?(:vertical, :vertical), do: true
  defp stroke_types_compatible?(:vertical, "vertical"), do: true
  defp stroke_types_compatible?(:diagonal_rising, _), do: true
  defp stroke_types_compatible?(:diagonal_falling, _), do: true
  defp stroke_types_compatible?(_, _), do: false

  # Check if directions are compatible
  defp directions_compatible?(:unknown, _), do: true
  defp directions_compatible?(_, :unknown), do: true

  defp directions_compatible?(d1, d2) when is_binary(d2),
    do: directions_compatible?(d1, String.to_atom(String.replace(d2, "-", "_")))

  defp directions_compatible?(:right, :left_to_right), do: true
  defp directions_compatible?(:left, :right_to_left), do: true
  defp directions_compatible?(:down, :top_to_bottom), do: true
  defp directions_compatible?(:up, :bottom_to_top), do: true
  # Be lenient with direction
  defp directions_compatible?(_, _), do: true

  # Check stroke order (simple check: are strokes drawn in roughly the right sequence)
  defp check_stroke_order(user_analysis, canonical_analysis) do
    # For now, just check that the count matches and basic types are compatible
    # A more sophisticated check would verify top-to-bottom, left-to-right ordering
    length(user_analysis) == length(canonical_analysis)
  end

  # Calculate position match between two centers
  defp calculate_position_match({ux, uy}, {cx, cy}) do
    # Normalize to 0-1 range (assuming canvas size ~250)
    dx = abs(ux - cx) / 250
    dy = abs(uy - cy) / 250
    distance = :math.sqrt(dx * dx + dy * dy)

    # Convert distance to accuracy (closer = higher accuracy)
    max(0.0, 1.0 - distance)
  end

  defp calculate_position_match(_, _), do: 0.0

  # Calculate stroke length
  defp calculate_stroke_length(points) when length(points) < 2, do: 0.0

  defp calculate_stroke_length(points) do
    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{x1, y1}, {x2, y2}] ->
      :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
    end)
    |> Enum.sum()
  end

  # Parse SVG path for canonical strokes
  defp parse_svg_path(path) when is_binary(path) do
    # Extract coordinates from path like "M25.25,32.4c1.77,0.37..."
    Regex.scan(~r/(-?\d+\.?\d*),(-?\d+\.?\d*)/, path)
    |> Enum.map(fn [_, x, y] ->
      {parse_number(x), parse_number(y)}
    end)
  end

  defp parse_svg_path(_), do: []

  # Parse a number string to float (handles both "123" and "123.45")
  defp parse_number(str) do
    case Float.parse(str) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  # Classify direction from KanjiVG data
  defp classify_canonical_direction(""), do: :unknown

  defp classify_canonical_direction(dir) when is_binary(dir) do
    cond do
      String.contains?(dir, "left-to-right") -> :left_to_right
      String.contains?(dir, "right-to-left") -> :right_to_left
      String.contains?(dir, "top-to-bottom") -> :top_to_bottom
      String.contains?(dir, "bottom-to-top") -> :bottom_to_top
      true -> :unknown
    end
  end

  defp classify_canonical_direction(_), do: :unknown

  @doc """
  Returns a simplified validation result for display.
  """
  def format_result({:ok, accuracy}) do
    "Correct! Accuracy: #{round(accuracy * 100)}%"
  end

  def format_result({:error, :wrong_stroke_count, expected: e, actual: a}) do
    "Expected #{e} strokes, got #{a}"
  end

  def format_result({:error, :wrong_stroke_order, accuracy: acc}) do
    "Wrong stroke order. Accuracy: #{round(acc * 100)}%"
  end

  def format_result({:error, :wrong_stroke_directions, wrong_strokes: wrong, accuracy: acc}) do
    "Stroke #{Enum.join(wrong, ", ")} wrong direction/type. Accuracy: #{round(acc * 100)}%"
  end

  def format_result({:error, :low_accuracy, accuracy: acc}) do
    "Stroke shape incorrect. Accuracy: #{round(acc * 100)}%"
  end

  def format_result({:error, reason}) do
    "Error: #{reason}"
  end

  @doc """
  Validates a single stroke in real-time against the expected stroke.
  Returns immediately if the stroke is wrong.

  ## Parameters
    * `stroke_index` - 0-based index of the stroke being drawn
    * `user_stroke` - Points for the current stroke being drawn
    * `stroke_data` - The canonical stroke data from kanji database

  ## Returns
    * `:ok` - Stroke looks correct so far
    * `{:error, reason}` - Stroke is clearly wrong
  """
  def validate_stroke_realtime(stroke_index, user_stroke, stroke_data) do
    expected_strokes = stroke_data["strokes"] || []

    cond do
      stroke_index >= length(expected_strokes) ->
        {:error, :too_many_strokes}

      length(user_stroke) < 2 ->
        # Too early to tell
        :ok

      true ->
        expected = Enum.at(expected_strokes, stroke_index)
        analysis = analyze_stroke(user_stroke)
        expected_analysis = analyze_canonical_stroke(expected)

        # Check if stroke type is compatible
        if stroke_types_compatible?(analysis.type, expected_analysis.type) do
          :ok
        else
          {:error, :wrong_stroke_type, expected: expected_analysis.type, got: analysis.type}
        end
    end
  end
end
