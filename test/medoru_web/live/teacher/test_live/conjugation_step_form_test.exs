defmodule MedoruWeb.Teacher.TestLive.ConjugationStepFormTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.TestsFixtures

  alias Medoru.Content

  describe "conjugation step form" do
    setup %{conn: conn} do
      user = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, user)
      test_item = test_fixture(%{creator_id: user.id, test_type: :teacher, status: :draft})

      # Seed grammar forms for conjugation
      {:ok, te_form} =
        Content.create_grammar_form(%{
          name: "te-form",
          display_name: "Te-form (て形)",
          word_type: "verb",
          suffix_pattern: "て",
          description: "Te-form for connecting verbs"
        })

      {:ok, ta_form} =
        Content.create_grammar_form(%{
          name: "ta-form",
          display_name: "Ta-form (た形)",
          word_type: "verb",
          suffix_pattern: "た",
          description: "Past affirmative form"
        })

      {:ok, _nai_form} =
        Content.create_grammar_form(%{
          name: "nai-form",
          display_name: "Nai-form (ない形)",
          word_type: "verb",
          suffix_pattern: "ない",
          description: "Negative plain form"
        })

      {:ok, _adj_te_form} =
        Content.create_grammar_form(%{
          name: "te-form",
          display_name: "Te-form (て形)",
          word_type: "adjective",
          suffix_pattern: "くて",
          description: "Te-form for adjectives"
        })

      # Grammar form for adjective past tense
      {:ok, adj_past} =
        Content.create_grammar_form(%{
          name: "past",
          display_name: "Past (かった)",
          word_type: "adjective",
          suffix_pattern: "かった",
          description: "Past affirmative form for i-adjectives"
        })

      # Seed some words for testing
      {:ok, verb} =
        Content.create_word(%{
          text: "食べる",
          reading: "たべる",
          meaning: "to eat",
          word_type: "verb",
          difficulty: 5,
          usage_frequency: 100
        })

      {:ok, adjective} =
        Content.create_word(%{
          text: "大きい",
          reading: "おおきい",
          meaning: "big",
          word_type: "adjective",
          difficulty: 5,
          usage_frequency: 100
        })

      %{
        conn: conn,
        user: user,
        test_item: test_item,
        verb: verb,
        adjective: adjective,
        te_form: te_form,
        ta_form: ta_form,
        adj_past: adj_past
      }
    end

    test "can open conjugation step form", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"conjugation\"]")
      |> render_click()

      # Verify the form is displayed
      assert has_element?(view, "h3", "New conjugation Step")
      assert has_element?(view, "input#step_question")
      assert has_element?(view, "input#correct_answer")
    end

    test "can toggle auto-generate checkbox on", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"conjugation\"]")
      |> render_click()

      # Initially checkbox should be unchecked (manual form visible)
      assert has_element?(view, "input#base_word")

      # Toggle checkbox on via click event
      view
      |> element("input#auto_generate_checkbox")
      |> render_click()

      # Now auto-generate UI should be visible (word type selector)
      assert has_element?(view, "select#word_type")
    end

    test "can toggle auto-generate checkbox off", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"conjugation\"]")
      |> render_click()

      # Toggle on first
      view
      |> element("input#auto_generate_checkbox")
      |> render_click()

      assert has_element?(view, "select#word_type")

      # Toggle off
      view
      |> element("input#auto_generate_checkbox")
      |> render_click()

      # Manual form should be visible again
      assert has_element?(view, "input#base_word")
    end

    test "can select word type in auto-generate mode", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"conjugation\"]")
      |> render_click()

      # Enable auto-generate
      view
      |> element("input#auto_generate_checkbox")
      |> render_click()

      # Select word type
      view
      |> form("#step-form", %{"step" => %{"question_data" => %{"word_type" => "verb"}}})
      |> render_change(%{"_target" => ["step", "question_data", "word_type"]})

      # Search field should now be visible
      assert has_element?(view, "input#base_word_search")
    end

    test "searching for words shows results", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"conjugation\"]")
      |> render_click()

      # Enable auto-generate and select word type
      view
      |> element("input#auto_generate_checkbox")
      |> render_click()

      view
      |> form("#step-form", %{"step" => %{"question_data" => %{"word_type" => "verb"}}})
      |> render_change(%{"_target" => ["step", "question_data", "word_type"]})

      # Search for a word - directly target the input with phx-change
      view
      |> element("input#base_word_search")
      |> render_change(%{
        "step" => %{"question_data" => %{"base_word_search" => "食"}},
        "_target" => ["step", "question_data", "base_word_search"]
      })

      # Results should be shown
      assert has_element?(view, "button[phx-click=\"select_conjugation_word\"]")
    end

    test "auto-generate works for i-adjectives", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"conjugation\"]")
      |> render_click()

      # Enable auto-generate
      view
      |> element("input#auto_generate_checkbox")
      |> render_click()

      # Select adjective type
      view
      |> form("#step-form", %{"step" => %{"question_data" => %{"word_type" => "adjective"}}})
      |> render_change(%{"_target" => ["step", "question_data", "word_type"]})

      # Search for adjective
      view
      |> element("input#base_word_search")
      |> render_change(%{
        "step" => %{"question_data" => %{"base_word_search" => "大"}},
        "_target" => ["step", "question_data", "base_word_search"]
      })

      # Verify search results appear
      assert has_element?(view, "button[phx-click=\"select_conjugation_word\"]")

      # Select the adjective
      view
      |> element("button[phx-click=\"select_conjugation_word\"]")
      |> render_click()

      # Select past form
      view
      |> element("select#target_form")
      |> render_change(%{
        "step" => %{"question_data" => %{"target_form" => "past"}},
        "_target" => ["step", "question_data", "target_form"]
      })

      # Verify the generated question and answer are correct
      assert has_element?(view, "input[value=\"大きかった\"]")
    end

    test "can save conjugation step with manual entry", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"conjugation\"]")
      |> render_click()

      # Fill manual form
      view
      |> form("#step-form", %{
        "step" => %{
          "question" => "Conjugate this verb",
          "correct_answer" => "食べて",
          "question_data" => %{
            "base_word" => "食べる",
            "word_type" => "verb",
            "target_form" => "te-form"
          }
        }
      })
      |> render_submit()

      # Verify step was created
      steps = Medoru.Tests.list_test_steps(test_item.id)
      assert length(steps) == 1

      step = hd(steps)
      assert step.question == "Conjugate this verb"
      assert step.correct_answer == "食べて"
      assert step.question_type == :conjugation
    end

    test "conjugation multichoice shows auto-generate UI without checkbox", %{
      conn: conn,
      test_item: test_item
    } do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      # Select conjugation_multichoice type
      view
      |> element("button[phx-value-type=\"conjugation_multichoice\"]")
      |> render_click()

      # No checkbox should be present - auto-generate is always enabled
      refute has_element?(view, "input#auto_generate_checkbox")

      # Select verb type
      view
      |> form("#step-form", %{"step" => %{"question_data" => %{"word_type" => "verb"}}})
      |> render_change(%{"_target" => ["step", "question_data", "word_type"]})

      # Search for verb
      view
      |> element("input#base_word_search")
      |> render_change(%{
        "step" => %{"question_data" => %{"base_word_search" => "食"}},
        "_target" => ["step", "question_data", "base_word_search"]
      })

      # Select the verb
      view
      |> element("button[phx-click=\"select_conjugation_word\"]")
      |> render_click()

      # Select te-form
      view
      |> element("select#target_form")
      |> render_change(%{
        "step" => %{"question_data" => %{"target_form" => "te-form"}},
        "_target" => ["step", "question_data", "target_form"]
      })

      # Verify the correct answer was generated (hidden input)
      assert has_element?(view, "input[value=\"食べて\"]")

      # The wrong answers section should now be visible
      assert has_element?(view, "button", "Add")

      # Verify the wrong answers section has the input and button
      assert has_element?(view, "input#new-wrong-option")
      assert has_element?(view, "button[phx-click=\"add_option\"]")

      # Verify correct answer is shown
      html = render(view)
      assert html =~ "Correct:"
      assert html =~ "食べて"
    end
  end
end
