defmodule MedoruWeb.ClassroomLive.TestResultsTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Medoru.{Accounts, Classrooms, Tests}
  alias MedoruWeb.ClassroomLive.TestResults

  @examples ["例 あそこで しゃしん（はい）\nあそこで写真を撮ってもいいですか。\n……はい、撮ってもいいです。"]

  defp mqa_step(question, examples, requirement) do
    %{
      question_type: :grammar_make_question_answer,
      question: question,
      question_data: %{"requirement" => requirement, "examples" => examples}
    }
  end

  defp mqa_result(index, step, user_answer) do
    %{
      index: index,
      step: step,
      user_answer: user_answer,
      correct_answer: "N/A",
      review_lines: nil,
      is_correct: true,
      points_earned: 10,
      points_possible: 10,
      explanation: nil
    }
  end

  defp other_result(index) do
    %{
      index: index,
      step: %{question_type: :multichoice, question: "Pick one", question_data: %{}},
      user_answer: "a",
      correct_answer: "a",
      review_lines: nil,
      is_correct: true,
      points_earned: 1,
      points_possible: 1,
      explanation: nil
    }
  end

  describe "group_results_for_export/1" do
    test "groups consecutive make-question-answer steps with identical question and examples" do
      step = mqa_step("Make a question", @examples, "req1")

      results = [
        mqa_result(0, step, "q1\na1"),
        mqa_result(1, mqa_step("Make a question", @examples, "req2"), "q2\na2")
      ]

      assert [%{type: :make_question_answer, items: items}] =
               TestResults.group_results_for_export(results)

      assert length(items) == 2
    end

    test "splits groups when examples differ" do
      results = [
        mqa_result(0, mqa_step("Q", ["例A"], "r1"), "q\na"),
        mqa_result(1, mqa_step("Q", ["例B"], "r2"), "q\na")
      ]

      assert [g1, g2] = TestResults.group_results_for_export(results)
      assert g1.examples == ["例A"]
      assert g2.examples == ["例B"]
    end

    test "splits groups when question differs" do
      results = [
        mqa_result(0, mqa_step("Q1", @examples, "r1"), "q\na"),
        mqa_result(1, mqa_step("Q2", @examples, "r2"), "q\na")
      ]

      assert [g1, g2] = TestResults.group_results_for_export(results)
      assert g1.question == "Q1"
      assert g2.question == "Q2"
    end

    test "non-consecutive identical groups stay separate" do
      step = mqa_step("Q", @examples, "req")

      results = [
        mqa_result(0, step, "q1\na1"),
        other_result(1),
        mqa_result(2, mqa_step("Q", @examples, "req"), "q2\na2")
      ]

      assert [g1, single, g2] = TestResults.group_results_for_export(results)
      assert g1.type == :make_question_answer
      assert single.type == :single
      assert g2.type == :make_question_answer
    end

    test "other step types pass through as singletons" do
      assert [%{type: :single, result: result}] =
               TestResults.group_results_for_export([other_result(0)])

      assert result.step.question == "Pick one"
    end
  end

  describe "results page export panel" do
    setup %{conn: conn} do
      {:ok, teacher} =
        Accounts.register_user_with_oauth(%{
          email: "teacher-export@example.com",
          provider: "google",
          provider_uid: "teacher-export"
        })

      {:ok, student} =
        Accounts.register_user_with_oauth(%{
          email: "student-export@example.com",
          provider: "google",
          provider_uid: "student-export"
        })

      {:ok, classroom} =
        Classrooms.create_classroom(%{name: "Export Classroom", teacher_id: teacher.id})

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      {:ok, test_resource} =
        Tests.create_test(%{
          title: "Export Test",
          description: "export",
          creator_id: teacher.id,
          test_type: :teacher,
          status: :published,
          total_points: 20,
          time_limit_seconds: 600
        })

      question_data = %{
        "requirement" => "あそこで しゃしん（はい）",
        "expected_question" => "あそこで写真を撮ってもいいですか。",
        "expected_answer" => "はい、撮ってもいいです。",
        "expected_question_reading" => "あそこでしゃしんをとってもいいですか",
        "expected_answer_reading" => "はいとってもいいです",
        "examples" => @examples
      }

      for {order, requirement} <- [{0, "あそこで しゃしん（はい）"}, {1, "ここで しゃしん（はい）"}] do
        {:ok, _step} =
          Tests.create_test_step(test_resource, %{
            question: "Make a question in the pattern and answer it",
            question_type: :grammar_make_question_answer,
            step_type: :grammar,
            order_index: order,
            question_data: Map.put(question_data, "requirement", requirement),
            options: [],
            correct_answer: "N/A",
            points: 10,
            kanji_id: nil,
            word_id: nil
          })
      end

      {:ok, _classroom_test} =
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

      {:ok, conn: log_in_user(conn, student), classroom: classroom, test_resource: test_resource}
    end

    test "export panel groups shared examples and renders export buttons", %{
      conn: conn,
      classroom: classroom,
      test_resource: test_resource
    } do
      {:ok, view, _html} = live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      for _ <- ["あそこで しゃしん（はい）", "ここで しゃしん（はい）"] do
        view
        |> form("form[phx-submit='submit_answer']", %{
          make_question_answer: %{
            question: "あそこでしゃしんをとってもいいですか。",
            answer: "はい、とってもいいです。"
          }
        })
        |> render_submit()
      end

      {:ok, _results_view, html} =
        live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      assert html =~ "test-results-export"

      # Examples block renders exactly once even though both steps share it
      example_line = "あそこで写真を撮ってもいいですか。"
      assert html |> String.split(example_line) |> length() == 2

      assert html =~ "あそこで しゃしん（はい）"
      assert html =~ "ここで しゃしん（はい）"

      # Export buttons
      assert html =~ "Download image"
      assert html =~ "Print / Save as PDF"
      assert html =~ ~s(data-share-target="test-results-export")
    end

    test "preview toggle shows and hides the export panel", %{
      conn: conn,
      classroom: classroom,
      test_resource: test_resource
    } do
      {:ok, view, _html} = live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}")

      for _ <- 1..2 do
        view
        |> form("form[phx-submit='submit_answer']", %{
          make_question_answer: %{
            question: "あそこでしゃしんをとってもいいですか。",
            answer: "はい、とってもいいです。"
          }
        })
        |> render_submit()
      end

      {:ok, view, _html} =
        live(conn, "/classrooms/#{classroom.id}/tests/#{test_resource.id}/results")

      html = view |> element("button", "Preview export") |> render_click()
      assert html =~ "test-results-export-wrapper mt-8"

      html = view |> element("button", "Preview export") |> render_click()
      assert html =~ "export-panel-hidden"
    end
  end
end
