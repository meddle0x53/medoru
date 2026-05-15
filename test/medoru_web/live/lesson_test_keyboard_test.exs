defmodule MedoruWeb.LessonTestKeyboardTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.{AccountsFixtures, ContentFixtures}

  describe "keyboard shortcuts" do
    setup do
      user = user_fixture()
      lesson = lesson_with_words_fixture(%{word_count: 3})
      %{user: user, lesson: lesson}
    end

    test "phx-window-keydown is present in rendered HTML", %{
      conn: conn,
      user: user,
      lesson: lesson
    } do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/lessons/#{lesson.id}/test")

      assert html =~ "phx-window-keydown=\"handle_key\""
    end

    test "pressing 1 selects first option", %{conn: conn, user: user, lesson: lesson} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/lessons/#{lesson.id}/test")

      # Wait for the live view to be fully connected and render
      html = render(view)
      assert html =~ "phx-window-keydown=\"handle_key\""

      # Send a window keydown event for "1"
      # In LiveViewTest, we can use render_hook or element().render_keydown
      # But for window events, we need to use render_hook on the view itself
      html = render_hook(view, "handle_key", %{"key" => "1"})

      # After pressing 1, the first option should be selected (marked with border-primary bg-primary/5)
      # We can check if the selected_answer state changed by looking at the re-rendered HTML
      assert html =~ "border-primary bg-primary/5"
    end
  end
end
