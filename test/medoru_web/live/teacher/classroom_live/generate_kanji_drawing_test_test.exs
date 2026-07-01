defmodule MedoruWeb.Teacher.ClassroomLive.GenerateKanjiDrawingTestTest do
  use MedoruWeb.ConnCase

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Phoenix.LiveViewTest

  alias Medoru.Classrooms
  alias Medoru.Content

  describe "Generate Kanji Drawing Test page" do
    setup %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          description: "Test",
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

      {:ok, kanji2} =
        Content.update_kanji(kanji2, %{
          stroke_count: 3,
          stroke_data: stroke_data
        })

      {:ok, _} = Content.add_word_to_lesson(lesson.id, word.id, %{position: 0})
      {:ok, _} = Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      %{conn: log_in_user(conn, teacher), classroom: classroom, kanji: [kanji1, kanji2]}
    end

    test "teacher sees classroom kanji and can generate a drawing test", %{
      conn: conn,
      classroom: classroom,
      kanji: kanji
    } do
      [kanji1 | _] = kanji

      {:ok, view, html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/generate-kanji-drawing-test")

      assert html =~ "Generate Kanji Drawing Test"
      assert html =~ kanji1.character

      view
      |> element("form#generate-kanji-test-form")
      |> render_submit(%{
        "kanji_ids" => Enum.map(kanji, & &1.id),
        "title" => "My Kanji Drawing Test"
      })

      assert_redirected(view, ~p"/teacher/classrooms/#{classroom.id}?tab=tests")

      published_tests = Classrooms.list_classroom_tests(classroom.id, status: :active)
      assert length(published_tests) == 1
      assert hd(published_tests).test.title == "My Kanji Drawing Test"
    end

    test "teacher can select and deselect all kanji", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} =
        live(conn, ~p"/teacher/classrooms/#{classroom.id}/generate-kanji-drawing-test")

      view
      |> element("input#select-all-kanji")
      |> render_click()

      html = render(view)
      assert html =~ "0 of 2 kanji selected"

      view
      |> element("input#select-all-kanji")
      |> render_click()

      html = render(view)
      assert html =~ "2 of 2 kanji selected"
    end

    test "non-owner teacher cannot access generate kanji drawing test page", %{conn: conn} do
      teacher1 = user_fixture(%{type: "teacher"})
      teacher2 = user_fixture(%{type: "teacher"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          description: "Test",
          teacher_id: teacher1.id
        })

      {:error, {:live_redirect, %{to: "/teacher/classrooms", flash: flash}}} =
        conn
        |> log_in_user(teacher2)
        |> live(~p"/teacher/classrooms/#{classroom.id}/generate-kanji-drawing-test")

      assert flash["error"] == "You don't have permission to access this classroom."
    end
  end
end
