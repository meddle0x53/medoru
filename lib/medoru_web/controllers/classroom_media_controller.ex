defmodule MedoruWeb.ClassroomMediaController do
  @moduledoc """
  Lets a classroom teacher download all classroom chat media as a zip
  archive, or bulk-delete all classroom chat media (soft-delete of the
  underlying messages).
  """

  use MedoruWeb, :controller

  alias Medoru.Chat
  alias MedoruWeb.SlugRoutes

  plug :load_classroom_and_authorize when action in [:download, :delete_all]

  def download(conn, _params) do
    classroom = conn.assigns.classroom

    case conn.assigns.conversation do
      nil ->
        conn
        |> put_flash(:info, gettext("No chat media to download yet."))
        |> redirect(to: ~p"/classrooms/#{classroom}?tab=chat")

      conversation ->
        case Chat.export_conversation_media_zip(conversation.id) do
          {:ok, zip_path} ->
            conn
            |> send_download({:file, zip_path},
              filename: "classroom-media-#{classroom.id}.zip",
              content_type: "application/zip"
            )
            |> cleanup_zip_later(zip_path)

          {:error, _reason} ->
            conn
            |> put_flash(:error, gettext("Could not export the chat media."))
            |> redirect(to: ~p"/classrooms/#{classroom}?tab=chat")
        end
    end
  end

  def delete_all(conn, _params) do
    classroom = conn.assigns.classroom

    case conn.assigns.conversation do
      nil ->
        conn
        |> put_flash(:info, gettext("No chat media to delete."))
        |> redirect(to: ~p"/classrooms/#{classroom}?tab=chat")

      conversation ->
        case Chat.delete_all_conversation_media(conversation.id, conn.assigns.current_user.id) do
          {:ok, count} ->
            conn
            |> put_flash(
              :info,
              gettext("Deleted %{count} media message(s).", count: count)
            )
            |> redirect(to: ~p"/classrooms/#{classroom}?tab=chat")

          {:error, :unauthorized} ->
            conn
            |> resp(403, "Forbidden")
            |> halt()
        end
    end
  end

  defp load_classroom_and_authorize(conn, _opts) do
    classroom = SlugRoutes.load_classroom!(conn.params["id"])

    if classroom.teacher_id == conn.assigns.current_user.id do
      conversation = Chat.get_classroom_conversation(classroom.id)

      conn
      |> assign(:classroom, classroom)
      |> assign(:conversation, conversation)
    else
      conn
      |> resp(403, "Forbidden")
      |> halt()
    end
  end

  # send_download streams the file during the response send, so the temp
  # zip can only be removed after the response has gone out.
  defp cleanup_zip_later(conn, zip_path) do
    Task.start(fn ->
      Process.sleep(5_000)
      File.rm(zip_path)
    end)

    conn
  end
end
