defmodule MedoruWeb.DashboardLiveTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Medoru.AccountsFixtures

  alias Medoru.{Repo, Social, WhiteBoard}

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

  describe "board stream" do
    test "renders board stream with own posts", %{conn: conn} do
      user = owner_fixture()
      post_fixture(%{user: user, title: "My Post", content: "Hello stream"})

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/dashboard")

      assert html =~ "Board Stream"
      assert html =~ "My Post"
      assert html =~ "Hello stream"
      assert html =~ "Write something on your white board"
    end

    test "renders posts from followed users", %{conn: conn} do
      viewer = owner_fixture()
      followed = owner_fixture(%{name: "FollowedUser"})

      Social.follow_user(viewer.id, followed.id)
      post_fixture(%{user: followed, title: "Followed Post", content: "From followed"})

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      assert html =~ "Followed Post"
      assert html =~ "From followed"
      assert html =~ "FollowedUser"
    end

    test "does not show posts from non-followed users", %{conn: conn} do
      viewer = owner_fixture()
      stranger = owner_fixture()

      post_fixture(%{user: stranger, content: "Stranger post"})

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      refute html =~ "Stranger post"
    end

    test "shows empty state when no posts", %{conn: conn} do
      user = owner_fixture()

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/dashboard")

      assert html =~ "No posts yet"
      assert html =~ "Follow more users or write something on your white board"
    end

    test "user can react to a post in the stream", %{conn: conn} do
      viewer = owner_fixture()
      followed = owner_fixture()

      Social.follow_user(viewer.id, followed.id)
      post = post_fixture(%{user: followed, visibility: "public"})

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      html =
        view
        |> element("button[phx-click='stream_toggle_reaction'][phx-value-post-id='#{post.id}'][phx-value-emoji='😀']")
        |> render_click()

      assert html =~ "😀"
      assert html =~ "1"
    end

    test "user can add a comment in the stream", %{conn: conn} do
      viewer = owner_fixture()
      followed = owner_fixture()

      Social.follow_user(viewer.id, followed.id)
      post = post_fixture(%{user: followed, visibility: "public"})

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      html =
        view
        |> form("form[phx-submit='stream_add_comment']", %{post_id: post.id, content: "Stream comment!"})
        |> render_submit()

      assert html =~ "Stream comment!"
    end

    test "user can delete their own comment in the stream", %{conn: conn} do
      viewer = owner_fixture()
      followed = owner_fixture()

      Social.follow_user(viewer.id, followed.id)
      post = post_fixture(%{user: followed, visibility: "public"})

      {:ok, comment} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: viewer.id, content: "Delete me"})

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      html =
        view
        |> element("button[phx-click='stream_delete_comment'][phx-value-id='#{comment.id}']")
        |> render_click()

      refute html =~ "Delete me"
    end

    test "hides comments from users who blocked the viewer in stream", %{conn: conn} do
      viewer = owner_fixture()
      followed = owner_fixture()
      blocker = owner_fixture()

      Social.follow_user(viewer.id, followed.id)
      post = post_fixture(%{user: followed, visibility: "public"})

      # Create a normal comment and a comment from someone who blocked the viewer
      {:ok, _} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: followed.id, content: "Nice post"})

      {:ok, _} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: blocker.id, content: "Mean comment"})

      Social.block_user(blocker.id, viewer.id)

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      assert html =~ "Nice post"
      refute html =~ "Mean comment"
    end

    test "load more fetches additional stream posts", %{conn: conn} do
      viewer = owner_fixture()
      followed = owner_fixture()

      Social.follow_user(viewer.id, followed.id)

      for i <- 1..7 do
        post_fixture(%{user: followed, content: "Stream post #{i}"})
        Process.sleep(10)
      end

      {:ok, view, _html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      # Count posts on first page (should be 5)
      html = render(view)
      post_count = Regex.scan(~r/id="stream-post-/, html) |> length()
      assert post_count == 5

      # Load more
      html =
        view
        |> element("button[phx-click='stream_load_more']")
        |> render_click()

      # Should now have all 7 posts
      post_count = Regex.scan(~r/id="stream-post-/, html) |> length()
      assert post_count == 7
    end

    test "write something CTA links to user's white board", %{conn: conn} do
      user = owner_fixture()

      {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/dashboard")

      assert html =~ ~s|href="/users/#{user.id}/white-board"|
    end

    test "post header links to user's white board", %{conn: conn} do
      viewer = owner_fixture()
      followed = owner_fixture(%{name: "PostAuthor"})

      Social.follow_user(viewer.id, followed.id)
      post_fixture(%{user: followed, visibility: "public", content: "Linked post"})

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      assert html =~ ~s|href="/users/#{followed.id}/white-board"|
    end

    test "post has link to dedicated post page", %{conn: conn} do
      viewer = owner_fixture()
      followed = owner_fixture()

      Social.follow_user(viewer.id, followed.id)
      post = post_fixture(%{user: followed, visibility: "public"})

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      assert html =~ ~s|href="/users/#{followed.id}/white-board/posts/#{post.id}"|
    end

    test "blocked user's posts are hidden from stream", %{conn: conn} do
      viewer = owner_fixture()
      blocked = owner_fixture()

      Social.follow_user(viewer.id, blocked.id)
      Social.block_user(viewer.id, blocked.id)

      post_fixture(%{user: blocked, visibility: "public", content: "Blocked stream"})

      {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/dashboard")

      refute html =~ "Blocked stream"
    end
  end
end
