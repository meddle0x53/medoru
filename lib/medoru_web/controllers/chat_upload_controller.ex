defmodule MedoruWeb.ChatUploadController do
  @moduledoc """
  Handles multipart file uploads for chat attachments.
  Supports images, audio, documents up to 50MB, and video up to 200MB (teachers/admins only).
  """

  use MedoruWeb, :controller

  alias Medoru.Accounts.User

  @default_max_size 50_000_000
  @video_max_size 200_000_000

  @allowed_types %{
    "image/jpeg" => %{type: "image", ext: ".jpg"},
    "image/png" => %{type: "image", ext: ".png"},
    "image/gif" => %{type: "image", ext: ".gif"},
    "image/webp" => %{type: "image", ext: ".webp"},
    "audio/mpeg" => %{type: "audio", ext: ".mp3"},
    "audio/wav" => %{type: "audio", ext: ".wav"},
    "audio/wave" => %{type: "audio", ext: ".wav"},
    "audio/x-wav" => %{type: "audio", ext: ".wav"},
    "audio/webm" => %{type: "audio", ext: ".webm"},
    "audio/ogg" => %{type: "audio", ext: ".ogg"},
    "video/mp4" => %{type: "video", ext: ".mp4"},
    "video/webm" => %{type: "video", ext: ".webm"},
    "video/ogg" => %{type: "video", ext: ".ogv"},
    "video/quicktime" => %{type: "video", ext: ".mov"},
    "application/pdf" => %{type: "document", ext: ".pdf"},
    "text/plain" => %{type: "document", ext: ".txt"},
    "text/csv" => %{type: "document", ext: ".csv"},
    "application/json" => %{type: "document", ext: ".json"},
    "text/markdown" => %{type: "document", ext: ".md"},
    "text/x-markdown" => %{type: "document", ext: ".md"},
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => %{
      type: "document",
      ext: ".docx"
    },
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => %{
      type: "document",
      ext: ".xlsx"
    },
    "application/epub+zip" => %{type: "document", ext: ".epub"}
  }

  # Fallback by file extension when MIME type is generic or unrecognized
  @ext_fallbacks %{
    ".jpg" => %{type: "image", ext: ".jpg"},
    ".jpeg" => %{type: "image", ext: ".jpg"},
    ".png" => %{type: "image", ext: ".png"},
    ".gif" => %{type: "image", ext: ".gif"},
    ".webp" => %{type: "image", ext: ".webp"},
    ".mp3" => %{type: "audio", ext: ".mp3"},
    ".wav" => %{type: "audio", ext: ".wav"},
    ".webm" => %{type: "audio", ext: ".webm"},
    ".ogg" => %{type: "audio", ext: ".ogg"},
    ".mp4" => %{type: "video", ext: ".mp4"},
    ".mov" => %{type: "video", ext: ".mov"},
    ".ogv" => %{type: "video", ext: ".ogv"},
    ".pdf" => %{type: "document", ext: ".pdf"},
    ".txt" => %{type: "document", ext: ".txt"},
    ".csv" => %{type: "document", ext: ".csv"},
    ".json" => %{type: "document", ext: ".json"},
    ".md" => %{type: "document", ext: ".md"},
    ".docx" => %{type: "document", ext: ".docx"},
    ".xlsx" => %{type: "document", ext: ".xlsx"},
    ".epub" => %{type: "document", ext: ".epub"}
  }

  def create(conn, %{"file" => %Plug.Upload{} = upload}) do
    mime_type = upload.content_type || "application/octet-stream"

    meta = Map.get(@allowed_types, mime_type) || fallback_by_extension(upload.filename)

    if meta == nil do
      conn
      |> put_status(:unsupported_media_type)
      |> json(%{error: "File type not allowed"})
    else
      user = conn.assigns.current_scope.current_user
      is_video = meta.type == "video"

      # Only teachers and admins can upload video
      if is_video and not User.teacher?(user) do
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Video uploads are only available for teachers and admins."})
      else
        file_size = File.stat!(upload.path).size
        max_size = if is_video, do: @video_max_size, else: @default_max_size
        max_size_mb = div(max_size, 1_000_000)

        if file_size > max_size do
          conn
          |> put_status(:payload_too_large)
          |> json(%{error: "File too large. Maximum size is #{max_size_mb}MB."})
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
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "No file provided"})
  end

  defp fallback_by_extension(filename) do
    ext = filename |> Path.extname() |> String.downcase()
    Map.get(@ext_fallbacks, ext)
  end
end
