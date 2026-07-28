defmodule Medoru.Tests.ClassroomKanjiDrawingTestGenerator do
  @moduledoc """
  Generates a teacher kanji drawing test for a classroom from selected kanji
  tied to words in the classroom's vocabulary lessons.

  Each selected entry becomes a writing step that asks for the kanji in the
  context of a word. The step's maximum points equal the kanji's stroke count,
  and the classroom test-taking LiveView awards
  `max(0, stroke_count - wrong_strokes)` points when the test is marked as a
  kanji drawing test via `metadata["kanji_drawing"] == true`.
  """

  alias Medoru.Classrooms
  alias Medoru.Repo
  alias Medoru.Tests

  @doc """
  Generates and publishes a kanji drawing test for a classroom.

  ## Options
    * `:title` - Test title (default: derived from classroom name)
    * `:due_date` - Optional due date for the classroom publication
    * `:max_attempts` - Optional max attempts for the classroom publication

  ## Examples
      generate_test(classroom, selected_entries, teacher_id,
        title: "Kanji Drawing Test",
        due_date: due_date,
        max_attempts: 3
      )
  """
  def generate_test(classroom, entries, teacher_id, opts \\ []) do
    title = Keyword.get(opts, :title, default_title(classroom))
    due_date = Keyword.get(opts, :due_date)
    max_attempts = Keyword.get(opts, :max_attempts)

    entries = Enum.reject(entries, &is_nil/1)

    if length(entries) == 0 do
      {:error, :no_kanji_selected}
    else
      drawable_entries = Enum.filter(entries, &has_strokes?/1)

      if length(drawable_entries) == 0 do
        {:error, :no_drawable_kanji}
      else
        selected_entries = Enum.sort_by(drawable_entries, & &1.kanji.character)

        Repo.transaction(fn ->
          test_attrs = %{
            title: title,
            description: "Kanji drawing test with #{length(selected_entries)} kanji",
            test_type: :teacher,
            status: :published,
            setup_state: "published",
            is_system: true,
            creator_id: teacher_id,
            metadata: %{
              kanji_drawing: true,
              kanji_count: length(selected_entries)
            }
          }

          with {:ok, test} <- Tests.create_test(test_attrs),
               {:ok, _steps} <- create_steps(test, selected_entries),
               {:ok, _classroom_test} <-
                 Classrooms.publish_test_to_classroom(classroom.id, test.id, teacher_id, %{
                   due_date: due_date,
                   max_attempts: max_attempts
                 }),
               updated_test <- Repo.get!(Tests.Test, test.id) do
            updated_test
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        end)
      end
    end
  end

  defp create_steps(test, entries) do
    steps =
      entries
      |> Enum.with_index(fn entry, index ->
        build_step(entry, index)
      end)

    Tests.create_test_steps(test, steps)
  end

  defp build_step(entry, index) do
    kanji = entry.kanji
    word = entry.word
    {reading_display, reading_is_fallback} = reading_info(entry)

    strokes =
      case kanji.stroke_data do
        %{"strokes" => strokes} when is_list(strokes) -> strokes
        _ -> []
      end

    meanings = Enum.take(kanji.meanings || [], 2)
    on_readings = readings(kanji, :on)
    kun_readings = readings(kanji, :kun)

    %{
      step_type: :writing,
      question_type: :writing,
      question: "__MSG_WRITE_KANJI_IN_WORD__|#{word.reading}|#{word.meaning}",
      correct_answer: kanji.character,
      kanji_id: kanji.id,
      points: kanji.stroke_count || 1,
      hints: [format_hint(meanings, on_readings, kun_readings)],
      question_data: %{
        type: :kanji_writing,
        kanji: kanji.character,
        meanings: meanings,
        stroke_count: kanji.stroke_count,
        strokes: strokes,
        on_reading: List.first(on_readings),
        kun_reading: List.first(kun_readings),
        on_readings: on_readings,
        kun_readings: kun_readings,
        word_reading: word.reading,
        word_meaning: word.meaning,
        reading_display: reading_display,
        reading_is_fallback: reading_is_fallback,
        word_id: word.id
      },
      order_index: index
    }
  end

  defp readings(kanji, type) do
    kanji =
      case kanji.kanji_readings do
        %Ecto.Association.NotLoaded{} -> Repo.preload(kanji, :kanji_readings)
        _ -> kanji
      end

    kanji.kanji_readings
    |> Enum.filter(&(&1.reading_type == type))
    |> Enum.sort_by(& &1.position)
    |> Enum.map(& &1.reading)
  end

  defp reading_in_word(%{kanji_reading_in_word: %{reading: reading}}), do: reading
  defp reading_in_word(_), do: nil

  defp reading_info(entry) do
    case reading_in_word(entry) do
      reading when is_binary(reading) and reading != "" ->
        {reading, false}

      _ ->
        on = List.first(readings(entry.kanji, :on)) || "-"
        kun = List.first(readings(entry.kanji, :kun)) || "-"
        {"#{on} / #{kun}", true}
    end
  end

  defp format_hint(meanings, on_readings, kun_readings) do
    parts =
      [
        if(meanings != [], do: "Meanings: #{Enum.join(meanings, ", ")}"),
        if(on_readings != [], do: "On: #{Enum.join(on_readings, ", ")}"),
        if(kun_readings != [], do: "Kun: #{Enum.join(kun_readings, ", ")}")
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, " • ")
  end

  defp has_strokes?(%{kanji: %{stroke_data: %{"strokes" => strokes}}})
       when is_list(strokes) and strokes != [],
       do: true

  defp has_strokes?(_), do: false

  defp default_title(classroom) do
    "#{classroom.name} - Kanji Drawing Test"
  end
end
