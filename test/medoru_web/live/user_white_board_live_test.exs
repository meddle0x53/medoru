defmodule MedoruWeb.UserWhiteBoardLiveTest do
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

  describe "mount" do
    test "renders white board for owner", %{conn: conn} do
      owner = owner_fixture(%{name: "BoardOwner"})
      post_fixture(%{user: owner, title: "My Post", content: "Hello world"})

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      assert html =~ "BoardOwner"
      assert html =~ "My Post"
      assert html =~ "Hello world"
    end

    test "renders white board for anonymous user", %{conn: conn} do
      owner = owner_fixture()
      post_fixture(%{user: owner, visibility: "public", content: "Public post"})
      post_fixture(%{user: owner, visibility: "followers", content: "Private post"})

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board")

      assert html =~ "Public post"
      refute html =~ "Private post"
    end

    test "redirects on invalid user id", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/users/invalid/white-board")
    end
  end

  describe "create post" do
    test "owner can create a text post", %{conn: conn} do
      owner = owner_fixture()

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      view
      |> form("form[phx-submit='create_post']", %{title: "New Title", content: "New content"})
      |> render_submit()

      html = render(view)
      assert html =~ "New Title"
      assert html =~ "New content"
      assert html =~ "Post created!"
    end

    test "guest cannot see post form", %{conn: conn} do
      owner = owner_fixture()

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board")

      refute html =~ "phx-submit=\"create_post\""
    end

    test "non-owner cannot see post form", %{conn: conn} do
      owner = owner_fixture()
      stranger = owner_fixture()

      {:ok, _view, html} =
        conn |> log_in_user(stranger) |> live(~p"/users/#{owner.id}/white-board")

      refute html =~ "phx-submit=\"create_post\""
    end

    test "post form has BoardInput hook and image file input for paste", %{conn: conn} do
      owner = owner_fixture()

      {:ok, _view, html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      assert html =~ "phx-hook=\"BoardInput\""
      assert html =~ "data-board-file-input"
      assert html =~ "accept=\"image/*"
    end
  end

  describe "grammar commands in posts" do
    test "renders grammar preview for /grammar command in post", %{conn: conn} do
      owner = owner_fixture()
      grammar_definition_fixture(%{title: "te-form pattern", jlpt_level: 5})

      {:ok, _post} =
        WhiteBoard.create_post(%{
          user_id: owner.id,
          title: "Grammar Post",
          content: "/grammar te-form pattern",
          visibility: "public",
          post_type: "text"
        })

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board")

      assert html =~ "te-form pattern"
      assert html =~ "/grammars/"
    end

    test "renders inline grammar link for \\text/ syntax in post", %{conn: conn} do
      owner = owner_fixture()
      grammar_definition_fixture(%{title: "na-adjective", jlpt_level: 5})

      {:ok, _post} =
        WhiteBoard.create_post(%{
          user_id: owner.id,
          title: "Inline Grammar",
          content: "Study \\na-adjective/ today",
          visibility: "public",
          post_type: "text"
        })

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board")

      assert html =~ "na-adjective"
      assert html =~ "/grammars/"
    end

    test "renders plain text for unknown inline grammar \\text/", %{conn: conn} do
      owner = owner_fixture()

      {:ok, _post} =
        WhiteBoard.create_post(%{
          user_id: owner.id,
          title: "Unknown Grammar",
          content: "Try \\onexistent-pattern/ here",
          visibility: "public",
          post_type: "text"
        })

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board")

      assert html =~ "\\onexistent-pattern/"
    end
  end

  describe "canvas post" do
    test "owner can save a canvas post", %{conn: conn} do
      owner = owner_fixture()

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      # Open canvas modal
      html =
        view
        |> element("button[phx-click='open_canvas']")
        |> render_click()

      assert html =~ "free-draw-container"

      # Save canvas
      html =
        view
        |> render_hook("save_canvas", %{
          "strokes" => [
            %{
              "tool" => "pencil",
              "color" => "#000",
              "width" => 3,
              "points" => [%{"x" => 10, "y" => 20}]
            }
          ],
          "grid" => nil,
          "background" => nil
        })

      assert html =~ "Drawing posted!"
    end

    test "canvas post renders canvas player", %{conn: conn} do
      owner = owner_fixture()

      {:ok, post} =
        WhiteBoard.create_post(%{
          user_id: owner.id,
          title: "Art",
          content: "My drawing",
          visibility: "public",
          post_type: "canvas",
          canvas_data: %{"strokes" => [%{"points" => [%{"x" => 1, "y" => 2}]}]}
        })

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board")

      assert html =~ "canvas-wrapper-#{post.id}"
      assert html =~ "phx-hook=\"CanvasPlayer\""
    end
  end

  describe "edit post" do
    test "owner can edit their post", %{conn: conn} do
      owner = owner_fixture()
      post = post_fixture(%{user: owner, title: "Old", content: "Old content"})

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      view
      |> element("button[phx-click='edit_post'][phx-value-id='#{post.id}']")
      |> render_click()

      view
      |> form("form[phx-submit='update_post']", %{
        post_id: post.id,
        title: "Updated",
        content: "Updated content"
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Updated"
      assert html =~ "Updated content"
    end

    test "owner can cancel edit", %{conn: conn} do
      owner = owner_fixture()
      post = post_fixture(%{user: owner, title: "Original", content: "Original content"})

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      view
      |> element("button[phx-click='edit_post'][phx-value-id='#{post.id}']")
      |> render_click()

      html =
        view
        |> element("button[phx-click='cancel_edit_post']")
        |> render_click()

      assert html =~ "Original"
    end
  end

  describe "delete post" do
    test "owner can delete their post", %{conn: conn} do
      owner = owner_fixture()
      post = post_fixture(%{user: owner, content: "To be deleted"})

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      view
      |> element("button[phx-click='delete_post'][phx-value-id='#{post.id}']")
      |> render_click()

      html = render(view)
      refute html =~ "To be deleted"
      assert html =~ "Post deleted."
    end
  end

  describe "toggle visibility" do
    test "owner can toggle post visibility", %{conn: conn} do
      owner = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      _html =
        view
        |> element("button[phx-click='toggle_visibility'][phx-value-id='#{post.id}']")
        |> render_click()

      updated_post = Repo.get!(WhiteBoard.BoardPost, post.id)
      assert updated_post.visibility == "followers"
    end
  end

  describe "comments" do
    test "logged-in user can add a comment", %{conn: conn} do
      owner = owner_fixture()
      commenter = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, view, _html} =
        conn |> log_in_user(commenter) |> live(~p"/users/#{owner.id}/white-board")

      html =
        view
        |> form("form[phx-submit='add_comment']", %{post_id: post.id, content: "Nice post!"})
        |> render_submit()

      assert html =~ "Nice post!"
    end

    test "comment form has CommentInput hook and image file input for paste", %{conn: conn} do
      owner = owner_fixture()
      commenter = owner_fixture()
      post_fixture(%{user: owner, visibility: "public"})

      {:ok, _view, html} =
        conn |> log_in_user(commenter) |> live(~p"/users/#{owner.id}/white-board")

      assert html =~ "phx-hook=\"CommentInput\""
      assert html =~ "data-comment-file-input"
    end

    test "logged-in user can reply to a comment", %{conn: conn} do
      owner = owner_fixture()
      commenter = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, parent} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Original"})

      {:ok, view, _html} =
        conn |> log_in_user(commenter) |> live(~p"/users/#{owner.id}/white-board")

      # Click reply button
      html =
        view
        |> element(
          "button[phx-click='reply_to_comment'][phx-value-post-id='#{post.id}'][phx-value-comment-id='#{parent.id}']"
        )
        |> render_click()

      assert html =~ "Write a reply"

      # Submit reply
      html =
        view
        |> form("form[phx-submit='add_comment']", %{
          post_id: post.id,
          parent_id: parent.id,
          content: "My reply"
        })
        |> render_submit()

      assert html =~ "My reply"
      assert html =~ "Replying to"
    end

    test "user can delete their own comment", %{conn: conn} do
      owner = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, comment} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Delete me"})

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      html =
        view
        |> element("button[phx-click='delete_comment'][phx-value-id='#{comment.id}']")
        |> render_click()

      refute html =~ "Delete me"
    end

    test "guest cannot see comment form", %{conn: conn} do
      owner = owner_fixture()
      post_fixture(%{user: owner, visibility: "public"})

      {:ok, _view, html} = live(conn, ~p"/users/#{owner.id}/white-board")

      refute html =~ "phx-submit=\"add_comment\""
    end
  end

  describe "reactions" do
    test "user can add a reaction", %{conn: conn} do
      owner = owner_fixture()
      reactor = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      {:ok, view, _html} =
        conn |> log_in_user(reactor) |> live(~p"/users/#{owner.id}/white-board")

      # Use 😀 which is in the first 30 emojis shown in the picker
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
        conn |> log_in_user(reactor) |> live(~p"/users/#{owner.id}/white-board")

      html =
        view
        |> element(
          "button[phx-click='toggle_reaction'][phx-value-post-id='#{post.id}'][phx-value-emoji='👍']"
        )
        |> render_click()

      refute html =~ "badge-primary"
    end
  end

  describe "pagination" do
    test "load more fetches additional posts", %{conn: conn} do
      owner = owner_fixture()

      for i <- 1..7 do
        post_fixture(%{user: owner, content: "Post #{i}"})
        Process.sleep(10)
      end

      {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/users/#{owner.id}/white-board")

      # Count posts on first page (should be 5)
      html = render(view)
      post_count = Regex.scan(~r/id="post-/, html) |> length()
      assert post_count == 5

      # Load more
      html =
        view
        |> element("button[phx-click='load_more']")
        |> render_click()

      # Should now have all 7 posts
      post_count = Regex.scan(~r/id="post-/, html) |> length()
      assert post_count == 7
    end
  end

  describe "blocked users" do
    test "blocked user's posts are hidden", %{conn: conn} do
      blocker = owner_fixture()
      blocked = owner_fixture()
      Social.block_user(blocker.id, blocked.id)

      post_fixture(%{user: blocked, visibility: "public", content: "Blocked content"})

      {:ok, _view, html} =
        conn |> log_in_user(blocker) |> live(~p"/users/#{blocked.id}/white-board")

      refute html =~ "Blocked content"
      assert html =~ "No posts yet"
    end
  end
end
