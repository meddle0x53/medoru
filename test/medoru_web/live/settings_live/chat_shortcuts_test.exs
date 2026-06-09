defmodule MedoruWeb.SettingsLive.ChatShortcutsTest do
  use MedoruWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Accounts

  describe "Chat Shortcuts settings" do
    setup %{conn: conn} do
      user = user_fixture_with_registration()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "toggles convert_emoticons off and on", %{conn: conn, user: user} do
      # Verify default is true
      profile = Accounts.get_user_profile(user.id)
      assert profile.convert_emoticons == true

      {:ok, view, _html} = live(conn, ~p"/settings/chat-shortcuts")

      # Toggle off
      view
      |> element("input[phx-click='toggle_emoticons']")
      |> render_click()

      # Save
      view
      |> element("button[phx-click='save']")
      |> render_click()

      # Verify DB updated to false
      profile = Accounts.get_user_profile(user.id)
      assert profile.convert_emoticons == false

      # Re-mount settings
      {:ok, view, _html} = live(conn, ~p"/settings/chat-shortcuts")

      # Toggle back on
      view
      |> element("input[phx-click='toggle_emoticons']")
      |> render_click()

      # Save
      view
      |> element("button[phx-click='save']")
      |> render_click()

      # Verify DB updated back to true
      profile = Accounts.get_user_profile(user.id)
      assert profile.convert_emoticons == true
    end

    test "convert_emoticons setting flows to classroom chat rendering", %{conn: conn, user: user} do
      # Turn emoticons off
      {:ok, _} = Accounts.update_settings(user, %{convert_emoticons: false})

      # Verify DB has false
      profile = Accounts.get_user_profile(user.id)
      assert profile.convert_emoticons == false

      # Create a classroom and send a message with an emoticon
      teacher = user_fixture(%{email: "teacher@example.com"})

      {:ok, classroom} =
        Medoru.Classrooms.create_classroom(%{
          name: "Test Classroom",
          teacher_id: teacher.id
        })

      {:ok, membership} = Medoru.Classrooms.apply_to_join(classroom.id, user.id)
      {:ok, _} = Medoru.Classrooms.approve_membership(membership)

      conversation = Medoru.Chat.get_classroom_conversation(classroom.id)
      Medoru.Chat.store_plaintext_message(conversation.id, teacher.id, "Hello :)")

      # Render classroom chat
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=chat")

      # With convert_emoticons=false, text should stay as ":)"
      # (reaction picker buttons contain emoji, so check message paragraph specifically)
      msg_content =
        html
        |> String.split("Hello")
        |> Enum.at(1, "")
        |> String.split("</p>")
        |> Enum.at(0, "")

      assert msg_content =~ ":)"
      refute msg_content =~ "😊"

      # Turn emoticons back on
      {:ok, _} = Accounts.update_settings(user, %{convert_emoticons: true})

      # Re-mount classroom chat (simulating navigation from settings)
      {:ok, _view, html} = live(conn, ~p"/classrooms/#{classroom.id}?tab=chat")

      # With convert_emoticons=true, text should be converted to emoji
      msg_content =
        html
        |> String.split("Hello")
        |> Enum.at(1, "")
        |> String.split("</p>")
        |> Enum.at(0, "")

      assert msg_content =~ "😊"
      refute msg_content =~ ":)"
    end
  end
end
