defmodule Medoru.Tests.ClassroomKanjiDrawingTestGenerator do
  @moduledoc """
  Generates a teacher kanji drawing test for a classroom from selected kanji.

  Each selected kanji becomes a writing step. The step's maximum points equal the
  kanji's stroke count, and the classroom test-taking LiveView awards
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
      generate_test(classroom, selected_kanji, teacher_id,
        title: "Kanji Drawing Test",
        due_date: due_date,
        max_attempts: 3
      )
  """
  def generate_test(classroom, kanji, teacher_id, opts \\ []) do
    title = Keyword.get(opts, :title, default_title(classroom))
    due_date = Keyword.get(opts, :due_date)
    max_attempts = Keyword.get(opts, :max_attempts)

    kanji = Enum.reject(kanji, &is_nil/1)

    if length(kanji) == 0 do
      {:error, :no_kanji_selected}
    else
      drawable_kanji = Enum.filter(kanji, &has_strokes?/1)

      if length(drawable_kanji) == 0 do
        {:error, :no_drawable_kanji}
      else
        selected_kanji = Enum.sort_by(drawable_kanji, & &1.character)

        Repo.transaction(fn ->
          test_attrs = %{
            title: title,
            description: "Kanji drawing test with #{length(selected_kanji)} kanji",
            test_type: :teacher,
            status: :published,
            setup_state: "published",
            is_system: true,
            creator_id: teacher_id,
            metadata: %{
              kanji_drawing: true,
              kanji_count: length(selected_kanji)
            }
          }

          with {:ok, test} <- Tests.create_test(test_attrs),
               {:ok, _steps} <- create_steps(test, selected_kanji),
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

  defp create_steps(test, kanji) do
    steps =
      kanji
      |> Enum.with_index(fn kanji, index ->
        build_step(kanji, index)
      end)

    Tests.create_test_steps(test, steps)
  end

  defp build_step(kanji, index) do
    strokes =
      case kanji.stroke_data do
        %{"strokes" => strokes} when is_list(strokes) -> strokes
        _ -> []
      end

    meanings = Enum.take(kanji.meanings || [], 2)
    meanings_text = Enum.join(meanings, ", ")

    %{
      step_type: :writing,
      question_type: :writing,
      question: "__MSG_WRITE_KANJI_FOR__|#{meanings_text}",
      correct_answer: kanji.character,
      kanji_id: kanji.id,
      points: kanji.stroke_count || 1,
      hints: ["Draw the kanji stroke by stroke"],
      question_data: %{
        type: :kanji_writing,
        kanji: kanji.character,
        meanings: meanings,
        stroke_count: kanji.stroke_count,
        strokes: strokes,
        on_reading: first_reading(kanji, :on),
        kun_reading: first_reading(kanji, :kun)
      },
      order_index: index
    }
  end

  defp first_reading(kanji, type) do
    kanji =
      case kanji.kanji_readings do
        %Ecto.Association.NotLoaded{} -> Repo.preload(kanji, :kanji_readings)
        _ -> kanji
      end

    case Enum.find(kanji.kanji_readings || [], &(&1.reading_type == type)) do
      nil -> nil
      reading -> reading.reading
    end
  end

  defp has_strokes?(%{stroke_data: %{"strokes" => strokes}}) when is_list(strokes) and strokes != [],
    do: true

  defp has_strokes?(_), do: false

  defp default_title(classroom) do
    "#{classroom.name} - Kanji Drawing Test"
  end
end
