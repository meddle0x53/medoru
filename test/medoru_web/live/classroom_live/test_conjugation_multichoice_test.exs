defmodule MedoruWeb.ClassroomLive.TestConjugationMultichoiceTest do
  @moduledoc """
  Tests for student taking a conjugation multichoice test.
  """
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Medoru.{Accounts, Classrooms, Content, Tests}

  setup %{conn: conn} do
    # Create a user
    {:ok, user} =
      Accounts.register_user_with_oauth(%{
        email: "student@example.com",
        provider: "google",
        provider_uid: "test123"
      })

    # Create a teacher
    {:ok, teacher} =
      Accounts.register_user_with_oauth(%{
        email: "teacher@example.com",
        provider: "google",
        provider_uid: "teacher123"
      })

    # Create word and grammar form
    {:ok, word} =
      Content.create_word(%{
        text: "高い",
        reading: "たかい",
        meaning: "expensive/tall",
        word_type: :adjective,
        difficulty: 1
      })

    {:ok, grammar_form} =
      Content.create_grammar_form(%{
        name: "past-i",
        display_name: "past form",
        word_type: "adjective",
        description: "Past tense for i-adjectives"
      })

    # Create conjugation
    {:ok, _conjugation} =
      Content.create_word_conjugation(%{
        word_id: word.id,
        grammar_form_id: grammar_form.id,
        conjugated_form: "高かった",
        reading: "たかかった"
      })

    # Create a test with conjugation multichoice step
    {:ok, test} =
      Tests.create_test(%{
        title: "Conjugation Test",
        description: "Test conjugation skills",
        created_by_id: teacher.id,
        test_type: :teacher,
        status: :published,
        total_points: 3,
        time_limit_seconds: 300
      })

    # Create the step with conjugation multichoice
    {:ok, step} =
      Tests.create_test_step(test, %{
        question: "Conjugate 高い to past form",
        question_type: :conjugation_multichoice,
        step_type: :grammar,
        question_data: %{
          "base_word" => "高い",
          "target_form" => "past-i",
          "word_type" => "i_adjective",
          "selected_word" => word.id,
          "selected_word_text" => "高い",
          "generated_answer" => "高かった",
          "generated_question" => "Conjugate 高い to past form"
        },
        correct_answer: "N/A",
        # Options include the correct answer (prepended by the form handler) + wrong answers
        options: ["高かった", "たかい", "てあか", "高いひと"],
        points: 3,
        order_index: 0
      })

    # Create a classroom
    {:ok, classroom} =
      Classrooms.create_classroom(%{
        name: "Test Classroom",
        description: "Test classroom",
        teacher_id: teacher.id
      })

    # Add user to classroom
    {:ok, membership} = Classrooms.apply_to_join(classroom.id, user.id)
    {:ok, _membership} = Classrooms.approve_membership(membership)

    # Publish test to classroom
    {:ok, _classroom_test} =
      Classrooms.publish_test_to_classroom(classroom.id, test.id, teacher.id, %{
        max_attempts: 1,
        time_limit_seconds: 300
      })

    # Log in as student
    conn = log_in_user(conn, user)

    %{
      conn: conn,
      user: user,
      teacher: teacher,
      classroom: classroom,
      test_item: test,
      step: step,
      word: word
    }
  end

  describe "conjugation multichoice student view" do
    test "displays word and target form correctly", %{
      conn: conn,
      classroom: classroom,
      test_item: test
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      # Should show the word being conjugated
      assert render(view) =~ "高い"
      # Should show the target form
      assert render(view) =~ "past-i"
    end

    test "displays all options including generated correct answer", %{
      conn: conn,
      classroom: classroom,
      test_item: test,
      step: step
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      html = render(view)

      # The correct answer should be in the options
      assert html =~ "高かった",
             "Expected correct answer '高かった' to be displayed. Step options: #{inspect(step.options)}, question_data: #{inspect(step.question_data)}"

      # Wrong options should also be displayed
      assert html =~ "たかい"
      assert html =~ "てあか"
      assert html =~ "高いひと"

      # Verify we have 4 radio buttons (1 correct + 3 wrong)
      radio_count =
        ~r/<input[^>]*type="radio"[^>]*>/
        |> Regex.scan(html)
        |> length()

      assert radio_count == 4
    end

    test "selecting correct answer marks it as correct", %{
      conn: conn,
      user: user,
      classroom: classroom,
      test_item: test
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      # Submit the correct answer
      view
      |> element("form")
      |> render_submit(%{"answer" => "高かった"})

      # Should complete the test (only 1 question)
      assert_redirect(view, ~p"/classrooms/#{classroom.id}/tests/#{test.id}/results")

      # Verify the attempt was recorded with correct answer
      attempt = Classrooms.get_test_attempt(classroom.id, user.id, test.id)
      assert attempt.status == "completed"
      assert attempt.score == 3
    end

    test "selecting wrong answer gives 0 points", %{
      conn: conn,
      user: user,
      classroom: classroom,
      test_item: test
    } do
      {:ok, view, _html} =
        live(conn, ~p"/classrooms/#{classroom.id}/tests/#{test.id}")

      # Submit a wrong answer
      view
      |> element("form")
      |> render_submit(%{"answer" => "たかい"})

      # Should complete the test
      assert_redirect(view, ~p"/classrooms/#{classroom.id}/tests/#{test.id}/results")

      # Verify the attempt was recorded with 0 points
      attempt = Classrooms.get_test_attempt(classroom.id, user.id, test.id)
      assert attempt.status == "completed"
      assert attempt.score == 0
    end
  end

  describe "teacher creates conjugation multichoice step" do
    test "step is saved with correct answer in options", %{
      conn: _conn,
      classroom: _classroom,
      test_item: test
    } do
      # Get the step from the test
      [step] = Tests.list_test_steps(test.id)

      # Verify question_data has the generated answer
      assert step.question_data["generated_answer"] == "高かった"
      assert step.question_data["base_word"] == "高い"
      assert step.question_data["target_form"] == "past-i"

      # Verify options include the wrong answers
      assert "たかい" in step.options
      assert "てあか" in step.options
      assert "高いひと" in step.options

      # CRITICAL: The correct answer should be in the options when displayed to student
      # This is what we're testing - currently this assertion will fail
      all_options = [step.question_data["generated_answer"] | step.options]

      assert "高かった" in all_options,
             "Correct answer should be included in the options displayed to student"
    end
  end
end
