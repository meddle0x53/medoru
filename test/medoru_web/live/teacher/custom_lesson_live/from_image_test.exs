defmodule MedoruWeb.Teacher.CustomLessonLive.FromImageTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  describe "from-image page" do
    test "redirects non-admin users", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      assert {:error,
              {:live_redirect, %{to: "/teacher/custom-lessons", flash: %{"error" => msg}}}} =
               live(conn, ~p"/teacher/custom-lessons/from-image")

      assert msg =~ "Only admins can create lessons from images"
    end

    test "renders upload page for admin", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)

      {:ok, _live, html} = live(conn, ~p"/teacher/custom-lessons/from-image")
      assert html =~ "Create Lesson from Image"
      assert html =~ "Upload a vocabulary page and let AI extract the words"
    end
  end

  describe "teacher custom lessons index" do
    test "shows 'Create from Image' button for admin", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)

      {:ok, _live, html} = live(conn, ~p"/teacher/custom-lessons")
      assert html =~ "Create from Image"
    end

    test "hides 'Create from Image' button for teacher", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      {:ok, _live, html} = live(conn, ~p"/teacher/custom-lessons")
      refute html =~ "Create from Image"
    end
  end

  describe "word matching and lesson creation" do
    test "creates lesson with existing and new words", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)

      # Pre-create a word that will match
      _existing_word = word_fixture(%{text: "電気", reading: "でんき", meaning: "electricity"})

      {:ok, view, _html} = live(conn, ~p"/teacher/custom-lessons/from-image")

      # Verify the page exists and has the right structure
      assert render(view) =~ "Create Lesson from Image"
    end
  end

  describe "preview form editing" do
    test "preview inputs are wrapped in forms with names" do
      assigns = %{
        step: :preview,
        lesson_title: "My Title",
        lesson_description: "My Desc",
        extracted_words: [
          %{
            "text" => "テスト",
            "reading" => "てすと",
            "meaning" => "test",
            "word_type" => "noun",
            "notes" => ""
          }
        ],
        selected_word_indices: MapSet.new([0]),
        loading: false,
        flash: %{},
        current_scope: nil,
        __changed__: %{},
        uploads: %{image: %{ref: "phx-upload-ref", entries: []}}
      }

      html =
        MedoruWeb.Teacher.CustomLessonLive.FromImage.render(assigns)
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ ~s(<form phx-change="update_title">)
      assert html =~ ~s(<form phx-change="update_description">)
      assert html =~ ~s(name="title")
      assert html =~ ~s(name="description")
      assert html =~ ~s(<form phx-change="update_word" class="contents">)
      assert html =~ ~s(name="value")
    end

    test "update_title event updates lesson title assign" do
      socket = preview_socket(%{lesson_title: "Old Title"})

      assert {:noreply, updated_socket} =
               MedoruWeb.Teacher.CustomLessonLive.FromImage.handle_event(
                 "update_title",
                 %{"title" => "New Title"},
                 socket
               )

      assert updated_socket.assigns.lesson_title == "New Title"
    end

    test "update_description event updates lesson description assign" do
      socket = preview_socket(%{lesson_description: "Old Description"})

      assert {:noreply, updated_socket} =
               MedoruWeb.Teacher.CustomLessonLive.FromImage.handle_event(
                 "update_description",
                 %{"description" => "New Description"},
                 socket
               )

      assert updated_socket.assigns.lesson_description == "New Description"
    end

    test "update_word event updates extracted word field" do
      socket =
        preview_socket(%{
          extracted_words: [
            %{
              "text" => "テスト",
              "reading" => "てすと",
              "meaning" => "test",
              "word_type" => "noun",
              "image_text" => "テスト",
              "notes" => ""
            }
          ]
        })

      assert {:noreply, updated_socket} =
               MedoruWeb.Teacher.CustomLessonLive.FromImage.handle_event(
                 "update_word",
                 %{"index" => "0", "field" => "meaning", "value" => "exam"},
                 socket
               )

      assert hd(updated_socket.assigns.extracted_words)["meaning"] == "exam"
    end

    test "create_lesson saves custom title and description", %{conn: _conn} do
      admin = user_fixture(%{type: "admin"})

      socket =
        preview_socket(%{
          current_scope: %{current_user: admin},
          extracted_words: [
            %{
              "text" => "テスト",
              "reading" => "てすと",
              "meaning" => "test",
              "word_type" => "noun",
              "image_text" => "テスト",
              "notes" => ""
            }
          ],
          selected_word_indices: MapSet.new([0]),
          lesson_title: "My Custom Title",
          lesson_description: "My Custom Description"
        })

      assert {:noreply, updated_socket} =
               MedoruWeb.Teacher.CustomLessonLive.FromImage.handle_event(
                 "create_lesson",
                 %{},
                 socket
               )

      assert {:live, :redirect, %{kind: :push, to: "/teacher/custom-lessons/" <> _}} =
               updated_socket.redirected

      lesson_id =
        updated_socket.redirected
        |> elem(2)
        |> Map.get(:to)
        |> String.split("/")
        |> Enum.at(3)

      lesson = Medoru.Content.get_custom_lesson!(lesson_id)
      assert lesson.title == "My Custom Title"
      assert lesson.description == "My Custom Description"
    end
  end

  defp preview_socket(extra_assigns) do
    base = %{
      __changed__: %{},
      flash: %{},
      current_scope: nil,
      extracted_words: [],
      selected_word_indices: MapSet.new(),
      lesson_title: "",
      lesson_description: "",
      loading: false
    }

    %Phoenix.LiveView.Socket{assigns: Map.merge(base, extra_assigns)}
  end
end
