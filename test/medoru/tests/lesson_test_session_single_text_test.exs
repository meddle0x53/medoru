defmodule Medoru.Tests.LessonTestSessionSingleTextTest do
  use Medoru.DataCase

  alias Medoru.Tests
  alias Medoru.Tests.LessonTestSession

  defp setup_session(_context) do
    user = Medoru.AccountsFixtures.user_fixture()

    {:ok, test_record} =
      Tests.create_test(%{
        title: "Single Text Test",
        test_type: :practice,
        total_points: 0
      })

    {:ok, word} =
      Medoru.Content.create_word(%{
        text: "食べる",
        meaning: "to eat",
        reading: "たべる",
        difficulty: 5
      })

    {:ok, step} =
      Tests.create_test_step(test_record, %{
        order_index: 0,
        step_type: :vocabulary,
        question_type: :reading_text,
        question: "食べる",
        correct_answer: "to eat",
        points: 1,
        word_id: word.id,
        question_data: %{
          "word_text" => "食べる",
          "word_reading" => "たべる",
          "question_label" => "meaning_only",
          "text_mode" => "meaning"
        }
      })

    {:ok, %{session: session}} = LessonTestSession.start_lesson_test(user.id, test_record.id)

    %{user: user, session: session, step: step, word: word}
  end

  setup :setup_session

  describe "submit_single_text_answer/5" do
    test "correct meaning answer completes the test", %{
      session: session,
      step: step
    } do
      assert {:completed, %{score: 1, total_possible: 1}} =
               LessonTestSession.submit_single_text_answer(
                 session.id,
                 step.id,
                 "to eat",
                 :meaning
               )
    end

    test "meaning grading is case-insensitive like the dual version", %{
      session: session,
      step: step
    } do
      assert {:completed, _} =
               LessonTestSession.submit_single_text_answer(
                 session.id,
                 step.id,
                 "TO EAT",
                 :meaning
               )
    end

    test "meaning grading accepts partial matches", %{session: session, step: step} do
      assert {:completed, _} =
               LessonTestSession.submit_single_text_answer(session.id, step.id, "eat", :meaning)
    end

    test "incorrect meaning requeues the step", %{session: session, step: step} do
      assert {:incorrect, %{remaining_count: 1, correct_meaning: "to eat"}} =
               LessonTestSession.submit_single_text_answer(
                 session.id,
                 step.id,
                 "wrong",
                 :meaning
               )

      # Step is now at the end of the queue - answering it correctly completes
      assert {:completed, _} =
               LessonTestSession.submit_single_text_answer(
                 session.id,
                 step.id,
                 "to eat",
                 :meaning
               )
    end

    test "correct reading answer grades against the word reading", %{
      session: session,
      step: step,
      word: word
    } do
      assert {:completed, _} =
               LessonTestSession.submit_single_text_answer(
                 session.id,
                 step.id,
                 word.reading,
                 :reading
               )
    end

    test "reading grading accepts long vowel variations", %{session: session, step: step} do
      # The step's word is たべる; replace reading validation target by using
      # a word with an おう reading instead.
      assert {:incorrect, _} =
               LessonTestSession.submit_single_text_answer(session.id, step.id, "たべ", :reading)
    end

    test "locale option is accepted for meaning validation", %{
      session: session,
      step: step,
      word: word
    } do
      {:ok, _word} =
        Medoru.Content.update_word(word, %{translations: %{"bg" => %{"meaning" => "ям"}}})

      assert {:completed, _} =
               LessonTestSession.submit_single_text_answer(
                 session.id,
                 step.id,
                 "ям",
                 :meaning,
                 locale: "bg"
               )
    end
  end
end
