defmodule Medoru.WhiteBoardTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures

  alias Medoru.{Repo, Social, WhiteBoard}
  alias Medoru.WhiteBoard.{BoardComment, BoardPost, BoardReaction}

  defp owner_fixture(attrs \\ %{}) do
    user_fixture_with_registration(attrs)
  end

  defp post_fixture(attrs \\ %{}) do
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
    %{post | user: user}
  end

  describe "posts" do
    test "create_post/1 creates a text post" do
      user = owner_fixture()

      attrs = %{
        user_id: user.id,
        title: "Hello",
        content: "World",
        visibility: "public",
        post_type: "text"
      }

      assert {:ok, %BoardPost{} = post} = WhiteBoard.create_post(attrs)
      assert post.title == "Hello"
      assert post.content == "World"
      assert post.visibility == "public"
      assert post.post_type == "text"
    end

    test "create_post/1 creates a canvas post" do
      user = owner_fixture()

      attrs = %{
        user_id: user.id,
        title: "Drawing",
        content: "My art",
        visibility: "followers",
        post_type: "canvas",
        canvas_data: %{"strokes" => [%{"points" => [%{"x" => 1, "y" => 2}]}]}
      }

      assert {:ok, %BoardPost{} = post} = WhiteBoard.create_post(attrs)
      assert post.post_type == "canvas"
      assert post.canvas_data["strokes"] != []
    end

    test "create_post/1 validates visibility" do
      user = owner_fixture()

      attrs = %{
        user_id: user.id,
        content: "Test",
        visibility: "invalid",
        post_type: "text"
      }

      assert {:error, %Ecto.Changeset{}} = WhiteBoard.create_post(attrs)
    end

    test "create_post/1 requires content for text posts" do
      user = owner_fixture()

      attrs = %{
        user_id: user.id,
        visibility: "public",
        post_type: "text"
      }

      assert {:error, %Ecto.Changeset{}} = WhiteBoard.create_post(attrs)
    end

    test "create_post/1 requires canvas_data for canvas posts" do
      user = owner_fixture()

      attrs = %{
        user_id: user.id,
        visibility: "public",
        post_type: "canvas"
      }

      assert {:error, %Ecto.Changeset{}} = WhiteBoard.create_post(attrs)
    end

    test "update_post/2 updates post attributes" do
      post = post_fixture()

      assert {:ok, updated} =
               WhiteBoard.update_post(post, %{title: "Updated", content: "New content"})

      assert updated.title == "Updated"
      assert updated.content == "New content"
    end

    test "update_post/2 can toggle visibility" do
      post = post_fixture(%{visibility: "public"})

      assert {:ok, updated} = WhiteBoard.update_post(post, %{visibility: "followers"})
      assert updated.visibility == "followers"
    end

    test "delete_post/1 removes the post" do
      post = post_fixture()
      assert {:ok, _} = WhiteBoard.delete_post(post)
      assert Repo.get(BoardPost, post.id) == nil
    end

    test "delete_post/1 cascades comments and reactions" do
      owner = owner_fixture()
      commenter = owner_fixture()
      post = post_fixture(%{user: owner})

      {:ok, _} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: commenter.id, content: "Nice!"})

      {:ok, _, _} = WhiteBoard.toggle_reaction(post.id, commenter.id, "👍")

      assert {:ok, _} = WhiteBoard.delete_post(post)

      assert Repo.all(from c in BoardComment, where: c.post_id == ^post.id) == []
      assert Repo.all(from r in BoardReaction, where: r.post_id == ^post.id) == []
    end

    test "list_posts/3 returns public posts for anonymous viewers" do
      owner = owner_fixture()
      post_fixture(%{user: owner, visibility: "public"})
      post_fixture(%{user: owner, visibility: "followers"})

      posts = WhiteBoard.list_posts(owner.id, nil)
      assert length(posts) == 1
      assert hd(posts).visibility == "public"
    end

    test "list_posts/3 returns all posts for owner" do
      owner = owner_fixture()
      post_fixture(%{user: owner, visibility: "public"})
      post_fixture(%{user: owner, visibility: "followers"})

      posts = WhiteBoard.list_posts(owner.id, owner.id)
      assert length(posts) == 2
    end

    test "list_posts/3 returns followers posts to followers" do
      owner = owner_fixture()
      follower = owner_fixture()
      Social.follow_user(follower.id, owner.id)

      post_fixture(%{user: owner, visibility: "public"})
      post_fixture(%{user: owner, visibility: "followers"})

      posts = WhiteBoard.list_posts(owner.id, follower.id)
      assert length(posts) == 2
    end

    test "list_posts/3 hides followers posts from non-followers" do
      owner = owner_fixture()
      stranger = owner_fixture()

      post_fixture(%{user: owner, visibility: "public"})
      post_fixture(%{user: owner, visibility: "followers"})

      posts = WhiteBoard.list_posts(owner.id, stranger.id)
      assert length(posts) == 1
      assert hd(posts).visibility == "public"
    end

    test "list_posts/3 excludes posts from blocked users" do
      _owner = owner_fixture()
      blocker = owner_fixture()
      blocked = owner_fixture()

      Social.block_user(blocker.id, blocked.id)
      post_fixture(%{user: blocked, visibility: "public"})

      posts = WhiteBoard.list_posts(blocked.id, blocker.id)
      assert posts == []
    end

    test "list_posts/3 excludes posts from users who blocked the viewer" do
      blocker = owner_fixture()
      viewer = owner_fixture()

      Social.block_user(blocker.id, viewer.id)
      post_fixture(%{user: blocker, visibility: "public", content: "Hidden post"})

      posts = WhiteBoard.list_posts(blocker.id, viewer.id)
      assert posts == []
    end

    test "get_post!/2 raises when viewer is blocked by post owner" do
      owner = owner_fixture()
      viewer = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      Social.block_user(owner.id, viewer.id)

      assert_raise Ecto.NoResultsError, fn ->
        WhiteBoard.get_post!(post.id, viewer.id)
      end
    end

    test "get_post!/2 raises when post owner is blocked by viewer" do
      owner = owner_fixture()
      viewer = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      Social.block_user(viewer.id, owner.id)

      assert_raise Ecto.NoResultsError, fn ->
        WhiteBoard.get_post!(post.id, viewer.id)
      end
    end

    test "list_posts/3 supports pagination" do
      owner = owner_fixture()

      for i <- 1..7 do
        post_fixture(%{user: owner, content: "Post #{i}"})
      end

      page1 = WhiteBoard.list_posts(owner.id, owner.id, page: 1)
      assert length(page1) == 5

      page2 = WhiteBoard.list_posts(owner.id, owner.id, page: 2)
      assert length(page2) == 2
    end

    test "count_posts/2 returns correct count with visibility filter" do
      owner = owner_fixture()
      stranger = owner_fixture()
      post_fixture(%{user: owner, visibility: "public"})
      post_fixture(%{user: owner, visibility: "followers"})

      assert WhiteBoard.count_posts(owner.id, nil) == 1
      assert WhiteBoard.count_posts(owner.id, stranger.id) == 1
      assert WhiteBoard.count_posts(owner.id, owner.id) == 2
    end

    test "list_following_posts/2 returns own posts and followed users' posts" do
      viewer = owner_fixture()
      followed = owner_fixture()
      stranger = owner_fixture()

      Social.follow_user(viewer.id, followed.id)

      _own_post = post_fixture(%{user: viewer, content: "My post"})
      _followed_post = post_fixture(%{user: followed, content: "Followed post"})
      _stranger_post = post_fixture(%{user: stranger, content: "Stranger post"})

      posts = WhiteBoard.list_following_posts(viewer.id)
      contents = Enum.map(posts, & &1.content)

      assert "My post" in contents
      assert "Followed post" in contents
      refute "Stranger post" in contents
    end

    test "list_following_posts/2 includes followers-only posts from followed users" do
      viewer = owner_fixture()
      followed = owner_fixture()

      Social.follow_user(viewer.id, followed.id)

      post_fixture(%{user: followed, visibility: "public", content: "Public"})
      post_fixture(%{user: followed, visibility: "followers", content: "Followers"})

      posts = WhiteBoard.list_following_posts(viewer.id)
      contents = Enum.map(posts, & &1.content)

      assert "Public" in contents
      assert "Followers" in contents
    end

    test "list_following_posts/2 excludes posts from blocked users" do
      viewer = owner_fixture()
      blocked = owner_fixture()

      Social.follow_user(viewer.id, blocked.id)
      Social.block_user(viewer.id, blocked.id)

      post_fixture(%{user: blocked, visibility: "public", content: "Blocked post"})

      posts = WhiteBoard.list_following_posts(viewer.id)
      contents = Enum.map(posts, & &1.content)

      refute "Blocked post" in contents
    end

    test "list_following_posts/2 excludes posts from users who blocked the viewer" do
      viewer = owner_fixture()
      blocker = owner_fixture()

      Social.follow_user(viewer.id, blocker.id)
      Social.block_user(blocker.id, viewer.id)

      post_fixture(%{user: blocker, visibility: "public", content: "Blocker post"})

      posts = WhiteBoard.list_following_posts(viewer.id)
      contents = Enum.map(posts, & &1.content)

      refute "Blocker post" in contents
    end

    test "list_following_posts/2 supports pagination" do
      viewer = owner_fixture()
      followed = owner_fixture()

      Social.follow_user(viewer.id, followed.id)

      for i <- 1..7 do
        post_fixture(%{user: followed, content: "Post #{i}"})
        Process.sleep(10)
      end

      page1 = WhiteBoard.list_following_posts(viewer.id, page: 1)
      assert length(page1) == 5

      page2 = WhiteBoard.list_following_posts(viewer.id, page: 2)
      assert length(page2) == 2
    end

    test "count_following_posts/1 returns correct count" do
      viewer = owner_fixture()
      followed = owner_fixture()
      stranger = owner_fixture()

      Social.follow_user(viewer.id, followed.id)

      post_fixture(%{user: viewer, content: "Own"})
      post_fixture(%{user: followed, content: "Followed"})
      _stranger_post = post_fixture(%{user: stranger, content: "Stranger"})

      assert WhiteBoard.count_following_posts(viewer.id) == 2
    end

    test "can_view_post?/2 allows owner always" do
      owner = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "followers"})

      assert WhiteBoard.can_view_post?(post, owner.id)
    end

    test "can_view_post?/2 allows public to anyone" do
      owner = owner_fixture()
      stranger = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "public"})

      assert WhiteBoard.can_view_post?(post, stranger.id)
      assert WhiteBoard.can_view_post?(post, nil)
    end

    test "can_view_post?/2 hides followers-only from strangers" do
      owner = owner_fixture()
      stranger = owner_fixture()
      post = post_fixture(%{user: owner, visibility: "followers"})

      refute WhiteBoard.can_view_post?(post, stranger.id)
      refute WhiteBoard.can_view_post?(post, nil)
    end
  end

  describe "comments" do
    test "create_comment/1 creates a top-level comment" do
      owner = owner_fixture()
      commenter = owner_fixture()
      post = post_fixture(%{user: owner})

      attrs = %{post_id: post.id, user_id: commenter.id, content: "Great post!"}
      assert {:ok, %BoardComment{} = comment} = WhiteBoard.create_comment(attrs)
      assert comment.content == "Great post!"
      assert comment.parent_id == nil
    end

    test "create_comment/1 creates a reply" do
      owner = owner_fixture()
      commenter = owner_fixture()
      post = post_fixture(%{user: owner})

      {:ok, parent} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Original"})

      attrs = %{post_id: post.id, user_id: commenter.id, parent_id: parent.id, content: "Reply!"}
      assert {:ok, %BoardComment{} = reply} = WhiteBoard.create_comment(attrs)
      assert reply.parent_id == parent.id
    end

    test "create_comment/1 validates content length" do
      owner = owner_fixture()
      post = post_fixture(%{user: owner})

      attrs = %{post_id: post.id, user_id: owner.id, content: ""}
      assert {:error, %Ecto.Changeset{}} = WhiteBoard.create_comment(attrs)
    end

    test "update_comment/2 updates content" do
      owner = owner_fixture()
      post = post_fixture(%{user: owner})

      {:ok, comment} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Original"})

      assert {:ok, updated} = WhiteBoard.update_comment(comment, %{content: "Edited"})
      assert updated.content == "Edited"
    end

    test "delete_comment/1 removes the comment" do
      owner = owner_fixture()
      post = post_fixture(%{user: owner})

      {:ok, comment} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Bye"})

      assert {:ok, _} = WhiteBoard.delete_comment(comment)
      assert Repo.get(BoardComment, comment.id) == nil
    end

    test "list_comments_for_post/1 returns top-level comments with replies" do
      owner = owner_fixture()
      post = post_fixture(%{user: owner})

      {:ok, parent} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Parent"})

      {:ok, _reply} =
        WhiteBoard.create_comment(%{
          post_id: post.id,
          user_id: owner.id,
          parent_id: parent.id,
          content: "Reply"
        })

      comments = WhiteBoard.list_comments_for_post(post.id)
      assert length(comments) == 1
      assert hd(comments).content == "Parent"
      assert length(hd(comments).replies) == 1
    end

    test "list_comments_for_post/2 filters out comments from blocked users" do
      owner = owner_fixture()
      blocker = owner_fixture()
      blocked = owner_fixture()
      post = post_fixture(%{user: owner})

      Social.block_user(blocker.id, blocked.id)

      {:ok, _visible_comment} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Visible"})

      {:ok, _blocked_comment} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: blocked.id, content: "Blocked"})

      comments = WhiteBoard.list_comments_for_post(post.id, blocker.id)
      assert length(comments) == 1
      assert hd(comments).content == "Visible"
    end

    test "list_comments_for_post/2 filters out comments from users who blocked the viewer" do
      owner = owner_fixture()
      viewer = owner_fixture()
      post = post_fixture(%{user: owner})

      Social.block_user(owner.id, viewer.id)

      {:ok, _comment} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Hidden"})

      comments = WhiteBoard.list_comments_for_post(post.id, viewer.id)
      assert comments == []
    end

    test "list_comments_for_post/2 filters out replies from blocked users" do
      owner = owner_fixture()
      blocker = owner_fixture()
      blocked = owner_fixture()
      post = post_fixture(%{user: owner})

      Social.block_user(blocker.id, blocked.id)

      {:ok, parent} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Parent"})

      {:ok, _visible_reply} =
        WhiteBoard.create_comment(%{
          post_id: post.id,
          user_id: owner.id,
          parent_id: parent.id,
          content: "Visible Reply"
        })

      {:ok, _blocked_reply} =
        WhiteBoard.create_comment(%{
          post_id: post.id,
          user_id: blocked.id,
          parent_id: parent.id,
          content: "Blocked Reply"
        })

      comments = WhiteBoard.list_comments_for_post(post.id, blocker.id)
      assert length(comments) == 1
      assert length(hd(comments).replies) == 1
      assert hd(hd(comments).replies).content == "Visible Reply"
    end

    test "list_commenter_ids_for_post/1 returns unique commenter IDs" do
      owner = owner_fixture()
      commenter = owner_fixture()
      post = post_fixture(%{user: owner})

      {:ok, _} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "First"})

      {:ok, _} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: commenter.id, content: "Second"})

      {:ok, _} =
        WhiteBoard.create_comment(%{post_id: post.id, user_id: owner.id, content: "Third"})

      ids = WhiteBoard.list_commenter_ids_for_post(post.id)
      assert length(ids) == 2
      assert owner.id in ids
      assert commenter.id in ids
    end
  end

  describe "reactions" do
    test "toggle_reaction/3 adds a new reaction" do
      owner = owner_fixture()
      reactor = owner_fixture()
      post = post_fixture(%{user: owner})

      assert {:ok, %BoardReaction{} = added, nil} =
               WhiteBoard.toggle_reaction(post.id, reactor.id, "👍")

      assert added.emoji == "👍"
      assert added.post_id == post.id
      assert added.user_id == reactor.id
    end

    test "toggle_reaction/3 removes same emoji reaction" do
      owner = owner_fixture()
      reactor = owner_fixture()
      post = post_fixture(%{user: owner})

      WhiteBoard.toggle_reaction(post.id, reactor.id, "👍")

      assert {:ok, nil, removed} = WhiteBoard.toggle_reaction(post.id, reactor.id, "👍")
      assert removed.emoji == "👍"
    end

    test "toggle_reaction/3 replaces different emoji reaction" do
      owner = owner_fixture()
      reactor = owner_fixture()
      post = post_fixture(%{user: owner})

      WhiteBoard.toggle_reaction(post.id, reactor.id, "👍")

      assert {:ok, %BoardReaction{} = added, removed} =
               WhiteBoard.toggle_reaction(post.id, reactor.id, "❤️")

      assert added.emoji == "❤️"
      assert removed.emoji == "👍"
    end

    test "toggle_reaction/3 allows multiple users to react" do
      owner = owner_fixture()
      user1 = owner_fixture()
      user2 = owner_fixture()
      post = post_fixture(%{user: owner})

      assert {:ok, _, _} = WhiteBoard.toggle_reaction(post.id, user1.id, "👍")
      assert {:ok, _, _} = WhiteBoard.toggle_reaction(post.id, user2.id, "👍")

      reactions = WhiteBoard.list_reactions_for_post(post.id, user1.id)
      assert reactions["👍"].count == 2
      assert reactions["👍"].me? == true
    end

    test "list_reactions_for_post/2 returns correct me? flag" do
      owner = owner_fixture()
      reactor = owner_fixture()
      stranger = owner_fixture()
      post = post_fixture(%{user: owner})

      WhiteBoard.toggle_reaction(post.id, reactor.id, "👍")

      reactor_reactions = WhiteBoard.list_reactions_for_post(post.id, reactor.id)
      assert reactor_reactions["👍"].me? == true

      stranger_reactions = WhiteBoard.list_reactions_for_post(post.id, stranger.id)
      assert stranger_reactions["👍"].me? == false
    end

    test "list_reactions_for_posts/2 batches reactions for multiple posts" do
      owner = owner_fixture()
      reactor = owner_fixture()
      post1 = post_fixture(%{user: owner})
      post2 = post_fixture(%{user: owner})

      WhiteBoard.toggle_reaction(post1.id, reactor.id, "👍")
      WhiteBoard.toggle_reaction(post2.id, reactor.id, "❤️")

      reactions = WhiteBoard.list_reactions_for_posts([post1.id, post2.id], reactor.id)
      assert reactions[post1.id]["👍"].count == 1
      assert reactions[post2.id]["❤️"].count == 1
    end
  end

  describe "broadcasting" do
    test "subscribe_to_board/1 and broadcast_post_created/2 work together" do
      owner = owner_fixture()
      post = post_fixture(%{user: owner})

      WhiteBoard.subscribe_to_board(owner.id)
      WhiteBoard.broadcast_post_created(owner.id, post)

      assert_receive {:post_created, ^post}
    end

    test "broadcast_post_updated/2 sends update message" do
      owner = owner_fixture()
      post = post_fixture(%{user: owner})

      WhiteBoard.subscribe_to_board(owner.id)
      WhiteBoard.broadcast_post_updated(owner.id, post)

      assert_receive {:post_updated, ^post}
    end

    test "broadcast_post_deleted/2 sends delete message" do
      owner = owner_fixture()
      post = post_fixture(%{user: owner})
      post_id = post.id

      WhiteBoard.subscribe_to_board(owner.id)
      WhiteBoard.broadcast_post_deleted(owner.id, post.id)

      assert_receive {:post_deleted, ^post_id}
    end

    test "broadcast_reaction/6 sends reaction message" do
      owner = owner_fixture()
      reactor = owner_fixture()
      post = post_fixture(%{user: owner})
      post_id = post.id
      reactor_id = reactor.id

      WhiteBoard.subscribe_to_board(owner.id)
      WhiteBoard.broadcast_reaction(owner.id, post.id, reactor.id, "👍", nil)

      assert_receive {:reaction, ^post_id, ^reactor_id, "👍", nil}
    end

    test "broadcast_reaction/6 with from_pid excludes sender" do
      owner = owner_fixture()
      reactor = owner_fixture()
      post = post_fixture(%{user: owner})

      WhiteBoard.subscribe_to_board(owner.id)
      WhiteBoard.broadcast_reaction(owner.id, post.id, reactor.id, "👍", nil, self())

      refute_receive {:reaction, _, _, _, _}, 100
    end

    test "broadcast_comment/3 sends comment message" do
      owner = owner_fixture()
      _post = post_fixture(%{user: owner})
      comment = %{id: "test-comment-id", content: "Hi"}

      WhiteBoard.subscribe_to_board(owner.id)
      WhiteBoard.broadcast_comment(owner.id, comment)

      assert_receive {:comment, ^comment}
    end

    test "broadcast_comment/3 with from_pid excludes sender" do
      owner = owner_fixture()
      comment = %{id: "test-comment-id", content: "Hi"}

      WhiteBoard.subscribe_to_board(owner.id)
      WhiteBoard.broadcast_comment(owner.id, comment, self())

      refute_receive {:comment, _}, 100
    end
  end
end
