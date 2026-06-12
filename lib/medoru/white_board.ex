defmodule Medoru.WhiteBoard do
  @moduledoc """
  Context for the user white board feature.
  Handles posts, comments, and reactions.
  """
  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Social.UserBlock
  alias Medoru.Social
  alias Medoru.WhiteBoard.{BoardPost, BoardComment, BoardReaction}

  @posts_per_page 5

  # ============================================================================
  # Posts
  # ============================================================================

  @doc """
  Lists posts from users the viewer follows plus their own posts.
  Sorted newest first with pagination.
  """
  def list_following_posts(viewer_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    offset = (page - 1) * @posts_per_page

    following_ids = Social.list_following_ids(viewer_id)
    author_ids = [viewer_id | following_ids]

    BoardPost
    |> where([p], p.user_id in ^author_ids)
    |> apply_following_stream_blocked_filter(viewer_id)
    |> order_by(desc: :inserted_at)
    |> limit(^@posts_per_page)
    |> offset(^offset)
    |> preload(user: [:profile])
    |> Repo.all()
  end

  @doc """
  Counts total posts from followed users + self visible to the viewer.
  """
  def count_following_posts(viewer_id) do
    following_ids = Social.list_following_ids(viewer_id)
    author_ids = [viewer_id | following_ids]

    BoardPost
    |> where([p], p.user_id in ^author_ids)
    |> apply_following_stream_blocked_filter(viewer_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Lists posts for a user's white board with pagination.
  Filters by visibility based on viewer relationship.
  """
  def list_posts(user_id, viewer_id \\ nil, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    offset = (page - 1) * @posts_per_page

    query =
      BoardPost
      |> where([p], p.user_id == ^user_id)
      |> apply_visibility_filter(viewer_id, user_id)
      |> apply_blocked_filter(viewer_id)
      |> order_by(desc: :inserted_at)
      |> limit(^@posts_per_page)
      |> offset(^offset)
      |> preload(user: [:profile])

    Repo.all(query)
  end

  @doc """
  Counts total visible posts for a user.
  """
  def count_posts(user_id, viewer_id \\ nil) do
    BoardPost
    |> where([p], p.user_id == ^user_id)
    |> apply_visibility_filter(viewer_id, user_id)
    |> apply_blocked_filter(viewer_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a single post with comments and user preloaded.
  Raises if not found or not visible.
  """
  def get_post!(id, viewer_id \\ nil) do
    post =
      BoardPost
      |> where([p], p.id == ^id)
      |> preload([:user, comments: [:user, replies: [:user]]])
      |> Repo.one!()

    unless can_view_post?(post, viewer_id) do
      raise Ecto.NoResultsError, queryable: BoardPost
    end

    post
  end

  @doc """
  Creates a post.
  """
  def create_post(attrs) do
    %BoardPost{}
    |> BoardPost.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post.
  """
  def update_post(%BoardPost{} = post, attrs) do
    post
    |> BoardPost.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post and its comments/reactions.
  """
  def delete_post(%BoardPost{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns true if the viewer can see the post.
  """
  def can_view_post?(%BoardPost{} = post, viewer_id) do
    cond do
      # Blocked in either direction: not visible
      viewer_id && Social.is_blocked?(post.user_id, viewer_id) == :blocked ->
        false

      # Owner can always see
      viewer_id && post.user_id == viewer_id ->
        true

      # Public posts visible to all
      post.visibility == "public" ->
        true

      # Followers-only: check if viewer follows the author
      post.visibility == "followers" && viewer_id ->
        Social.following?(viewer_id, post.user_id)

      true ->
        false
    end
  end

  # ============================================================================
  # Comments
  # ============================================================================

  @doc """
  Lists comments for a post, including nested replies.
  Filters out comments from users blocked by the viewer.
  """
  def list_comments_for_post(post_id, viewer_id \\ nil) do
    comments =
      BoardComment
      |> where([c], c.post_id == ^post_id and is_nil(c.parent_id))
      |> order_by(asc: :inserted_at)
      |> preload(user: [:profile], replies: [user: [:profile]])
      |> Repo.all()

    if viewer_id do
      blocked_ids =
        UserBlock
        |> where([ub], ub.blocker_id == ^viewer_id)
        |> select([ub], ub.blocked_id)
        |> Repo.all()

      blocked_by_ids =
        UserBlock
        |> where([ub], ub.blocked_id == ^viewer_id)
        |> select([ub], ub.blocker_id)
        |> Repo.all()

      excluded_ids = Enum.uniq(blocked_ids ++ blocked_by_ids)

      if excluded_ids == [] do
        comments
      else
        comments
        |> Enum.reject(fn comment -> comment.user_id in excluded_ids end)
        |> Enum.map(fn comment ->
          %{comment | replies: Enum.reject(comment.replies, &(&1.user_id in excluded_ids))}
        end)
      end
    else
      comments
    end
  end

  @doc """
  Returns unique user IDs who have commented on a post.
  """
  def list_commenter_ids_for_post(post_id) do
    BoardComment
    |> where([c], c.post_id == ^post_id)
    |> select([c], c.user_id)
    |> distinct(true)
    |> Repo.all()
  end

  @doc """
  Creates a comment.
  """
  def create_comment(attrs) do
    %BoardComment{}
    |> BoardComment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a comment.
  """
  def update_comment(%BoardComment{} = comment, attrs) do
    comment
    |> BoardComment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a comment.
  """
  def delete_comment(%BoardComment{} = comment) do
    Repo.delete(comment)
  end

  # ============================================================================
  # Reactions
  # ============================================================================

  @doc """
  Toggles a reaction on a post.
  Returns {:ok, added_reaction, removed_reaction}.
  """
  def toggle_reaction(post_id, user_id, emoji) do
    existing =
      Repo.one(
        from r in BoardReaction,
          where: r.post_id == ^post_id and r.user_id == ^user_id
      )

    cond do
      is_nil(existing) ->
        %BoardReaction{}
        |> BoardReaction.changeset(%{post_id: post_id, user_id: user_id, emoji: emoji})
        |> Repo.insert()
        |> case do
          {:ok, reaction} -> {:ok, reaction, nil}
          error -> error
        end

      existing.emoji == emoji ->
        Repo.delete(existing)
        {:ok, nil, existing}

      true ->
        Repo.transaction(fn ->
          Repo.delete!(existing)

          %BoardReaction{}
          |> BoardReaction.changeset(%{post_id: post_id, user_id: user_id, emoji: emoji})
          |> Repo.insert!()
        end)
        |> case do
          {:ok, reaction} -> {:ok, reaction, existing}
          error -> error
        end
    end
  end

  @doc """
  Gets reactions for a single post.
  Returns %{emoji => %{count: int, me?: bool}}.
  """
  def list_reactions_for_post(post_id, current_user_id) do
    BoardReaction
    |> where([r], r.post_id == ^post_id)
    |> select([r], {r.emoji, r.user_id})
    |> Repo.all()
    |> Enum.group_by(fn {emoji, _user_id} -> emoji end, fn {_emoji, user_id} -> user_id end)
    |> Enum.map(fn {emoji, user_ids} ->
      {emoji,
       %{
         count: length(user_ids),
         me?: current_user_id in user_ids
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Gets reactions for multiple posts at once.
  Returns %{post_id => %{emoji => %{count: int, me?: bool}}}.
  """
  def list_reactions_for_posts(post_ids, current_user_id) do
    BoardReaction
    |> where([r], r.post_id in ^post_ids)
    |> select([r], {r.post_id, r.emoji, r.user_id})
    |> Repo.all()
    |> Enum.group_by(fn {post_id, _emoji, _user_id} -> post_id end)
    |> Enum.map(fn {post_id, rows} ->
      grouped =
        rows
        |> Enum.group_by(fn {_post_id, emoji, _user_id} -> emoji end, fn {_post_id, _emoji,
                                                                          user_id} ->
          user_id
        end)
        |> Enum.map(fn {emoji, user_ids} ->
          {emoji,
           %{
             count: length(user_ids),
             me?: current_user_id in user_ids
           }}
        end)
        |> Enum.into(%{})

      {post_id, grouped}
    end)
    |> Enum.into(%{})
  end

  # ============================================================================
  # PubSub Broadcasting
  # ============================================================================

  def subscribe_to_board(user_id) do
    Phoenix.PubSub.subscribe(Medoru.PubSub, "white_board:#{user_id}")
  end

  def broadcast_post_created(user_id, post) do
    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "white_board:#{user_id}",
      {:post_created, post}
    )
  end

  def broadcast_post_updated(user_id, post) do
    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "white_board:#{user_id}",
      {:post_updated, post}
    )
  end

  def broadcast_post_deleted(user_id, post_id) do
    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "white_board:#{user_id}",
      {:post_deleted, post_id}
    )
  end

  def broadcast_reaction(
        user_id,
        post_id,
        user_id_reacting,
        added_emoji,
        removed_emoji,
        from_pid \\ nil
      ) do
    msg = {:reaction, post_id, user_id_reacting, added_emoji, removed_emoji}

    if from_pid do
      Phoenix.PubSub.broadcast_from(
        Medoru.PubSub,
        from_pid,
        "white_board:#{user_id}",
        msg
      )
    else
      Phoenix.PubSub.broadcast(
        Medoru.PubSub,
        "white_board:#{user_id}",
        msg
      )
    end
  end

  def broadcast_comment(user_id, comment, from_pid \\ nil) do
    if from_pid do
      Phoenix.PubSub.broadcast_from(
        Medoru.PubSub,
        from_pid,
        "white_board:#{user_id}",
        {:comment, comment}
      )
    else
      Phoenix.PubSub.broadcast(
        Medoru.PubSub,
        "white_board:#{user_id}",
        {:comment, comment}
      )
    end
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp apply_visibility_filter(query, nil, _owner_id),
    do: where(query, [p], p.visibility == "public")

  defp apply_visibility_filter(query, viewer_id, owner_id) do
    if viewer_id == owner_id do
      query
    else
      is_follower =
        Medoru.Social.Follow
        |> where([f], f.follower_id == ^viewer_id and f.following_id == ^owner_id)
        |> Repo.exists?()

      if is_follower do
        query
      else
        where(query, [p], p.visibility == "public")
      end
    end
  end

  # Bidirectional block filter for white board queries.
  defp apply_blocked_filter(query, nil), do: query

  defp apply_blocked_filter(query, viewer_id) do
    blocked_ids =
      UserBlock
      |> where([ub], ub.blocker_id == ^viewer_id)
      |> select([ub], ub.blocked_id)
      |> Repo.all()

    blocked_by_ids =
      UserBlock
      |> where([ub], ub.blocked_id == ^viewer_id)
      |> select([ub], ub.blocker_id)
      |> Repo.all()

    excluded_ids = Enum.uniq(blocked_ids ++ blocked_by_ids)

    if excluded_ids == [] do
      query
    else
      where(query, [p], p.user_id not in ^excluded_ids)
    end
  end

  # For the following stream, we need bidirectional block filtering:
  # exclude posts from users the viewer blocked AND users who blocked the viewer.
  defp apply_following_stream_blocked_filter(query, nil), do: query

  defp apply_following_stream_blocked_filter(query, viewer_id) do
    blocked_ids =
      UserBlock
      |> where([ub], ub.blocker_id == ^viewer_id)
      |> select([ub], ub.blocked_id)
      |> Repo.all()

    blocked_by_ids =
      UserBlock
      |> where([ub], ub.blocked_id == ^viewer_id)
      |> select([ub], ub.blocker_id)
      |> Repo.all()

    excluded_ids = Enum.uniq(blocked_ids ++ blocked_by_ids)

    if excluded_ids == [] do
      query
    else
      where(query, [p], p.user_id not in ^excluded_ids)
    end
  end
end
