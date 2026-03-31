defmodule MedoruWeb.Teacher.TestLiveEditDialogTest do
  @moduledoc """
  Tests for teacher test edit dialog closing behavior.
  """
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Medoru.Tests
  import Medoru.AccountsFixtures
  import Medoru.TestsFixtures

  setup %{conn: conn} do
    teacher = user_fixture(%{type: "teacher"})
    test = teacher_test_fixture(teacher.id)

    # Create a simple multichoice step
    {:ok, step} =
      Tests.create_test_step(test, %{
        question: "What is the meaning of 高い?",
        question_type: :multichoice,
        step_type: :vocabulary,
        order_index: 0,
        question_data: %{},
        options: ["expensive/tall", "cheap", "fast", "slow"],
        correct_answer: "expensive/tall",
        points: 1,
        kanji_id: nil,
        word_id: nil
      })

    conn = log_in_user(conn, teacher)

    {:ok, conn: conn, test_obj: test, step: step}
  end

  test "dialog opens when clicking edit button", %{conn: conn, test_obj: test, step: step} do
    {:ok, view, _html} = live(conn, "/teacher/tests/#{test.id}/edit")
    assert render(view) =~ "What is the meaning"

    html =
      view
      |> element("button[phx-click='edit_step'][phx-value-step-id='#{step.id}']")
      |> render_click()

    assert html =~ "Edit Step"
  end

  test "dialog closes after form submission", %{conn: conn, test_obj: test, step: step} do
    {:ok, view, _html} = live(conn, "/teacher/tests/#{test.id}/edit")

    # Open edit dialog
    view
    |> element("button[phx-click='edit_step'][phx-value-step-id='#{step.id}']")
    |> render_click()

    assert render(view) =~ "Edit Step"

    # Submit the form with updated question
    html =
      view
      |> form("#step-form", %{
        step: %{
          question: "Updated: What is the meaning of 高い?"
        }
      })
      |> render_submit()

    # Verify dialog is closed and success message is shown
    refute html =~ "Edit Step"
    assert html =~ "Step updated successfully"
    assert html =~ "Updated: What is the meaning"
  end
end
