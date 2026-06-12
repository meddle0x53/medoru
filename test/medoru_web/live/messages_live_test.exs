defmodule MedoruWeb.MessagesLiveTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.Chat
  alias Medoru.Encryption
  alias Medoru.Accounts

  defp user_with_display_name(attrs \\ %{}) do
    user = user_fixture_with_registration(attrs)
    display_name = attrs[:display_name] || "User#{System.unique_integer([:positive])}"
    {:ok, profile} = Accounts.update_profile(user.profile, %{display_name: display_name})
    %{user | profile: profile}
  end

  describe "MessagesLive.Index" do
    test "renders conversations list", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, _} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, _view, html} = conn |> log_in_user(user_a) |> live(~p"/messages")

      assert html =~ "Messages"
      assert html =~ "New Message"
    end

    test "shows empty state when no conversations", %{conn: conn} do
      user = user_with_display_name()

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/messages")

      assert html =~ "No messages yet"
      assert html =~ "Find Users"
    end

    test "redirects unauthenticated user", %{conn: conn} do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/messages")
    end

    test "filters out blocked users from conversations", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      # Store a message so it shows up
      Chat.store_message(conv.id, user_b.id, Base.encode64(<<1>>), Base.encode64(<<2>>))

      # Block user_b
      Medoru.Social.block_user(user_a.id, user_b.id)

      # Clear any notifications so they don't show user_b's name in the dropdown
      Medoru.Notifications.mark_all_as_read(user_a.id)

      {:ok, _view, html} = conn |> log_in_user(user_a) |> live(~p"/messages")

      # Should not show the conversation with blocked user
      refute html =~ user_b.profile.display_name
    end

    test "starts conversation from user param", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()

      # handle_params redirects to the conversation
      assert {:error, {:live_redirect, %{to: path}}} =
               conn |> log_in_user(user_a) |> live(~p"/messages?user=#{user_b.id}")

      assert path =~ "/messages/"
    end

    test "prevents messaging blocked user from param", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()

      Medoru.Social.block_user(user_a.id, user_b.id)

      {:ok, view, _html} = conn |> log_in_user(user_a) |> live(~p"/messages?user=#{user_b.id}")

      assert render(view) =~ "You cannot message this user"
    end
  end

  describe "MessagesLive.Show" do
    test "renders 1:1 conversation", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      # Set up public keys so input area is shown
      Encryption.store_public_key(user_a.id, <<1>>)
      Encryption.store_public_key(user_b.id, <<2>>)

      {:ok, _view, html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      assert html =~ user_b.profile.display_name
      assert html =~ "Type a message"
    end

    test "shows online status when other participant is present", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      Encryption.store_public_key(user_a.id, <<1>>)
      Encryption.store_public_key(user_b.id, <<2>>)

      # user_b joins the conversation first
      {:ok, _view_b, _html_b} = conn |> log_in_user(user_b) |> live(~p"/messages/#{conv.id}")

      # user_a sees user_b as online
      {:ok, _view_a, html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      assert html =~ "Online"
    end

    test "renders group conversation", %{conn: conn} do
      creator = user_with_display_name()
      user_b = user_with_display_name()

      {:ok, conv} =
        Chat.create_group_conversation(creator.id, "Test Group", [user_b.id], %{
          creator.id => Base.encode64(<<1>>),
          user_b.id => Base.encode64(<<2>>)
        })

      {:ok, _view, html} = conn |> log_in_user(creator) |> live(~p"/messages/#{conv.id}")

      assert html =~ "Test Group"
      assert html =~ "members"
    end

    test "redirects non-participant", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      user_c = user_with_display_name()

      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:error, {:live_redirect, %{to: "/messages"}}} =
        conn |> log_in_user(user_c) |> live(~p"/messages/#{conv.id}")
    end

    test "redirects when conversation is blocked", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      # Set up public keys so blocked message is shown instead of missing keys
      Encryption.store_public_key(user_a.id, <<1>>)
      Encryption.store_public_key(user_b.id, <<2>>)

      Medoru.Social.block_user(user_a.id, user_b.id)

      {:error,
       {:live_redirect, %{to: "/messages", flash: %{"error" => "Conversation not found."}}}} =
        conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")
    end

    test "shows missing keys warning", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      # No public keys set up
      {:ok, _view, html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      # HTML-escaped apostrophe: haven&#39;t
      assert html =~ "set up encryption yet"
    end

    test "shows messages in conversation", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, _msg} =
        Chat.store_message(conv.id, user_b.id, Base.encode64(<<1>>), Base.encode64(<<2>>))

      {:ok, _view, html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      # Messages are encrypted so we check for the encrypted placeholder
      assert html =~ "[...]"
    end

    test "adds reaction to message via picker", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, msg} =
        Chat.store_message(conv.id, user_b.id, Base.encode64(<<1>>), Base.encode64(<<2>>))

      {:ok, view, _html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      # Open reaction picker
      html =
        view
        |> element("button[phx-click='open_reaction_picker']")
        |> render_click(%{"id" => msg.id})

      assert html =~ "👍"

      # Click emoji to add reaction
      html =
        view
        |> element("button[phx-value-emoji='👍']")
        |> render_click(%{"message_id" => msg.id, "emoji" => "👍"})

      # Reaction pill should appear
      assert html =~ "👍"
      assert html =~ "bg-primary/15"
    end

    test "removes existing reaction by clicking pill", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, msg} =
        Chat.store_message(conv.id, user_b.id, Base.encode64(<<1>>), Base.encode64(<<2>>))

      # Pre-add a reaction
      {:ok, _reaction, nil} = Chat.toggle_reaction(msg.id, user_a.id, "👍")

      {:ok, view, _html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      # Reaction pill should be visible
      assert render(view) =~ "👍"

      # Click reaction pill to remove
      html =
        view
        |> element("button[phx-click='toggle_reaction']")
        |> render_click(%{"message_id" => msg.id, "emoji" => "👍"})

      # Reaction should be removed
      refute html =~ "bg-primary/15"
    end

    test "handles reply selection and cancellation", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, msg} =
        Chat.store_message(conv.id, user_b.id, Base.encode64(<<1>>), Base.encode64(<<2>>))

      {:ok, view, _html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      # Set reply
      html =
        view
        |> element("button[phx-click='set_reply']")
        |> render_click(%{"id" => msg.id})

      assert html =~ "Replying to"
      assert html =~ "phx-value-id=\"#{msg.id}\""

      # Click reply preview bar to open preview panel
      html =
        view
        |> element("div[phx-click='preview_message']")
        |> render_click(%{"id" => msg.id})

      assert html =~ "Message</h3>"
      assert html =~ "[...]"

      # Close preview
      html = render_click(view, "close_preview")

      refute html =~ "Message</h3>"

      # Cancel reply
      html =
        view
        |> element("button[phx-click='cancel_reply']")
        |> render_click()

      refute html =~ "Replying to"
    end

    test "handles register_public_key event", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      # Set up public keys so input area is shown
      Encryption.store_public_key(user_a.id, <<1>>)
      Encryption.store_public_key(user_b.id, <<2>>)

      {:ok, view, _html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      html =
        view
        |> render_hook("register_public_key", %{"public_key" => Base.encode64(<<1, 2, 3>>)})

      # Should not crash - input area visible since keys are set up
      assert html =~ "Type a message"
    end

    test "handles ensure_conversation_key with missing keys", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      {:ok, view, _html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      # Should push encryption_error event
      _html = render_hook(view, "ensure_conversation_key", %{})
    end

    test "handles store_conversation_keys event", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()
      {:ok, conv} = Chat.find_or_create_conversation(user_a.id, user_b.id)

      # Set up public keys
      Encryption.store_public_key(user_a.id, <<1>>)
      Encryption.store_public_key(user_b.id, <<2>>)

      {:ok, view, _html} = conn |> log_in_user(user_a) |> live(~p"/messages/#{conv.id}")

      encrypted_keys = %{
        user_a.id => Base.encode64(<<3>>),
        user_b.id => Base.encode64(<<4>>)
      }

      _ = render_hook(view, "store_conversation_keys", %{"encrypted_keys" => encrypted_keys})

      # Verify keys were stored
      assert Chat.get_conversation_key(conv.id, user_a.id) != nil
      assert Chat.get_conversation_key(conv.id, user_b.id) != nil
    end
  end

  describe "MessagesLive.NewGroup" do
    test "renders group creation page", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()

      {:ok, _view, html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/new-group?users=#{user_b.id}")

      assert html =~ "New Group Chat"
      assert html =~ "Participants"
      assert html =~ user_b.profile.display_name
    end

    test "validates empty title", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()

      {:ok, view, _html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/new-group?users=#{user_b.id}")

      html =
        view
        |> render_hook("create_group", %{"title" => "   ", "encrypted_keys" => %{}})

      assert html =~ "Please enter a group name"
    end

    test "creates group with valid data", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()

      Encryption.store_public_key(user_a.id, <<1>>)
      Encryption.store_public_key(user_b.id, <<2>>)

      {:ok, view, _html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/new-group?users=#{user_b.id}")

      encrypted_keys = %{
        user_a.id => Base.encode64(<<3>>),
        user_b.id => Base.encode64(<<4>>)
      }

      result =
        view
        |> render_hook("create_group", %{
          "title" => "My Group",
          "encrypted_keys" => encrypted_keys
        })

      assert {:error, {:live_redirect, %{to: path}}} = result
      assert path =~ "/messages/"
    end

    test "shows warning for missing participant keys", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()

      # Only user_a has a key
      Encryption.store_public_key(user_a.id, <<1>>)

      {:ok, _view, html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/new-group?users=#{user_b.id}")

      # HTML-escaped apostrophe
      assert html =~ "set up encryption yet"
    end

    test "handles register_public_key event", %{conn: conn} do
      user_a = user_with_display_name()
      user_b = user_with_display_name()

      {:ok, view, _html} =
        conn |> log_in_user(user_a) |> live(~p"/messages/new-group?users=#{user_b.id}")

      html =
        view
        |> render_hook("register_public_key", %{"public_key" => Base.encode64(<<1, 2, 3>>)})

      assert html =~ "New Group Chat"
    end
  end
end
