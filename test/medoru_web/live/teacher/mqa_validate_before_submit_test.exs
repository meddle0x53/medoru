defmodule MedoruWeb.Teacher.MqaValidateBeforeSubmitTest do
  use MedoruWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Medoru.TestsFixtures
  import Medoru.AccountsFixtures

  alias Medoru.Tests

  setup do
    teacher = user_fixture(%{type: "teacher"})
    teacher_test = teacher_test_fixture(teacher.id)
    %{teacher: teacher, teacher_test: teacher_test}
  end

  test "make_question_answer step survives validate-before-submit on add and edit", %{
    conn: conn,
    teacher: teacher,
    teacher_test: test
  } do
    {:ok, view, _html} =
      conn |> log_in_user(teacher) |> live(~p"/teacher/tests/#{test.id}/edit")

    view |> element("button", "Add First Step") |> render_click()

    view
    |> element("button[phx-value-type='grammar_make_question_answer']")
    |> render_click()

    attrs = %{
      "question" => "Make a question in the pattern and answer it",
      "question_data" => %{
        "requirement" => "家の 部屋で 料理（いいえ）",
        "expected_question" => "家の部屋で料理ができますか。",
        "expected_answer" => "いいえ、できません。",
        "expected_question_reading" => "いえのへやでりょうりができますか",
        "expected_answer_reading" => "いいえできません",
        "examples_text" => "この 公園で サッカー（はい）\nこの公園でサッカーができますか。\n……はい、できます。"
      }
    }

    # Simulate real typing: phx-change fires before submit.
    view
    |> form("#step-form", %{"step" => attrs})
    |> render_change()

    view
    |> form("#step-form", %{"step" => attrs})
    |> render_submit()

    assert render(view) =~ "Step added successfully."

    [step] = Tests.list_test_steps(test.id)
    assert step.question_data["examples"] == ["この 公園で サッカー（はい）\nこの公園でサッカーができますか。\n……はい、できます。"]

    # Edit the step: validate a change, then submit update_step.
    view
    |> element("button[phx-click='edit_step'][phx-value-step-id='#{step.id}']")
    |> render_click()

    updated_attrs = put_in(attrs, ["question_data", "requirement"], "寮の 部屋で 料理（いいえ）")

    view
    |> form("#step-form", %{"step" => updated_attrs})
    |> render_change()

    view
    |> form("#step-form", %{"step" => updated_attrs})
    |> render_submit()

    assert render(view) =~ "Step updated successfully."

    updated = Tests.get_test_step(step.id)
    assert updated.question_data["requirement"] == "寮の 部屋で 料理（いいえ）"

    assert updated.question_data["examples"] == [
             "この 公園で サッカー（はい）\nこの公園でサッカーができますか。\n……はい、できます。"
           ]
  end
end
