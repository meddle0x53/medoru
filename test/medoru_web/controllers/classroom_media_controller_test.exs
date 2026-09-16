defmodule MedoruWeb.ClassroomMediaControllerTest do
  use MedoruWeb.ConnCase, async: true

  import Medoru.AccountsFixtures

  alias Medoru.Chat
  alias Medoru.Classrooms

  defp setup_classroom(_context) do
    teacher = user_fixture()
    student = user_fixture()

    {:ok, classroom} =
      Classrooms.create_classroom(%{name: "Media Classroom", teacher_id: teacher.id})

    {:ok, membership} = Classrooms.apply_to_join(classroom.id, student.id)
    {:ok, _} = Classrooms.approve_membership(membership)

    conversation = Chat.get_classroom_conversation(classroom.id)

    %{teacher: teacher, student: student, classroom: classroom, conversation: conversation}
  end

  setup :setup_classroom

  defp write_upload(content) do
    rel_path = "chat_files/controller-test-#{System.unique_integer([:positive])}.jpg"
    uploads_dir = Application.get_env(:medoru, :uploads_dir)
    path = Path.join(uploads_dir, rel_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    "/uploads/#{rel_path}"
  end

  describe "GET /classrooms/:id/media/download" do
    test "teacher downloads all media as a zip", %{
      conn: conn,
      teacher: teacher,
      classroom: classroom,
      conversation: conversation
    } do
      attachment = write_upload("zip-me")

      Chat.store_plaintext_message(conversation.id, teacher.id, "Image",
        attachment_path: attachment,
        attachment_type: "image"
      )

      conn =
        conn
        |> log_in_user(teacher)
        |> get(~p"/classrooms/#{classroom}/media/download")

      assert response(conn, 200) =~ "PK"
      [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "classroom-media-#{classroom.id}.zip"
    end

    test "student is forbidden", %{conn: conn, student: student, classroom: classroom} do
      conn =
        conn
        |> log_in_user(student)
        |> get(~p"/classrooms/#{classroom}/media/download")

      assert response(conn, 403)
    end

    test "returns 404 for unknown classroom", %{conn: conn, teacher: teacher} do
      assert_error_sent 404, fn ->
        conn
        |> log_in_user(teacher)
        |> get(~p"/classrooms/#{Ecto.UUID.generate()}/media/download")
      end
    end
  end

  describe "POST /classrooms/:id/media/delete_all" do
    test "teacher bulk-deletes all media", %{
      conn: conn,
      teacher: teacher,
      classroom: classroom,
      conversation: conversation
    } do
      uploads_dir = Application.get_env(:medoru, :uploads_dir)
      attachment = write_upload("delete-me")
      disk_path = Path.join(uploads_dir, String.trim_leading(attachment, "/uploads/"))

      {:ok, msg} =
        Chat.store_plaintext_message(conversation.id, teacher.id, "Image",
          attachment_path: attachment,
          attachment_type: "image"
        )

      conn =
        conn
        |> log_in_user(teacher)
        |> post(~p"/classrooms/#{classroom}/media/delete_all")

      assert redirected_to(conn) == ~p"/classrooms/#{classroom}?tab=chat"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Deleted 1"
      refute File.exists?(disk_path)
      assert Medoru.Repo.get!(Medoru.Chat.Message, msg.id).is_deleted
    end

    test "student is forbidden", %{conn: conn, student: student, classroom: classroom} do
      conn =
        conn
        |> log_in_user(student)
        |> post(~p"/classrooms/#{classroom}/media/delete_all")

      assert response(conn, 403)
    end
  end
end
