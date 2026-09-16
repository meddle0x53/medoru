defmodule MedoruWeb.ChatUploadControllerTest do
  use MedoruWeb.ConnCase, async: true

  import Medoru.AccountsFixtures

  defp uploads_dir, do: Application.get_env(:medoru, :uploads_dir)

  defp video_upload(filename, content, content_type) do
    path = Path.join(System.tmp_dir!(), "upload-test-#{System.unique_integer([:positive])}")
    File.write!(path, content)
    %Plug.Upload{path: path, filename: filename, content_type: content_type}
  end

  defp cleanup_uploaded(path) do
    on_exit(fn ->
      if path, do: File.rm(Path.join(uploads_dir(), String.trim_leading(path, "/uploads/")))
    end)
  end

  test "any authenticated user can upload a video", %{conn: conn} do
    # regular student-type user, not a teacher
    user = user_fixture()
    assert Medoru.Accounts.User.teacher?(user) == false

    conn =
      conn
      |> log_in_user(user)
      |> post(~p"/api/chat/uploads", %{
        "file" => video_upload("clip.mp4", "fake video data", "video/mp4")
      })

    assert %{"path" => path, "type" => "video"} = json_response(conn, 200)
    assert path =~ ~r/^\/uploads\/chat_files\/[a-f0-9-]+\.mp4$/
    cleanup_uploaded(path)
  end

  test "teacher can still upload a video", %{conn: conn} do
    user = user_fixture(%{type: "teacher"})

    conn =
      conn
      |> log_in_user(user)
      |> post(~p"/api/chat/uploads", %{
        "file" => video_upload("clip.mov", "fake video data", "video/quicktime")
      })

    assert %{"path" => path, "type" => "video"} = json_response(conn, 200)
    assert path =~ ~r/^\/uploads\/chat_files\/[a-f0-9-]+\.mov$/
    cleanup_uploaded(path)
  end

  test "video extension fallback works when MIME type is empty", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> post(~p"/api/chat/uploads", %{
        "file" => video_upload("clip.mp4", "fake video data", "application/octet-stream")
      })

    assert %{"path" => path, "type" => "video"} = json_response(conn, 200)
    cleanup_uploaded(path)
  end

  test "image upload still works", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> post(~p"/api/chat/uploads", %{
        "file" => video_upload("photo.jpg", "fake image data", "image/jpeg")
      })

    assert %{"path" => path, "type" => "image"} = json_response(conn, 200)
    cleanup_uploaded(path)
  end

  test "disallowed file types are rejected", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> post(~p"/api/chat/uploads", %{
        "file" => video_upload("evil.exe", "binary", "application/x-msdownload")
      })

    assert json_response(conn, 415)["error"] =~ "not allowed"
  end

  test "requires authentication", %{conn: conn} do
    conn =
      post(conn, ~p"/api/chat/uploads", %{"file" => video_upload("clip.mp4", "x", "video/mp4")})

    assert redirected_to(conn) == "/"
  end
end
