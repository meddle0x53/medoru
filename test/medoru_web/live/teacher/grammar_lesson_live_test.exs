defmodule MedoruWeb.Teacher.GrammarLessonLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.ContentFixtures

  setup %{conn: conn} do
    user = user_fixture(%{type: "teacher"})
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "grammar lesson index" do
    test "shows share link for published grammar lessons", %{conn: conn, user: user} do
      # Create a published grammar lesson with a step
      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Published Grammar Lesson",
          status: "published"
        })

      # Create a grammar step
      grammar_lesson_step_fixture(%{
        custom_lesson: lesson,
        title: "Test Step",
        position: 0
      })

      {:ok, _view, html} = live(conn, ~p"/teacher/grammar-lessons")

      # Should show the lesson title
      assert html =~ "Published Grammar Lesson"

      # Should show the share link for published lessons
      assert html =~ "hero-share"
    end

    test "does not show share link for draft grammar lessons", %{conn: conn, user: user} do
      # Create a draft grammar lesson
      _lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Draft Grammar Lesson",
          status: "draft"
        })

      {:ok, _view, html} = live(conn, ~p"/teacher/grammar-lessons")

      # Should show the lesson title
      assert html =~ "Draft Grammar Lesson"

      # Should not show the share link for draft lessons
      refute html =~ "hero-share"
    end
  end

  describe "grammar lesson form" do
    test "word slot bubble updates when changing word type", %{conn: conn, user: user} do
      # Create a grammar lesson
      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      # Add a step
      view
      |> element("button", "Add Step")
      |> render_click()

      # Add a word slot
      view
      |> element("button[phx-value-type='word_slot']", "Add Word")
      |> render_click()

      # Initial bubble should show VERB
      html = render(view)
      assert html =~ "VERB"

      # Change word type to noun - using form
      view
      |> form("form[phx-change='update_element_word_type']", %{index: "0", value: "noun"})
      |> render_change()

      # Bubble should now show NOUN
      html = render(view)
      assert html =~ "NOUN"
      refute html =~ "VERB"
    end

    test "word slot bubble shows form when selected", %{conn: conn, user: user} do
      # Seed grammar forms
      grammar_form_fixture(%{
        name: "masu-form",
        display_name: "Polite (ます)",
        word_type: "verb"
      })

      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      # Add a step and word slot
      view |> element("button", "Add Step") |> render_click()
      view |> element("button[phx-value-type='word_slot']", "Add Word") |> render_click()

      # Select a form using form
      view
      |> form("form[phx-change='update_element_form']", %{index: "0", value: "masu-form"})
      |> render_change()

      # Bubble should show VERB with hiragana from display_name (e.g., "VERB-Polite (ます)")
      html = render(view)
      assert html =~ "VERB-"
      assert html =~ "ます"
    end

    test "word class bubble updates when selected", %{conn: conn, user: user} do
      # Create a word class
      word_class =
        word_class_fixture(%{
          name: "time",
          display_name: "Time Words",
          description: "Words related to time"
        })

      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      # Add a step and word class element
      view |> element("button", "Add Step") |> render_click()
      view |> element("button[phx-value-type='word_class']", "Add Word Class") |> render_click()

      # Initially shows "Select..."
      html = render(view)
      assert html =~ "Select..."

      # Select the word class using form
      view
      |> form("form[phx-change='update_element_word_class']", %{index: "0", value: word_class.id})
      |> render_change()

      # Bubble should now show the class name
      html = render(view)
      assert html =~ "Time Words"
    end

    test "literal text bubble updates", %{conn: conn, user: user} do
      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      # Add a step and literal element
      view |> element("button", "Add Step") |> render_click()
      view |> element("button[phx-value-type='literal']", "Add Text") |> render_click()

      # Initially shows "..."
      html = render(view)
      assert html =~ "..."

      # Type text using form (no debounce in test)
      view
      |> form("form[phx-change='update_element_text']", %{index: "0", value: "まえに、"})
      |> render_change()

      # Bubble should show the text
      html = render(view)
      assert html =~ "まえに、"
    end
  end
end
