defmodule MedoruWeb.MessagesLive.SettingsTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.{Chat, Classrooms}
  alias Medoru.Accounts

  defp user_with_display_name(attrs \\ %{}) do
    user = user_fixture_with_registration(attrs)
    display_name = attrs[:display_name] || "User#{System.unique_integer([:positive])}"
    {:ok, profile} = Accounts.update_profile(user.profile, %{display_name: display_name})
    %{user | profile: profile}
  end

  defp classroom_fixture(attrs) do
    attrs = Map.merge(%{name: attrs[:name] || "Test Classroom"}, attrs)
    {:ok, classroom} = Classrooms.create_classroom(attrs)
    classroom
  end

  describe "MessagesLive.Settings" do
    test "renders theme settings for 1:1 conversation", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, _view, html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}/settings")

      assert html =~ "Chat Theme"
      assert html =~ user_b.profile.display_name
    end

    test "renders theme settings for group conversation", %{conn: conn} do
      creator = user_with_display_name()
      user_b = user_with_display_name()
      user_c = user_with_display_name()

      encrypted_keys = %{
        creator.id => Base.encode64(<<1, 2, 3>>),
        user_b.id => Base.encode64(<<4, 5, 6>>),
        user_c.id => Base.encode64(<<7, 8, 9>>)
      }

      {:ok, conv} =
        Chat.create_group_conversation(
          creator.id,
          "Test Group",
          [user_b.id, user_c.id],
          encrypted_keys
        )

      {:ok, _view, html} =
        conn |> log_in_user(user_b) |> live(~p"/messages/#{conv.id}/settings")

      assert html =~ "Chat Theme"
      assert html =~ "Test Group"
    end

    test "sets a theme and redirects back to chat", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, view, _html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}/settings")

      assert {:error, {:live_redirect, %{to: path}}} =
               render_click(view, :set_theme, %{"theme" => "dracula"})

      assert path == "/messages/#{conv.id}"

      assert Chat.get_conversation(user_a.id, conv.id).theme == "dracula"
    end

    test "resets theme to default", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)
      {:ok, conv} = Chat.update_conversation_theme(user_a.id, conv.id, "dracula")

      {:ok, view, _html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}/settings")

      assert {:error, {:live_redirect, %{to: path}}} =
               render_click(view, :set_theme, %{"theme" => ""})

      assert path == "/messages/#{conv.id}"

      assert is_nil(Chat.get_conversation(user_a.id, conv.id).theme)
    end

    test "redirects non-participant", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      user_c = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      assert {:error, {:live_redirect, %{to: "/messages"}}} =
               conn |> log_in_user(user_c) |> live(~p"/messages/#{conv.id}/settings")
    end

    test "redirects for classroom conversation", %{conn: conn} do
      teacher = user_with_display_name()
      student = user_with_display_name()
      classroom = classroom_fixture(%{teacher_id: teacher.id})
      conv = Chat.get_classroom_conversation(classroom.id)
      {:ok, _} = Chat.add_participant_plain(conv.id, student.id)

      assert {:error, {:live_redirect, %{to: path}}} =
               conn |> log_in_user(student) |> live(~p"/messages/#{conv.id}/settings")

      assert path == "/messages/#{conv.id}"
    end
  end
end
