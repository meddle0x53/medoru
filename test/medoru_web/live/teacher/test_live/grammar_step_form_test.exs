defmodule MedoruWeb.Teacher.TestLive.GrammarStepFormTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.TestsFixtures

  describe "grammar step form with pattern builder" do
    setup %{conn: conn} do
      user = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, user)
      test_item = test_fixture(%{creator_id: user.id, test_type: :teacher, status: :draft})
      %{conn: conn, user: user, test_item: test_item}
    end

    test "can add word slot element", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"sentence_validation\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"add_pattern_element\"][phx-value-type=\"word_slot\"]")
      |> render_click()

      # Verify word slot was added
      assert has_element?(view, "span.bg-emerald-500", "Verb")
      assert has_element?(view, "span", "Element 1:")
    end

    test "can add word class element", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"sentence_validation\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"add_pattern_element\"][phx-value-type=\"word_class\"]")
      |> render_click()

      assert has_element?(view, "span.bg-purple-400")
      assert has_element?(view, "span", "Element 1:")
    end

    test "can add literal text element", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"sentence_validation\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"add_pattern_element\"][phx-value-type=\"literal\"]")
      |> render_click()

      # Verify literal element was added (shows "..." when text is empty)
      assert has_element?(view, "span.bg-white", "...")
    end

    test "can remove pattern elements", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"sentence_validation\"]")
      |> render_click()

      # Add multiple elements
      view
      |> element("button[phx-click=\"add_pattern_element\"][phx-value-type=\"word_slot\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"add_pattern_element\"][phx-value-type=\"literal\"]")
      |> render_click()

      # Verify both elements exist
      assert has_element?(view, "span.bg-emerald-500", "Verb")
      assert has_element?(view, "span", "Element 2:")

      # Remove first element
      view
      |> element("button[phx-click=\"remove_pattern_element\"][phx-value-index=\"0\"]")
      |> render_click()

      # First element should be gone
      refute has_element?(view, "span.bg-emerald-500", "Verb")
      assert has_element?(view, "span", "Element 1:")
    end

    test "can save step with pattern to database", %{conn: conn, test_item: test_item} do
      {:ok, view, _html} = live(conn, ~p"/teacher/tests/#{test_item.id}/edit")

      view
      |> element("button", "Add First Step")
      |> render_click()

      view
      |> element("button[phx-value-type=\"sentence_validation\"]")
      |> render_click()

      # Add a word slot
      view
      |> element("button[phx-click=\"add_pattern_element\"][phx-value-type=\"word_slot\"]")
      |> render_click()

      # Fill in question and submit
      html =
        view
        |> form("#step-form", %{"step" => %{"question" => "Write a sentence"}})
        |> render_submit()

      # Check for error messages
      refute html =~ "Failed to save step"

      # Verify step was created in database
      steps = Medoru.Tests.list_test_steps(test_item.id)
      assert length(steps) == 1

      step = hd(steps)
      assert step.question == "Write a sentence"
      assert step.question_type == :sentence_validation

      # Verify pattern was saved as a list
      pattern = step.question_data["pattern"]
      assert is_list(pattern)
      assert length(pattern) == 1
      assert hd(pattern)["type"] == "word_slot"
      assert hd(pattern)["word_type"] == "verb"
    end
  end
end
