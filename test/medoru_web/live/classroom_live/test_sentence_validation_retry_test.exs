defmodule MedoruWeb.ClassroomLive.TestSentenceValidationRetryTest do
  @moduledoc """
  Tests for sentence validation step retry behavior (up to 4 attempts).
  """
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Medoru.{Accounts, Classrooms, Content, Tests}

  setup %{conn: conn} do
    # Create users
    {:ok, teacher} =
      Accounts.register_user_with_oauth(%{
        email: "teacher@example.com",
        provider: "google",
        provider_uid: "teacher123"
      })

    {:ok, student} =
      Accounts.register_user_with_oauth(%{
        email: "student@example.com",
        provider: "google",
        provider_uid: "student123"
      })

    # Create a classroom
    {:ok, classroom} =
      Classrooms.create_classroom(%{
        name: "Test Classroom",
        teacher_id: teacher.id
      })

    # Add student to classroom
    {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
    {:ok, _} = Classrooms.approve_membership(membership)

    # Create grammar forms
    {:ok, te_form} =
      Content.create_grammar_form(%{
        name: "te-form",
        display_name: "te-form",
        word_type: "verb",
        description: "Te form"
      })

    # Create a verb word
    {:ok, word} =
      Content.create_word(%{
        text: "食べる",
        reading: "たべる",
        meaning: "to eat",
        word_type: :verb,
        difficulty: 1
      })

    # Create conjugation
    {:ok, _conjugation} =
      Content.create_word_conjugation(%{
        word_id: word.id,
        grammar_form_id: te_form.id,
        conjugated_form: "食べて",
        reading: "たべて"
      })

    # Create a test with sentence_validation step
    {:ok, test_resource} =
      Tests.create_test(%{
        title: "Grammar Test",
        description: "Test grammar validation",
        created_by_id: teacher.id,
        test_type: :teacher,
        status: :published,
        total_points: 10,
        time_limit_seconds: 600
      })

    # Create sentence validation step
    {:ok, step} =
      Tests.create_test_step(test_resource, %{
        question: "Conjugate 食べる to te-form",
        question_type: :sentence_validation,
        step_type: :grammar,
        order_index: 0,
        question_data: %{
          "pattern" => [
            %{
              "type" => "word_slot",
              "word_type" => "verb",
              "forms" => ["te-form"]
            }
          ]
        },
        options: [],
        correct_answer: "N/A",
        points: 10,
        kanji_id: nil,
        word_id: word.id
      })

    # Publish test to classroom
    {:ok, classroom_test} =
      Classrooms.publish_test_to_classroom(
        classroom.id,
        test_resource.id,
        teacher.id,
        %{
          due_date: DateTime.utc_now() |> DateTime.add(7, :day),
          max_attempts: 1,
          time_limit_seconds: 600
        }
      )

    conn = log_in_user(conn, student)

    {:ok,
     conn: conn,
     student: student,
     classroom: classroom,
     test_resource: test_resource,
     step: step,
     classroom_test: classroom_test}
  end

  test "sentence validation shows correct attempt count on wrong answers", %{
    conn: conn,
    classroom: classroom,
    test_resource: test_resource
  } do
    # Start the test
    {:ok, view, _html} = live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}")

    # First wrong attempt - should show 1/4
    html =
      view
      |> form("form[phx-submit='submit_answer']", %{answer: "wrong1"})
      |> render_submit()

    assert html =~ "1/4 attempts", "First wrong should show 1/4, got: #{inspect(html)}"

    # Second wrong attempt - should show 2/4
    html =
      view
      |> form("form[phx-submit='submit_answer']", %{answer: "wrong2"})
      |> render_submit()

    assert html =~ "2/4 attempts", "Second wrong should show 2/4"

    # Third wrong attempt - should show 3/4
    html =
      view
      |> form("form[phx-submit='submit_answer']", %{answer: "wrong3"})
      |> render_submit()

    assert html =~ "3/4 attempts", "Third wrong should show 3/4"
  end

  test "sentence validation moves to next step after 4 wrong attempts", %{
    conn: conn,
    classroom: classroom,
    test_resource: test_resource
  } do
    # Start the test
    {:ok, view, _html} = live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}")

    # Submit 4 wrong answers
    results =
      for i <- 1..4 do
        view
        |> form("form[phx-submit='submit_answer']", %{answer: "wrong#{i}"})
        |> render_submit()
      end

    # After 4 wrong attempts, should redirect to results
    # The last result should be a redirect tuple
    last_result = List.last(results)

    # Check if we got redirected (the result is {:error, {:live_redirect, %{to: url}}})
    redirected =
      case last_result do
        {:error, {:live_redirect, %{to: url}}} -> url =~ "/results"
        {:error, {:redirect, %{to: url}}} -> url =~ "/results"
        html when is_binary(html) -> html =~ "results" or html =~ "/results"
        _ -> false
      end

    assert redirected,
           "Should have redirected to results after 4 wrong attempts, got: #{inspect(last_result)}"
  end

  test "sentence validation accepts correct answer and moves on", %{
    conn: conn,
    classroom: classroom,
    test_resource: test_resource
  } do
    # Start the test
    {:ok, view, _html} = live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}")

    # Submit correct answer
    result =
      view
      |> form("form[phx-submit='submit_answer']", %{answer: "食べて"})
      |> render_submit()

    # Should redirect to results (since there's only 1 step)
    redirected =
      case result do
        {:error, {:live_redirect, %{to: url}}} -> url =~ "/results"
        {:error, {:redirect, %{to: url}}} -> url =~ "/results"
        html when is_binary(html) -> html =~ "results" or html =~ "/results"
        _ -> false
      end

    assert redirected,
           "Should have redirected to results after correct answer, got: #{inspect(result)}"
  end
end
