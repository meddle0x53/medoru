defmodule MedoruWeb.Teacher.TestSentenceValidationShowPatternTest do
  @moduledoc """
  Tests for the show_pattern checkbox in sentence validation steps.
  """
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Medoru.Tests
  import Medoru.AccountsFixtures
  import Medoru.TestsFixtures

  setup %{conn: conn} do
    teacher = user_fixture(%{type: "teacher"})
    test = teacher_test_fixture(teacher.id)

    # Create a sentence validation step with show_pattern initially true
    {:ok, step} =
      Tests.create_test_step(test, %{
        question: "Is this sentence correct?",
        question_type: :sentence_validation,
        step_type: :grammar,
        order_index: 0,
        question_data: %{
          "target_sentence" => "私は学生です",
          "is_correct" => true,
          "show_pattern" => true
        },
        options: [],
        correct_answer: "N/A",
        points: 10,
        kanji_id: nil,
        word_id: nil
      })

    conn = log_in_user(conn, teacher)

    {:ok, conn: conn, test_obj: test, step: step}
  end

  test "show_pattern checkbox is checked when editing step with show_pattern=true", %{
    conn: conn,
    test_obj: test,
    step: step
  } do
    {:ok, view, _html} = live(conn, "/teacher/tests/#{test.id}/edit")

    # Open edit dialog
    html =
      view
      |> element("button[phx-click='edit_step'][phx-value-step-id='#{step.id}']")
      |> render_click()

    # The checkbox should be checked
    assert html =~ "Show grammar pattern to students"
    # Check that the checkbox input has checked attribute
    assert html =~ ~s{checked}
  end

  test "unchecking show_pattern and saving persists the change", %{
    conn: conn,
    test_obj: test,
    step: step
  } do
    {:ok, view, _html} = live(conn, "/teacher/tests/#{test.id}/edit")

    # Open edit dialog
    view
    |> element("button[phx-click='edit_step'][phx-value-step-id='#{step.id}']")
    |> render_click()

    # Trigger a validation change to uncheck the checkbox
    view
    |> form("#step-form")
    |> render_change(%{
      step: %{
        question: "Is this sentence correct?",
        question_data: %{
          show_pattern: "false",
          target_sentence: "test"
        }
      }
    })

    # Now submit the form
    html =
      view
      |> form("#step-form")
      |> render_submit()

    # Dialog should close
    refute html =~ "Edit Step"
    assert html =~ "Step updated successfully"

    # Verify in database that show_pattern is now false
    updated_step = Tests.get_test_step(step.id)
    assert updated_step.question_data["show_pattern"] == false
  end

  test "checking show_pattern and saving persists the change", %{
    conn: conn,
    test_obj: test,
    step: step
  } do
    # First update step to have show_pattern=false
    Tests.update_test_step(step, %{
      "question_data" => Map.put(step.question_data, "show_pattern", false)
    })

    {:ok, view, _html} = live(conn, "/teacher/tests/#{test.id}/edit")

    # Open edit dialog
    view
    |> element("button[phx-click='edit_step'][phx-value-step-id='#{step.id}']")
    |> render_click()

    # Trigger a validation change to check the checkbox
    view
    |> form("#step-form")
    |> render_change(%{
      step: %{
        question: "Is this sentence correct?",
        question_data: %{
          show_pattern: "on",
          target_sentence: "test"
        }
      }
    })

    # Now submit the form
    html =
      view
      |> form("#step-form")
      |> render_submit()

    # Dialog should close
    refute html =~ "Edit Step"
    assert html =~ "Step updated successfully"

    # Verify in database that show_pattern is now true
    updated_step = Tests.get_test_step(step.id)
    assert updated_step.question_data["show_pattern"] == true
  end
end
