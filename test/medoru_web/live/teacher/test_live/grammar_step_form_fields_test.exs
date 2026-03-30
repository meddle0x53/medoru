defmodule MedoruWeb.Teacher.TestLive.GrammarStepFormFieldsTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.TestsFixtures

  describe "grammar step form - typing in all fields" do
    setup %{conn: conn} do
      user = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, user)
      test_item = test_fixture(%{creator_id: user.id, test_type: :teacher, status: :draft})
      %{conn: conn, user: user, test_item: test_item}
    end

    test "can type in question field without error", %{conn: conn, test_item: test_item} do
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

      # Type in question field
      result =
        view
        |> form("#step-form", %{"step" => %{"question" => "Test question"}})
        |> render_change(%{"_target" => ["step", "question"]})

      assert is_binary(result)
      assert has_element?(view, "input[value=\"Test question\"]")
    end

    test "can type in hints field without error", %{conn: conn, test_item: test_item} do
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

      # Type in hints field
      result =
        view
        |> form("#step-form", %{"step" => %{"hints" => "Some hint"}})
        |> render_change(%{"_target" => ["step", "hints"]})

      assert is_binary(result)
    end

    test "can type in explanation field without error", %{conn: conn, test_item: test_item} do
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

      # Type in explanation field
      result =
        view
        |> form("#step-form", %{"step" => %{"explanation" => "Some explanation"}})
        |> render_change(%{"_target" => ["step", "explanation"]})

      assert is_binary(result)
    end
  end
end
