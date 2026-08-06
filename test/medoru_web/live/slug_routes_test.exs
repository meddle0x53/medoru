defmodule MedoruWeb.SlugRoutesTest do
  use MedoruWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures
  import Medoru.TestsFixtures

  alias Medoru.Classrooms
  alias Medoru.Content

  describe "public classroom content accessed by slug" do
    setup %{conn: conn} do
      teacher = user_fixture(%{email: "teacher@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Featured Classroom",
          description: "Public featured classroom",
          teacher_id: teacher.id
        })

      test_record =
        test_fixture(%{
          title: "Public Featured Test",
          description: "A test anyone can try",
          test_type: :teacher,
          status: :published,
          total_points: 20
        })

      _ = test_step_fixture(test_record)

      {:ok, _} =
        Classrooms.publish_test_to_classroom(classroom.id, test_record.id, teacher.id)

      lesson =
        custom_lesson_fixture(%{
          title: "Public Featured Lesson",
          creator_id: teacher.id,
          status: "published"
        })

      {:ok, _} =
        Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)

      original = Application.get_env(:medoru, :featured_classroom_id)
      Application.put_env(:medoru, :featured_classroom_id, classroom.id)

      on_exit(fn ->
        Application.put_env(:medoru, :featured_classroom_id, original)
      end)

      %{
        conn: conn,
        classroom: classroom,
        test_record: test_record,
        lesson: lesson
      }
    end

    test "public test page loads using classroom slug and test slug", %{
      conn: conn,
      classroom: classroom,
      test_record: test_record
    } do
      path = "/classrooms/#{classroom.slug}/tests/#{test_record.slug}"
      {:ok, _view, html} = live(conn, path)

      assert html =~ test_record.title
    end

    test "public custom lesson page loads using classroom slug and lesson slug", %{
      conn: conn,
      classroom: classroom,
      lesson: lesson
    } do
      path = "/classrooms/#{classroom.slug}/custom-lessons/#{lesson.slug}"
      {:ok, _view, html} = live(conn, path)

      assert html =~ lesson.title
    end

    test "lesson slug that is exactly 16 bytes is not mistaken for a UUID", %{
      conn: conn,
      classroom: classroom,
      lesson: _lesson
    } do
      # Regression: Ecto.UUID.cast/1 accepts any raw 16-byte binary as an
      # already-dumped UUID, so a 16-byte slug like "iv-grammar-notes" used to
      # crash with Ecto.Query.CastError instead of hitting the slug lookup.
      lesson16 =
        custom_lesson_fixture(%{
          title: "Sixteen Byte Slug Lesson",
          slug: "iv-grammar-notes",
          creator_id: classroom.teacher_id,
          status: "published"
        })

      {:ok, _} =
        Content.publish_lesson_to_classroom(lesson16.id, classroom.id, classroom.teacher_id)

      path = "/classrooms/#{classroom.slug}/custom-lessons/#{lesson16.slug}"
      {:ok, _view, html} = live(conn, path)

      assert html =~ lesson16.title
    end
  end
end
