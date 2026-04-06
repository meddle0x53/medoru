defmodule MedoruWeb.ClassroomLive.ShowTest do
  use MedoruWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Learning.WordSets

  describe "Classroom Show - Copy Lesson to Word Set" do
    setup %{conn: conn} do
      # Create user and classroom
      user = user_fixture()
      conn = log_in_user(conn, user)
      
      teacher = user_fixture(%{email: "teacher@example.com"})
      
      # Create classroom
      {:ok, classroom} = Classrooms.create_classroom(%{
        name: "Test Classroom",
        description: "A test classroom",
        teacher_id: teacher.id
      })
      
      # Add user as approved member
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, user.id)
      {:ok, _} = Classrooms.approve_membership(membership)
      
      # Create a custom lesson with words (reading type with vocabulary subtype)
      {:ok, lesson} = Content.create_custom_lesson(%{
        title: "Test Lesson",
        description: "A test lesson",
        difficulty: 5,
        lesson_type: "reading",
        lesson_subtype: "vocabulary",
        status: "published",
        creator_id: teacher.id,
        word_count: 3
      })
      
      # Add words to lesson
      word1 = word_fixture(%{text: "日本", meaning: "Japan", reading: "にほん"})
      word2 = word_fixture(%{text: "一", meaning: "one", reading: "いち"})
      word3 = word_fixture(%{text: "二", meaning: "two", reading: "に"})
      
      Content.add_word_to_lesson(lesson.id, word1.id, %{position: 0})
      Content.add_word_to_lesson(lesson.id, word2.id, %{position: 1})
      Content.add_word_to_lesson(lesson.id, word3.id, %{position: 2})
      
      # Publish lesson to classroom
      Content.publish_lesson_to_classroom(lesson.id, classroom.id, teacher.id)
      
      %{conn: conn, user: user, classroom: classroom, lesson: lesson}
    end

    test "shows copy to word set button for vocabulary lessons", %{conn: conn, classroom: classroom} do
      {:ok, view, html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=lessons")
      
      # Should show the copy button
      assert html =~ "Copy words to word set"
      assert has_element?(view, "button[phx-click='open_copy_modal']")
    end

    test "opens confirmation modal when copy button clicked", %{conn: conn, classroom: classroom, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=lessons")
      
      # Click the copy button
      view
      |> element("button[phx-click='open_copy_modal']")
      |> render_click(%{"lesson_id" => lesson.id, "lesson_title" => lesson.title})
      
      # Modal should be visible
      html = render(view)
      assert html =~ "Copy to Word Set"
      assert html =~ "Create a new word set from"
    end

    test "creates word set from lesson when confirmed", %{conn: conn, user: user, classroom: classroom, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=lessons")
      
      # Open modal
      view
      |> element("button[phx-click='open_copy_modal']")
      |> render_click(%{"lesson_id" => lesson.id, "lesson_title" => lesson.title})
      
      # Confirm copy
      view
      |> element("button[phx-click='confirm_copy_lesson']")
      |> render_click()
      
      # Verify word set was created
      result = WordSets.list_user_word_sets(user.id)
      assert result.total_count == 1
      
      word_set = hd(result.word_sets)
      
      # Should redirect to the new word set
      assert_redirect(view, ~p"/words/sets/#{word_set.id}")
      assert word_set.name == lesson.title
      assert word_set.description == lesson.description
      assert word_set.word_count == 3
    end

    test "closes modal when cancel clicked", %{conn: conn, classroom: classroom, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=lessons")
      
      # Open modal
      view
      |> element("button[phx-click='open_copy_modal']")
      |> render_click(%{"lesson_id" => lesson.id, "lesson_title" => lesson.title})
      
      # Cancel
      view
      |> element("button[phx-click='close_copy_modal']")
      |> render_click()
      
      # Modal should be closed
      html = render(view)
      refute html =~ "Create a new word set from"
    end
  end
end
