defmodule Medoru.Tests.ClassroomKanjiDrawingTestGeneratorTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Tests
  alias Medoru.Tests.ClassroomKanjiDrawingTestGenerator

  describe "generate_test/4" do
    setup do
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      lesson = custom_lesson_fixture(%{creator_id: teacher.id, lesson_subtype: "vocabulary"})

      stroke_data = %{"strokes" => [%{"path" => "M 10 10 L 20 20"}]}

      word =
        word_with_kanji_fixture(
          %{stroke_count: 5, stroke_data: stroke_data},
          %{text: "日本", meaning: "Japan", reading: "にほん"}
        )

      [kanji1, kanji2] = Enum.map(word.word_kanjis, & &1.kanji)

      # Update the second kanji to have distinct stroke data for the test.
      {:ok, kanji2} =
        Content.update_kanji(kanji2, %{
          stroke_count: 3,
          stroke_data: stroke_data
        })

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})
      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      kanji = [kanji1, kanji2]

      entries =
        word.word_kanjis
        |> Enum.map(fn wk ->
          %{
            kanji_id: wk.kanji_id,
            kanji: wk.kanji,
            word: word,
            word_kanji: wk,
            kanji_reading_in_word: wk.kanji_reading
          }
        end)
        |> Enum.map(fn entry ->
          if entry.kanji_id == kanji2.id do
            %{entry | kanji: kanji2}
          else
            entry
          end
        end)

      %{
        classroom: classroom,
        teacher: teacher,
        lesson: lesson,
        word: word,
        kanji: kanji,
        entries: entries
      }
    end

    test "generates and publishes a kanji drawing test to the classroom", %{
      classroom: classroom,
      teacher: teacher,
      entries: entries
    } do
      assert {:ok, test} =
               ClassroomKanjiDrawingTestGenerator.generate_test(
                 classroom,
                 entries,
                 teacher.id,
                 title: "Kanji Drawing Test"
               )

      assert test.title == "Kanji Drawing Test"
      assert test.test_type == :teacher
      assert test.setup_state == "published"
      assert test.metadata["kanji_drawing"] == true
      assert test.total_points == 8

      test = Tests.get_test!(test.id) |> Medoru.Repo.preload(:test_steps)
      assert length(test.test_steps) == 2

      Enum.each(test.test_steps, fn step ->
        assert step.step_type == :writing
        assert step.question_type == :writing
        assert step.kanji_id in Enum.map(entries, & &1.kanji_id)
        assert step.points == step.question_data["stroke_count"]
        assert step.question =~ "__MSG_WRITE_KANJI_IN_WORD__"
        assert is_list(step.question_data["strokes"])
        assert step.question_data["on_reading"]
        assert step.question_data["kun_reading"]
        assert step.question_data["word_reading"] == "にほん"
        assert step.question_data["word_meaning"] == "Japan"
        assert step.question_data["reading_display"]
        assert is_boolean(step.question_data["reading_is_fallback"])
      end)

      classroom_tests = Classrooms.list_classroom_tests(classroom.id, status: :active)
      assert Enum.any?(classroom_tests, &(&1.test_id == test.id))
    end

    test "returns error when no kanji are selected", %{
      classroom: classroom,
      teacher: teacher
    } do
      assert {:error, :no_kanji_selected} =
               ClassroomKanjiDrawingTestGenerator.generate_test(
                 classroom,
                 [],
                 teacher.id
               )
    end

    test "returns error when selected kanji have no stroke data", %{
      classroom: classroom,
      teacher: teacher,
      entries: [entry | _]
    } do
      {:ok, kanji_no_strokes} =
        Content.update_kanji(entry.kanji, %{stroke_data: %{}})

      entry_no_strokes = %{entry | kanji: kanji_no_strokes}

      assert {:error, :no_drawable_kanji} =
               ClassroomKanjiDrawingTestGenerator.generate_test(
                 classroom,
                 [entry_no_strokes],
                 teacher.id
               )
    end

    test "passes due_date and max_attempts to classroom publication", %{
      classroom: classroom,
      teacher: teacher,
      entries: entries
    } do
      due_date = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, test} =
               ClassroomKanjiDrawingTestGenerator.generate_test(
                 classroom,
                 entries,
                 teacher.id,
                 title: "Kanji Drawing",
                 due_date: due_date,
                 max_attempts: 2
               )

      classroom_tests = Classrooms.list_classroom_tests(classroom.id, status: :active)
      classroom_test = Enum.find(classroom_tests, &(&1.test_id == test.id))

      assert classroom_test
      assert classroom_test.due_date == due_date
      assert classroom_test.max_attempts == 2
    end
  end
end
