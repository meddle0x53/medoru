defmodule MedoruWeb.TestLive.IndexTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.TestsFixtures

  alias Medoru.Classrooms

  describe "public featured-classroom tests page" do
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
          total_points: 20,
          time_limit_seconds: 600
        })

      {:ok, _} =
        Classrooms.publish_test_to_classroom(classroom.id, test_record.id, teacher.id, %{
          due_date: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
        })

      original = Application.get_env(:medoru, :featured_classroom_id)
      Application.put_env(:medoru, :featured_classroom_id, classroom.id)

      on_exit(fn ->
        Application.put_env(:medoru, :featured_classroom_id, original)
      end)

      %{conn: conn, classroom: classroom, test_record: test_record, teacher: teacher}
    end

    test "anonymous user sees the tests page with published tests", %{
      conn: conn,
      test_record: test_record
    } do
      {:ok, _view, html} = live(conn, ~p"/tests")

      assert html =~ "Tests"
      assert html =~ test_record.title
      assert html =~ "Start Test"
      assert html =~ "20 points"
    end

    test "test link points to the public classroom test route", %{
      conn: conn,
      classroom: classroom,
      test_record: test_record
    } do
      {:ok, view, _html} = live(conn, ~p"/tests")

      assert has_element?(
               view,
               "a[href='/classrooms/#{classroom.slug}/tests/#{test_record.slug}']",
               "Start Test"
             )
    end

    test "anonymous user sees empty state when featured classroom has no tests", %{
      conn: conn,
      classroom: classroom,
      teacher: teacher
    } do
      # Clear published tests but keep featured classroom set
      Classrooms.list_classroom_tests(classroom.id)
      |> Enum.each(fn ct ->
        Classrooms.unpublish_test_from_classroom(ct, teacher.id)
      end)

      {:ok, _view, html} = live(conn, ~p"/tests")

      assert html =~ "Sign in to see your tests"
    end
  end

  describe "tests page without featured classroom" do
    setup %{conn: conn} do
      original = Application.get_env(:medoru, :featured_classroom_id)
      Application.put_env(:medoru, :featured_classroom_id, nil)

      on_exit(fn ->
        Application.put_env(:medoru, :featured_classroom_id, original)
      end)

      %{conn: conn}
    end

    test "anonymous user sees empty state when no classroom is featured", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tests")

      assert html =~ "Sign in to see your tests"
    end
  end
end
