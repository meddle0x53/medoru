defmodule MedoruWeb.Teacher.GrammarLessonLiveTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.ContentFixtures

  alias Medoru.Content

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
      |> element("button[phx-click='add_step'][phx-value-type='grammar']", "Grammar")
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
      view
      |> element("button[phx-click='add_step'][phx-value-type='grammar']", "Grammar")
      |> render_click()

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
      view
      |> element("button[phx-click='add_step'][phx-value-type='grammar']", "Grammar")
      |> render_click()

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
      view
      |> element("button[phx-click='add_step'][phx-value-type='grammar']", "Grammar")
      |> render_click()

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

    test "opens grammar definition modal", %{conn: conn, user: user} do
      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      html =
        view
        |> element("button[phx-click='open_grammar_def_modal']")
        |> render_click()

      assert html =~ "Add from Grammar Definition"
      assert html =~ "Search grammar definitions"
    end

    test "searches and selects grammar definition in modal", %{conn: conn, user: user} do
      grammar = grammar_definition_fixture(%{title: "te-form pattern", jlpt_level: 5})

      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      # Open modal
      view
      |> element("button[phx-click='open_grammar_def_modal']")
      |> render_click()

      # Search
      html =
        view
        |> form("form[phx-change='update_grammar_def_search']")
        |> render_change(%{search: %{query: "te-form"}})

      assert html =~ "te-form"

      # Submit search
      html =
        view
        |> form("form[phx-submit='search_grammar_definitions']")
        |> render_submit()

      assert html =~ "te-form pattern"
      assert html =~ "N5"

      # Select grammar
      html =
        view
        |> element("button[phx-click='select_grammar_definition'][phx-value-id='#{grammar.id}']")
        |> render_click()

      assert html =~ "te-form pattern"
      assert html =~ "Add as Step"
    end

    test "adds grammar definition as a new step", %{conn: conn, user: user} do
      grammar =
        grammar_definition_fixture(%{
          title: "te-form pattern",
          jlpt_level: 5,
          pattern_elements: [
            %{"type" => "word_slot", "word_type" => "verb", "forms" => ["te-form"]},
            %{"type" => "literal", "text" => "いる"}
          ],
          examples: [
            %{"sentence" => "食べている", "reading" => "たべている", "meaning" => "eating"}
          ]
        })

      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      # Open modal, search, and select grammar
      view
      |> element("button[phx-click='open_grammar_def_modal']")
      |> render_click()

      view
      |> form("form[phx-change='update_grammar_def_search']")
      |> render_change(%{search: %{query: "te-form"}})

      view
      |> form("form[phx-submit='search_grammar_definitions']")
      |> render_submit()

      view
      |> element("button[phx-click='select_grammar_definition'][phx-value-id='#{grammar.id}']")
      |> render_click()

      # Add as step
      html =
        view
        |> element("button[phx-click='add_from_grammar_definition']")
        |> render_click()

      # Should have a new step with grammar data populated
      assert html =~ "te-form pattern"
      # Modal should be closed
      refute html =~ "Add from Grammar Definition"
    end

    test "closes grammar definition modal", %{conn: conn, user: user} do
      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      view
      |> element("button[phx-click='open_grammar_def_modal']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='close_grammar_def_modal']")
        |> render_click()

      refute html =~ "Add from Grammar Definition"
    end

    test "changing lesson word color apply_to does not crash", %{conn: conn, user: user} do
      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      view
      |> element("button[phx-click='add_lesson_word_color']")
      |> render_click()

      # The select is wired to the WordColorApplyTo hook, which pushes the event
      # with index, field, and apply_to metadata.
      html =
        render_hook(view, "update_lesson_word_color", %{
          index: "0",
          field: "apply_to",
          apply_to: "examples"
        })

      assert html =~ "Examples only"
    end

    test "changing step word color apply_to does not crash", %{conn: conn, user: user} do
      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      view
      |> element("button[phx-click='add_step'][phx-value-type='grammar']", "Grammar")
      |> render_click()

      view
      |> element("button[phx-click='add_step_word_color']")
      |> render_click()

      html =
        render_hook(view, "update_step_word_color", %{
          index: "0",
          field: "apply_to",
          apply_to: "explanation"
        })

      assert html =~ "Explanation only"
    end

    test "text step can have examples without pattern validation", %{conn: conn, user: user} do
      lesson =
        custom_lesson_fixture(%{
          creator_id: user.id,
          lesson_subtype: "grammar",
          title: "Test Lesson"
        })

      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/#{lesson.id}/edit")

      view
      |> element("button[phx-click='add_step'][phx-value-type='text']", "Text")
      |> render_click()

      # Example editor should be visible for text steps
      assert render(view) =~ "Examples (Max 5)"

      view
      |> element("button[phx-click='add_example']", "Add")
      |> render_click()

      render_hook(view, "update_example", %{
        index: "0",
        field: "sentence",
        value: "今日は寒いです"
      })

      render_hook(view, "update_example", %{
        index: "0",
        field: "reading",
        value: "きょうはさむいです"
      })

      render_hook(view, "update_example", %{
        index: "0",
        field: "meaning",
        value: "Today is cold"
      })

      # Save the step
      view
      |> element("button[phx-click='save_step']", "Save Step")
      |> render_click()

      assert render(view) =~ "Step saved successfully"

      # Verify the step was saved with the example
      [step] = Content.list_grammar_lesson_steps(lesson.id)
      assert step.step_type == "text"
      assert length(step.examples) == 1
      assert hd(step.examples)["sentence"] == "今日は寒いです"
      assert hd(step.examples)["reading"] == "きょうはさむいです"
      assert hd(step.examples)["meaning"] == "Today is cold"
    end
  end
end
