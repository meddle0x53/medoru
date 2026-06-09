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
      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Test Classroom",
          description: "A test classroom",
          teacher_id: teacher.id
        })

      # Add user as approved member
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, user.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      # Create a custom lesson with words (reading type with vocabulary subtype)
      {:ok, lesson} =
        Content.create_custom_lesson(%{
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

    test "shows copy to word set button for vocabulary lessons", %{
      conn: conn,
      classroom: classroom
    } do
      {:ok, view, html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=lessons")

      # Should show the copy button
      assert html =~ "Copy words to word set"
      assert has_element?(view, "button[phx-click='open_copy_modal']")
    end

    test "opens confirmation modal when copy button clicked", %{
      conn: conn,
      classroom: classroom,
      lesson: lesson
    } do
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

    test "creates word set from lesson when confirmed", %{
      conn: conn,
      user: user,
      classroom: classroom,
      lesson: lesson
    } do
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

  describe "Classroom Show - Chat Tab" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      teacher = user_fixture(%{email: "teacher@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Chat Test Classroom",
          description: "A test classroom",
          teacher_id: teacher.id
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, user.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      {:ok, conn: conn, user: user, classroom: classroom, teacher: teacher}
    end

    test "renders chat tab", %{conn: conn, classroom: classroom} do
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=chat")

      assert html =~ "Chat"
      assert html =~ "Type a message"
    end

    test "sends a plaintext message in classroom chat", %{conn: conn, classroom: classroom} do
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=chat")

      # Send a message via the event (simulating the JS hook)
      view
      |> element("#classroom-chat-input")
      |> render_hook("send_message", %{"content" => "Hello classroom!"})

      html = render(view)
      assert html =~ "Hello classroom!"
    end

    test "shows teacher badge for teacher messages", %{
      conn: conn,
      classroom: classroom,
      teacher: teacher
    } do
      # Teacher sends a message
      conversation = Medoru.Chat.get_classroom_conversation(classroom.id)
      Medoru.Chat.store_plaintext_message(conversation.id, teacher.id, "Teacher message here")

      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=chat")

      assert html =~ "Teacher message here"
      assert html =~ "Teacher"
    end

    test "sends /grammar command and renders grammar preview", %{
      conn: conn,
      classroom: classroom
    } do
      grammar_definition_fixture(%{title: "te-form pattern", jlpt_level: 5})

      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=chat")

      view
      |> element("#classroom-chat-input")
      |> render_hook("send_message", %{"content" => "/grammar te-form pattern"})

      html = render(view)
      assert html =~ "te-form pattern"
      assert html =~ "/grammars/"
    end

    test "rejects invalid /grammar command with flash error", %{
      conn: conn,
      classroom: classroom
    } do
      {:ok, view, _html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=chat")

      html =
        view
        |> element("#classroom-chat-input")
        |> render_hook("send_message", %{"content" => "/grammar nonexistent-pattern"})

      assert html =~ "Invalid command or not found"
    end

    test "renders inline grammar link \\text/ when grammar exists", %{
      conn: conn,
      classroom: classroom
    } do
      grammar_definition_fixture(%{title: "na-adjective", jlpt_level: 5})
      conversation = Medoru.Chat.get_classroom_conversation(classroom.id)
      Medoru.Chat.store_plaintext_message(conversation.id, classroom.teacher_id, "Learn \\na-adjective/ today")

      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=chat")

      assert html =~ "na-adjective"
      assert html =~ "/grammars/"
    end

    test "renders plain text for unknown inline grammar \\text/", %{
      conn: conn,
      classroom: classroom
    } do
      conversation = Medoru.Chat.get_classroom_conversation(classroom.id)
      Medoru.Chat.store_plaintext_message(conversation.id, classroom.teacher_id, "Try \\onexistent/ grammar")

      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=chat")

      assert html =~ "\\onexistent/"
    end
  end

  describe "Classroom Theme" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      teacher = user_fixture(%{email: "teacher@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Themed Classroom",
          description: "A themed classroom",
          teacher_id: teacher.id,
          theme: "cupcake"
        })

      {:ok, membership} = Classrooms.apply_to_join(classroom.id, user.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      %{conn: conn, user: user, classroom: classroom}
    end

    test "applies data-theme attribute when classroom has a theme", %{
      conn: conn,
      classroom: classroom
    } do
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}")
      assert html =~ ~s(data-theme="cupcake")
    end

    test "does not apply data-theme when classroom has no theme", %{
      conn: _conn
    } do
      teacher = user_fixture(%{email: "teacher2@example.com"})

      {:ok, classroom} =
        Classrooms.create_classroom(%{
          name: "Default Classroom",
          description: "No theme",
          teacher_id: teacher.id
        })

      user = user_fixture(%{email: "member@example.com"})
      conn = log_in_user(build_conn(), user)
      {:ok, membership} = Classrooms.apply_to_join(classroom.id, user.id)
      {:ok, _} = Classrooms.approve_membership(membership)

      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}")
      # The root layout has data-theme on <html>, but the classroom wrapper should not
      refute html =~ ~s(class="max-w-6xl mx-auto px-4 py-8" data-theme=)
    end
  end
end
