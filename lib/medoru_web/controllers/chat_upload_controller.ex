defmodule MedoruWeb.ChatUploadController do
  @moduledoc """
  Handles multipart file uploads for chat attachments.
  Supports images, audio, and documents up to 50MB.
  """

  use MedoruWeb, :controller

  @max_size 50_000_000

  @allowed_types %{
    "image/jpeg" => %{type: "image", ext: ".jpg"},
    "image/png" => %{type: "image", ext: ".png"},
    "image/gif" => %{type: "image", ext: ".gif"},
    "image/webp" => %{type: "image", ext: ".webp"},
    "audio/mpeg" => %{type: "audio", ext: ".mp3"},
    "audio/wav" => %{type: "audio", ext: ".wav"},
    "audio/wave" => %{type: "audio", ext: ".wav"},
    "audio/x-wav" => %{type: "audio", ext: ".wav"},
    "application/pdf" => %{type: "document", ext: ".pdf"},
    "text/plain" => %{type: "document", ext: ".txt"},
    "text/csv" => %{type: "document", ext: ".csv"},
    "application/json" => %{type: "document", ext: ".json"},
    "text/markdown" => %{type: "document", ext: ".md"},
    "text/x-markdown" => %{type: "document", ext: ".md"},
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => %{type: "document", ext: ".docx"},
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => %{type: "document", ext: ".xlsx"},
    "application/epub+zip" => %{type: "document", ext: ".epub"}
  }

  def create(conn, %{"file" => %Plug.Upload{} = upload}) do
    mime_type = upload.content_type || "application/octet-stream"

    case Map.get(@allowed_types, mime_type) do
      nil ->
        conn
        |> put_status(:unsupported_media_type)
        |> json(%{error: "File type not allowed"})

      meta ->
        file_size = File.stat!(upload.path).size

        if file_size > @max_size do
          conn
          |> put_status(:payload_too_large)
          |> json(%{error: "File too large. Maximum size is 50MB."})
        else
          uploads_dir = Application.get_env(:medoru, :uploads_dir)
          filename = "#{Ecto.UUID.generate()}#{meta.ext}"
          dest_dir = Path.join(uploads_dir, "chat_files")
          File.mkdir_p!(dest_dir)
          dest_path = Path.join(dest_dir, filename)

          File.cp!(upload.path, dest_path)

          json(conn, %{
            path: "/uploads/chat_files/#{filename}",
            type: meta.type,
            mime_type: mime_type,
            size: file_size,
            name: upload.filename
          })
        end
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "No file provided"})
  end
end
