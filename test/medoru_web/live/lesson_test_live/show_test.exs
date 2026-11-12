defmodule MedoruWeb.LessonTestLive.ShowTest do
  @moduledoc """
  Tests for rendering and answer handling of the meaning-first step types
  (meaning_to_word multichoice, meaning_to_text typed) in the lesson test
  LiveView.
  """

  use MedoruWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}

  alias Medoru.Repo
  alias Medoru.Tests
  alias Medoru.Tests.TestStep

  defp meaning_step_attrs(word, type) do
    base = %{
      step_type: :vocabulary,
      question: "umbrella holder",
      correct_answer: "#{word.text} / #{word.reading}",
      points: 2,
      word_id: word.id,
      question_data: %{
        "type" => type,
        "word_text" => word.text,
        "word_reading" => word.reading,
        "meaning_indices" => [],
        "question_label" => "word",
        "word_id" => word.id
      }
    }

    case type do
      "meaning_to_word" ->
        Map.merge(base, %{
          question_type: :multichoice,
          options: ["#{word.text} / #{word.reading}", "ほん / ほん"]
        })

      "meaning_to_text" ->
        Map.merge(base, %{
          question_type: :reading_text,
          options: [],
          question_data: Map.merge(base.question_data, %{"text_mode" => "word_or_reading"})
        })
    end
  end

  # The lesson test LiveView regenerates the test on mount, so deterministic
  # meaning-first steps are injected into the DB as the second step of the
  # session queue; skipping the first step loads them fresh from the DB.
  defp inject_meaning_step!(lesson, user, attrs) do
    lesson = Medoru.Content.get_lesson!(lesson.id)
    test = Tests.get_test!(lesson.test_id)
    session = Tests.get_active_session(user.id, test.id)

    [_first, second_id | _] = session.metadata["step_queue"]

    step =
      TestStep
      |> Repo.get!(second_id)
      |> Ecto.Changeset.change(attrs)
      |> Repo.update!()

    step
  end

  defp skip_first_step(view) do
    view
    |> element("button", "Skip")
    |> render_click()
  end

  describe "meaning-first step types" do
    setup do
      user = user_fixture()
      lesson = lesson_with_words_fixture(%{word_count: 2})
      word = word_fixture(%{text: "かさ", meaning: "umbrella holder", reading: "かさ"})

      %{user: user, lesson: lesson, word: word}
    end

    test "meaning_to_word renders the meaning prompt without leaking the word", %{
      conn: conn,
      user: user,
      lesson: lesson,
      word: word
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/test")

      inject_meaning_step!(lesson, user, meaning_step_attrs(word, "meaning_to_word"))
      skip_first_step(view)

      html = render(view)
      assert html =~ "umbrella holder"
      assert html =~ "かさ / かさ"
      refute html =~ "Reading:"
    end

    test "meaning_to_word selected option is graded correct", %{
      conn: conn,
      user: user,
      lesson: lesson,
      word: word
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/test")

      step = inject_meaning_step!(lesson, user, meaning_step_attrs(word, "meaning_to_word"))
      skip_first_step(view)

      view
      |> element("button", "#{word.text} / #{word.reading}")
      |> render_click()

      view
      |> element("button", "Submit Answer")
      |> render_click()

      assert render(view) =~ "Correct!"

      answer =
        Medoru.Tests.TestStepAnswer
        |> where([a], a.test_step_id == ^step.id)
        |> Repo.one!()

      assert answer.is_correct
    end

    test "meaning_to_text renders a single input and accepts the word text", %{
      conn: conn,
      user: user,
      lesson: lesson,
      word: word
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/test")

      step = inject_meaning_step!(lesson, user, meaning_step_attrs(word, "meaning_to_text"))
      skip_first_step(view)

      html = render(view)
      assert html =~ "umbrella holder"
      assert html =~ "Type the Japanese word"
      refute html =~ "Reading (Hiragana)"

      view
      |> element("input[name='meaning_answer']")
      |> render_change(%{meaning_answer: word.text})

      view
      |> element("button", "Submit Answer")
      |> render_click()

      assert render(view) =~ "Correct!"

      answer =
        Medoru.Tests.TestStepAnswer
        |> where([a], a.test_step_id == ^step.id)
        |> Repo.one!()

      assert answer.is_correct
      assert answer.answer == word.text
    end

    test "meaning_to_text submits via the form on Enter", %{
      conn: conn,
      user: user,
      lesson: lesson,
      word: word
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/test")

      step = inject_meaning_step!(lesson, user, meaning_step_attrs(word, "meaning_to_text"))
      skip_first_step(view)

      view
      |> element("input[name='meaning_answer']")
      |> render_change(%{meaning_answer: word.text})

      view
      |> element("form#meaning-to-text-form")
      |> render_submit(%{})

      assert render(view) =~ "Correct!"

      answer =
        Medoru.Tests.TestStepAnswer
        |> where([a], a.test_step_id == ^step.id)
        |> Repo.one!()

      assert answer.is_correct
      assert answer.answer == word.text
    end

    test "meaning_to_text wrong answer records is_correct false and shows feedback", %{
      conn: conn,
      user: user,
      lesson: lesson,
      word: word
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/test")

      step = inject_meaning_step!(lesson, user, meaning_step_attrs(word, "meaning_to_text"))
      skip_first_step(view)

      view
      |> element("input[name='meaning_answer']")
      |> render_change(%{meaning_answer: "ほん"})

      view
      |> element("button", "Submit Answer")
      |> render_click()

      html = render(view)
      assert html =~ "Incorrect"

      answer =
        Medoru.Tests.TestStepAnswer
        |> where([a], a.test_step_id == ^step.id)
        |> Repo.one!()

      refute answer.is_correct
    end
  end
end
