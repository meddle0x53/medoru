defmodule MedoruWeb.MessagesLive.ShowTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Chat
  alias Medoru.Accounts

  defp user_with_display_name(attrs \\ %{}) do
    user = user_fixture_with_registration(attrs)
    display_name = attrs[:display_name] || "User#{System.unique_integer([:positive])}"
    {:ok, profile} = Accounts.update_profile(user.profile, %{display_name: display_name})
    %{user | profile: profile}
  end

  describe "media folder" do
    test "renders empty media folder when no attachments", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, view, _html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      html = render_click(view, :open_media_folder)

      assert html =~ "Media"
      assert html =~ "No media found"
    end

    test "renders media items and filters by type", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      Chat.store_plaintext_message(conv.id, user_a.id, "Image",
        attachment_path: "/uploads/chat_images/1.jpg",
        attachment_type: "image"
      )

      Chat.store_plaintext_message(conv.id, user_a.id, "Voice",
        attachment_path: "/uploads/voice_messages/1.webm",
        attachment_type: "voice"
      )

      {:ok, view, _html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      html = render_click(view, :open_media_folder)

      assert html =~ "Media"
      assert html =~ "/uploads/chat_images/1.jpg"
      assert html =~ "/uploads/voice_messages/1.webm"

      html = render_click(view, :set_media_filter, %{"type" => "image"})
      assert html =~ "bg-primary text-primary-content"
      assert html =~ "/uploads/chat_images/1.jpg"
    end

    test "paginates media one page at a time", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      for i <- 1..25 do
        Chat.store_plaintext_message(conv.id, user_a.id, "Image #{i}",
          attachment_path: "/uploads/chat_images/#{i}.jpg",
          attachment_type: "image"
        )
      end

      {:ok, view, _html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      html = render_click(view, :open_media_folder)

      assert html =~ "Load more media"
      assert html =~ "phx-viewport-bottom=\"load_more_media\""

      # Clicking load more starts an async load.
      html = render_click(view, :load_more_media)
      assert html =~ "Loading..."
      refute html =~ "phx-viewport-bottom=\"load_more_media\""

      # Wait for the async load to finish.
      html = render_async(view, 1000)

      # After loading more, all 25 image paths should be present.
      for i <- 1..25 do
        assert html =~ "/uploads/chat_images/#{i}.jpg"
      end

      refute html =~ "Load more media"
      refute html =~ "phx-viewport-bottom=\"load_more_media\""
    end
  end
end
