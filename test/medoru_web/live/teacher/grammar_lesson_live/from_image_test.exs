defmodule MedoruWeb.Teacher.GrammarLessonLive.FromImageTest do
  use MedoruWeb.ConnCase

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  describe "From Image Grammar (admin only)" do
    test "redirects non-admin users", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)

      {:error, {:live_redirect, %{to: "/teacher/grammar-lessons"}}} =
        live(conn, ~p"/teacher/grammar-lessons/from-image")
    end

    test "mounts for admin user", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/from-image")
      assert render(view) =~ "Create Grammar Lesson from Image"
    end

    test "shows upload area", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons/from-image")
      assert render(view) =~ "Click or drag an image here"
      assert render(view) =~ "Extract Grammar"
    end
  end

  describe "Grammar lesson index shows Create from Image button for admins" do
    test "admin sees Create from Image button", %{conn: conn} do
      admin = user_fixture(%{type: "admin"})
      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons")
      assert render(view) =~ "Create from Image"
    end

    test "teacher does not see Create from Image button", %{conn: conn} do
      teacher = user_fixture(%{type: "teacher"})
      conn = log_in_user(conn, teacher)
      {:ok, view, _html} = live(conn, ~p"/teacher/grammar-lessons")
      refute render(view) =~ "Create from Image"
    end
  end

  describe "preview form editing" do
    test "preview inputs are wrapped in forms with names" do
      assigns = %{
        step: :preview,
        lesson_title: "My Title",
        lesson_description: "My Desc",
        extracted_sections: [
          %{
            "title" => "Section 1",
            "description" => "Desc",
            "step_type" => "grammar",
            "number" => 1,
            "examples" => [
              %{"sentence" => "S", "reading" => "R", "meaning" => "M"}
            ]
          }
        ],
        selected_section_indices: MapSet.new([0]),
        loading: false,
        flash: %{},
        current_scope: nil,
        __changed__: %{},
        uploads: %{image: %{ref: "phx-upload-ref", entries: []}}
      }

      html =
        MedoruWeb.Teacher.GrammarLessonLive.FromImage.render(assigns)
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ ~s(<form phx-change="update_title">)
      assert html =~ ~s(<form phx-change="update_description">)
      assert html =~ ~s(name="title")
      assert html =~ ~s(name="description")
      assert html =~ ~s(<form phx-change="update_section" class="contents">)
      assert html =~ ~s(<form phx-change="update_example" class="contents">)
      assert html =~ ~s(name="value")
    end

    test "update_title event updates lesson title assign" do
      socket = preview_socket(%{lesson_title: "Old Title"})

      assert {:noreply, updated_socket} =
               MedoruWeb.Teacher.GrammarLessonLive.FromImage.handle_event(
                 "update_title",
                 %{"title" => "New Title"},
                 socket
               )

      assert updated_socket.assigns.lesson_title == "New Title"
    end

    test "update_description event updates lesson description assign" do
      socket = preview_socket(%{lesson_description: "Old Description"})

      assert {:noreply, updated_socket} =
               MedoruWeb.Teacher.GrammarLessonLive.FromImage.handle_event(
                 "update_description",
                 %{"description" => "New Description"},
                 socket
               )

      assert updated_socket.assigns.lesson_description == "New Description"
    end

    test "update_section event updates section field" do
      socket =
        preview_socket(%{
          extracted_sections: [
            %{
              "title" => "Section 1",
              "description" => "Old",
              "step_type" => "text",
              "number" => 1,
              "examples" => []
            }
          ]
        })

      assert {:noreply, updated_socket} =
               MedoruWeb.Teacher.GrammarLessonLive.FromImage.handle_event(
                 "update_section",
                 %{"index" => "0", "field" => "description", "value" => "New"},
                 socket
               )

      assert hd(updated_socket.assigns.extracted_sections)["description"] == "New"
    end

    test "update_example event updates example field" do
      socket =
        preview_socket(%{
          extracted_sections: [
            %{
              "title" => "Section 1",
              "description" => "",
              "step_type" => "grammar",
              "number" => 1,
              "examples" => [%{"sentence" => "S", "reading" => "R", "meaning" => "M"}]
            }
          ]
        })

      assert {:noreply, updated_socket} =
               MedoruWeb.Teacher.GrammarLessonLive.FromImage.handle_event(
                 "update_example",
                 %{
                   "section_index" => "0",
                   "example_index" => "0",
                   "field" => "meaning",
                   "value" => "New Meaning"
                 },
                 socket
               )

      section = hd(updated_socket.assigns.extracted_sections)
      example = hd(section["examples"])
      assert example["meaning"] == "New Meaning"
    end

    test "create_lesson saves custom title and description" do
      admin = user_fixture(%{type: "admin"})

      socket =
        preview_socket(%{
          current_scope: %{current_user: admin},
          extracted_sections: [
            %{
              "title" => "Section 1",
              "description" => "Description",
              "step_type" => "text",
              "number" => 1,
              "examples" => []
            }
          ],
          selected_section_indices: MapSet.new([0]),
          lesson_title: "My Grammar Title",
          lesson_description: "My Grammar Description"
        })

      assert {:noreply, updated_socket} =
               MedoruWeb.Teacher.GrammarLessonLive.FromImage.handle_event(
                 "create_lesson",
                 %{},
                 socket
               )

      assert {:live, :redirect, %{kind: :push, to: "/teacher/grammar-lessons/" <> _}} =
               updated_socket.redirected

      lesson_id =
        updated_socket.redirected
        |> elem(2)
        |> Map.get(:to)
        |> String.split("/")
        |> Enum.at(3)

      lesson = Medoru.Content.get_custom_lesson!(lesson_id)
      assert lesson.title == "My Grammar Title"
      assert lesson.description == "My Grammar Description"
    end
  end

  defp preview_socket(extra_assigns) do
    base = %{
      __changed__: %{},
      flash: %{},
      current_scope: nil,
      extracted_sections: [],
      selected_section_indices: MapSet.new(),
      lesson_title: "",
      lesson_description: "",
      loading: false
    }

    %Phoenix.LiveView.Socket{assigns: Map.merge(base, extra_assigns)}
  end
end
