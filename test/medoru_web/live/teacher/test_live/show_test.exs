defmodule MedoruWeb.Teacher.TestLive.ShowTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Medoru.Tests

  describe "Test details" do
    setup do
      teacher = teacher_fixture()
      teacher_test = teacher_test_fixture(teacher.id)
      %{teacher: teacher, teacher_test: teacher_test}
    end

    test "renders test title and description", %{
      conn: conn,
      teacher: teacher,
      teacher_test: teacher_test
    } do
      {:ok, _view, html} =
        conn
        |> log_in_user(teacher)
        |> live(~p"/teacher/tests/#{teacher_test.id}")

      assert html =~ teacher_test.title
      assert html =~ (teacher_test.description || "No description")
    end

    test "owner can edit title and description", %{
      conn: conn,
      teacher: teacher,
      teacher_test: teacher_test
    } do
      {:ok, view, _html} =
        conn
        |> log_in_user(teacher)
        |> live(~p"/teacher/tests/#{teacher_test.id}")

      view
      |> element("button[phx-click='edit_details']")
      |> render_click()

      assert has_element?(view, "form#test-details-form")

      view
      |> form("#test-details-form", %{
        "test" => %{
          "title" => "Updated Test Title",
          "description" => "Updated description text."
        }
      })
      |> render_submit()

      assert render(view) =~ "Updated Test Title"
      assert render(view) =~ "Updated description text."

      updated_test = Tests.get_test!(teacher_test.id)
      assert updated_test.title == "Updated Test Title"
      assert updated_test.description == "Updated description text."
    end

    test "validation errors are shown for empty title", %{
      conn: conn,
      teacher: teacher,
      teacher_test: teacher_test
    } do
      {:ok, view, _html} =
        conn
        |> log_in_user(teacher)
        |> live(~p"/teacher/tests/#{teacher_test.id}")

      view
      |> element("button[phx-click='edit_details']")
      |> render_click()

      html =
        view
        |> form("#test-details-form", %{
          "test" => %{"title" => "", "description" => ""}
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "redirects non-owner to test list", %{
      conn: conn,
      teacher_test: teacher_test
    } do
      other_teacher = teacher_fixture()

      result =
        conn
        |> log_in_user(other_teacher)
        |> live(~p"/teacher/tests/#{teacher_test.id}")

      assert {:error, {:live_redirect, %{to: "/teacher/tests"}}} = result
    end
  end
end
