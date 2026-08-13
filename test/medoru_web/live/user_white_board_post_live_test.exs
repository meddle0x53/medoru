defmodule MedoruWeb.UserWhiteBoardPostLiveTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.{Notifications, Repo, WhiteBoard}

  defp owner_fixture(attrs \\ %{}) do
    user_fixture_with_registration(attrs)
  end

  defp post_fixture(attrs) do
    user = attrs[:user] || owner_fixture()

    attrs =
      Enum.into(attrs, %{
        user_id: user.id,
        title: "Test Post",
        content: "Test content",
        visibility: "public",
        post_type: "text"
      })

    {:ok, post} = WhiteBoard.create_post(attrs)
    Repo.preload(post, user: [:profile])
  end

  describe "mount" do
    test "renders single post page", %{conn: conn} do
      owner = owner_fixture(%{name: "PostOwner"})
      post = post_fixture(%{user: owner, title: "My Post", content: "Hello world"})

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board/posts/#{post.id}")

      assert html =~ "My Post"
      assert html =~ "Hello world"
      assert html =~ "PostOwner"
    end

    test "redirects on invalid post id", %{conn: conn} do
      owner = owner_fixture()

      assert {:error, {:live_redirect, %{to: "/"}}} =
               live(conn, ~p"/users/#{owner.id}/white-board/posts/invalid")
    end
  end

  describe "reactions" do
    test "user can add a reaction", %{conn: conn} do
      owner = owner_fixture()
      reactor = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, view, _html} =
        conn |> log_in_user(reactor) |> live(~p"/users/#{owner.id}/white-board/posts/#{post.id}")

      html =
        view
        |> element(
          "button[phx-click='toggle_reaction'][phx-value-post-id='#{post.id}'][phx-value-emoji='😀']"
        )
        |> render_click()

      assert html =~ "😀"
      assert html =~ "1"
    end

    test "user can remove their reaction", %{conn: conn} do
      owner = owner_fixture()
      reactor = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      WhiteBoard.toggle_reaction(post.id, reactor.id, "👍")

      {:ok, view, _html} =
        conn |> log_in_user(reactor) |> live(~p"/users/#{owner.id}/white-board/posts/#{post.id}")

      html =
        view
        |> element(
          "button[phx-click='toggle_reaction'][phx-value-post-id='#{post.id}'][phx-value-emoji='👍']"
        )
        |> render_click()

      refute html =~ "badge-primary"
    end

    test "emoji picker renders limited emojis", %{conn: conn} do
      owner = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board/posts/#{post.id}")

      # Should have max-h-60 and overflow-y-auto for scrolling
      assert html =~ "max-h-60"
      assert html =~ "overflow-y-auto"

      # Should only show 30 emoji buttons in the picker
      picker_emojis = Regex.scan(~r/phx-value-emoji="([^"]+)"/, html) |> length()
      # 30 picker emojis + possibly some reaction pills (none here since no reactions yet)
      # The share button and view post button also don't have phx-value-emoji
      assert picker_emojis == 30
    end
  end

  describe "comments" do
    test "logged-in user can add a comment", %{conn: conn} do
      owner = owner_fixture()
      commenter = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, view, _html} =
        conn
        |> log_in_user(commenter)
        |> live(~p"/users/#{owner.id}/white-board/posts/#{post.id}")

      html =
        view
        |> form("form[phx-submit='add_comment']", %{post_id: post.id, content: "Nice post!"})
        |> render_submit()

      assert html =~ "Nice post!"
    end

    test "commenting notifies the post owner", %{conn: conn} do
      owner = owner_fixture()
      commenter = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, view, _html} =
        conn
        |> log_in_user(commenter)
        |> live(~p"/users/#{owner.id}/white-board/posts/#{post.id}")

      view
      |> form("form[phx-submit='add_comment']", %{post_id: post.id, content: "Notifying comment!"})
      |> render_submit()

      assert Notifications.count_notifications(owner.id) == 1
      notification = hd(Notifications.list_notifications(owner.id))
      assert notification.type == "white_board_comment"
    end

    test "guest cannot see comment form", %{conn: conn} do
      owner = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board/posts/#{post.id}")

      refute html =~ "phx-submit=\"add_comment\""
    end
  end
end
