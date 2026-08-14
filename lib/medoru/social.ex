defmodule Medoru.Social do
  @moduledoc """
  The Social context.

  Handles user directory, search, blocking, and privacy controls.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo

  alias Medoru.Social.UserBlock
  alias Medoru.Social.Tag
  alias Medoru.Social.UserTag
  alias Medoru.Social.Follow
  alias Medoru.Social.ProfileVisit
  alias Medoru.Accounts
  alias Medoru.Accounts.User

  # ============================================================================
  # User Directory & Search
  # ============================================================================

  @doc """
  Lists users for the public directory.
  Users with a display_name or OAuth name are shown.
  Users who have blocked the viewer are filtered out.
  """
  def list_users(viewer_id \\ nil, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 24)
    tag_id = Keyword.get(opts, :tag_id)
    only_following = Keyword.get(opts, :only_following, false)

    query =
      User
      |> join(:left, [u], p in assoc(u, :profile))
      |> where([u], u.is_deleted == false)
      |> where(
        [u, p],
        (not is_nil(p.display_name) and p.display_name != "") or
          (not is_nil(u.name) and u.name != "")
      )
      |> preload([:profile, :stats])
      |> order_by([u], desc: u.inserted_at)

    query = filter_public_profiles(query)
    query = filter_blocked_by_users(query, viewer_id)
    query = filter_following_only(query, viewer_id, only_following)
    query = filter_by_tag(query, tag_id)

    query
    |> limit(^per_page)
    |> offset((^page - 1) * ^per_page)
    |> Repo.all()
  end

  @doc """
  Searches users by display name or OAuth name.
  Users who have blocked the viewer are filtered out.
  """
  def search_users(query_term, viewer_id \\ nil, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 24)
    tag_id = Keyword.get(opts, :tag_id)

    search_query =
      User
      |> join(:left, [u], p in assoc(u, :profile))
      |> where([u], u.is_deleted == false)
      |> where(
        [u, p],
        (not is_nil(p.display_name) and p.display_name != "") or
          (not is_nil(u.name) and u.name != "")
      )
      |> where(
        [u, p],
        ilike(p.display_name, ^"%#{query_term}%") or
          ilike(u.name, ^"%#{query_term}%")
      )
      |> preload([:profile, :stats])
      |> order_by([u, p], asc: p.display_name)

    search_query = filter_public_profiles(search_query)
    search_query = filter_blocked_by_users(search_query, viewer_id)
    search_query = filter_by_tag(search_query, tag_id)

    search_query
    |> limit(^per_page)
    |> offset((^page - 1) * ^per_page)
    |> Repo.all()
  end

  @doc """
  Counts total users in the directory (for pagination).
  """
  def count_users(viewer_id \\ nil, opts \\ []) do
    tag_id = Keyword.get(opts, :tag_id)
    only_following = Keyword.get(opts, :only_following, false)

    query =
      User
      |> join(:left, [u], p in assoc(u, :profile))
      |> where([u], u.is_deleted == false)
      |> where(
        [u, p],
        (not is_nil(p.display_name) and p.display_name != "") or
          (not is_nil(u.name) and u.name != "")
      )

    query = filter_public_profiles(query)
    query = filter_blocked_by_users(query, viewer_id)
    query = filter_following_only(query, viewer_id, only_following)
    query = filter_by_tag(query, tag_id)
    Repo.aggregate(query, :count, :id)
  end

  @doc """
  Counts search results (for pagination).
  """
  def count_search_users(query_term, viewer_id \\ nil, opts \\ []) do
    tag_id = Keyword.get(opts, :tag_id)

    search_query =
      User
      |> join(:left, [u], p in assoc(u, :profile))
      |> where([u], u.is_deleted == false)
      |> where(
        [u, p],
        (not is_nil(p.display_name) and p.display_name != "") or
          (not is_nil(u.name) and u.name != "")
      )
      |> where(
        [u, p],
        ilike(p.display_name, ^"%#{query_term}%") or
          ilike(u.name, ^"%#{query_term}%")
      )

    search_query = filter_public_profiles(search_query)
    search_query = filter_blocked_by_users(search_query, viewer_id)
    search_query = filter_by_tag(search_query, tag_id)
    Repo.aggregate(search_query, :count, :id)
  end

  # Only show users who have made their profile public.
  # Users without a profile (e.g. OAuth-only) are treated as public.
  defp filter_public_profiles(query) do
    query
    |> where([u, p], is_nil(p.id) or p.is_public == true)
  end

  # Always filter out users who have blocked the viewer (privacy).
  defp filter_blocked_by_users(query, nil), do: query

  defp filter_blocked_by_users(query, viewer_id) do
    blocked_by_subquery =
      UserBlock
      |> where([ub], ub.blocked_id == ^viewer_id)
      |> select([ub], ub.blocker_id)

    query
    |> where([u], u.id not in subquery(blocked_by_subquery))
  end

  # When only_following is true (student/teacher browsing without search),
  # restrict to users the viewer follows.
  defp filter_following_only(query, _viewer_id, false), do: query
  defp filter_following_only(query, nil, _only_following), do: query

  defp filter_following_only(query, viewer_id, true) do
    following_subquery =
      Follow
      |> where([f], f.follower_id == ^viewer_id)
      |> select([f], f.following_id)

    query
    |> where([u], u.id in subquery(following_subquery))
  end

  defp filter_by_tag(query, nil), do: query
  defp filter_by_tag(query, ""), do: query

  defp filter_by_tag(query, tag_id) do
    query
    |> join(:inner, [u], ut in UserTag, on: ut.user_id == u.id)
    |> where([u, p, ut], ut.tag_id == ^tag_id)
  end

  # ============================================================================
  # Tags
  # ============================================================================

  @doc """
  Creates a new tag.
  """
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag.
  """
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tag and its associated user_tags.
  """
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @doc """
  Gets a single tag.
  Raises `Ecto.NoResultsError` if the tag does not exist.
  """
  def get_tag!(id), do: Repo.get!(Tag, id)

  @doc """
  Lists all official tags ordered by category and order_index.
  """
  def list_tags do
    Tag
    |> where([t], t.is_official == true)
    |> order_by([t], asc: t.category, asc: t.order_index)
    |> Repo.all()
  end

  @doc """
  Lists tags with pagination and filtering.
  Shows all tags (including non-official) for admin use.
  """
  def list_tags_paginated(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 30)
    search = Keyword.get(opts, :search)
    category = Keyword.get(opts, :category)

    query =
      Tag
      |> order_by([t], asc: t.category, asc: t.order_index)

    query =
      if category && category != "" do
        where(query, [t], t.category == ^category)
      else
        query
      end

    query =
      if search && search != "" do
        where(query, [t], ilike(t.name, ^"%#{search}%"))
      else
        query
      end

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = max(1, ceil(total_count / per_page))

    tags =
      query
      |> limit(^per_page)
      |> offset((^page - 1) * ^per_page)
      |> Repo.all()

    %{
      tags: tags,
      current_page: page,
      total_pages: total_pages,
      total_count: total_count
    }
  end

  @doc """
  Returns all distinct tag categories.
  """
  def list_tag_categories do
    Tag
    |> where([t], t.is_official == true)
    |> distinct(true)
    |> select([t], t.category)
    |> order_by([t], asc: t.category)
    |> Repo.all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag changes.
  """
  def change_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end

  @doc """
  Gets a tag by its slug.
  """
  def get_tag_by_slug!(slug), do: Repo.get_by!(Tag, slug: slug)

  @doc """
  Lists tags for a specific user.
  """
  def list_user_tags(user_id) do
    Tag
    |> join(:inner, [t], ut in UserTag, on: ut.tag_id == t.id)
    |> where([t, ut], ut.user_id == ^user_id)
    |> order_by([t, ut], asc: t.category, asc: t.order_index)
    |> Repo.all()
  end

  @doc """
  Sets a user's tags, replacing any existing selection.
  Enforces a maximum of 15 tags.
  """
  def set_user_tags(user_id, tag_ids) when is_list(tag_ids) do
    tag_ids = tag_ids |> Enum.take(15) |> Enum.uniq()

    Repo.transaction(fn ->
      # Delete existing tags
      UserTag
      |> where([ut], ut.user_id == ^user_id)
      |> Repo.delete_all()

      # Insert new tags
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      entries =
        Enum.map(tag_ids, fn tag_id ->
          %{
            id: Ecto.UUID.generate(),
            user_id: user_id,
            tag_id: tag_id,
            inserted_at: now,
            updated_at: now
          }
        end)

      if entries != [] do
        Repo.insert_all(UserTag, entries)
      end

      :ok
    end)
  end

  @doc """
  Returns the IDs of tags selected by a user.
  """
  def list_user_tag_ids(user_id) do
    UserTag
    |> where([ut], ut.user_id == ^user_id)
    |> select([ut], ut.tag_id)
    |> Repo.all()
  end

  # ============================================================================
  # Following
  # ============================================================================

  @doc """
  Follows a user.
  """
  def follow_user(follower_id, following_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    result =
      %Follow{}
      |> Follow.changeset(%{
        follower_id: follower_id,
        following_id: following_id,
        followed_at: now
      })
      |> Repo.insert()

    with {:ok, _} <- result do
      _ =
        Accounts.add_xp(follower_id, 10,
          source_type: "follow_user",
          description: "Followed a user"
        )
    end

    result
  end

  @doc """
  Unfollows a user.
  """
  def unfollow_user(follower_id, following_id) do
    Follow
    |> where([f], f.follower_id == ^follower_id and f.following_id == ^following_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Checks if user_a follows user_b.
  """
  def following?(follower_id, following_id) do
    Follow
    |> where([f], f.follower_id == ^follower_id and f.following_id == ^following_id)
    |> Repo.exists?()
  end

  @doc """
  Counts followers for a user.
  """
  def count_followers(user_id) do
    Follow
    |> where([f], f.following_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts how many users a user is following.
  """
  def count_following(user_id) do
    Follow
    |> where([f], f.follower_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Lists followers of a user with their profiles.
  """
  def list_followers(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 24)

    Follow
    |> where([f], f.following_id == ^user_id)
    |> join(:inner, [f], u in assoc(f, :follower))
    |> preload([f, u], follower: [:profile, :stats])
    |> order_by([f], desc: f.followed_at)
    |> limit(^per_page)
    |> offset((^page - 1) * ^per_page)
    |> Repo.all()
    |> Enum.map(& &1.follower)
  end

  @doc """
  Lists users that a user is following with their profiles.
  """
  def list_following(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 24)

    Follow
    |> where([f], f.follower_id == ^user_id)
    |> join(:inner, [f], u in assoc(f, :following))
    |> preload([f, u], following: [:profile, :stats])
    |> order_by([f], desc: f.followed_at)
    |> limit(^per_page)
    |> offset((^page - 1) * ^per_page)
    |> Repo.all()
    |> Enum.map(& &1.following)
  end

  @doc """
  Returns the list of user IDs that a user is following.
  """
  def list_following_ids(follower_id) do
    Follow
    |> where([f], f.follower_id == ^follower_id)
    |> select([f], f.following_id)
    |> Repo.all()
  end

  @doc """
  Returns the list of user IDs that follow the given user.
  """
  def list_follower_ids(user_id) do
    Follow
    |> where([f], f.following_id == ^user_id)
    |> select([f], f.follower_id)
    |> Repo.all()
  end

  @doc """
  Lists users who are mutual followers with the given user.
  (They follow the user AND the user follows them back.)
  """
  def list_mutual_follows(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 100)

    following_ids =
      Follow
      |> where([f], f.follower_id == ^user_id)
      |> select([f], f.following_id)

    follower_ids =
      Follow
      |> where([f], f.following_id == ^user_id)
      |> select([f], f.follower_id)

    User
    |> where([u], u.id in subquery(following_ids))
    |> where([u], u.id in subquery(follower_ids))
    |> where([u], u.is_deleted == false)
    |> preload([:profile, :stats])
    |> order_by([u], asc: u.inserted_at)
    |> limit(^per_page)
    |> offset((^page - 1) * ^per_page)
    |> Repo.all()
  end

  @doc """
  Returns true if two users are mutual followers.
  """
  def mutual_followers?(user_a_id, user_b_id) do
    following?(user_a_id, user_b_id) and following?(user_b_id, user_a_id)
  end

  # ============================================================================
  # Blocking
  # ============================================================================

  @doc """
  Blocks a user.
  """
  def block_user(blocker_id, blocked_id, reason \\ nil) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    result =
      %UserBlock{}
      |> UserBlock.changeset(%{
        blocker_id: blocker_id,
        blocked_id: blocked_id,
        reason: reason,
        blocked_at: now
      })
      |> Repo.insert()

    # Silently unfollow in both directions
    unfollow_user(blocker_id, blocked_id)
    unfollow_user(blocked_id, blocker_id)

    result
  end

  @doc """
  Unblocks a user.
  """
  def unblock_user(blocker_id, blocked_id) do
    UserBlock
    |> where([ub], ub.blocker_id == ^blocker_id and ub.blocked_id == ^blocked_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Lists all users blocked by a given user.
  """
  def list_blocked_users(blocker_id) do
    UserBlock
    |> where([ub], ub.blocker_id == ^blocker_id)
    |> preload(blocked: :profile)
    |> order_by([ub], desc: ub.blocked_at)
    |> Repo.all()
  end

  @doc """
  Checks if user_a has blocked user_b (either direction).
  Returns :blocked if either direction is blocked, :ok otherwise.
  """
  def is_blocked?(user_a_id, user_b_id) do
    blocked? =
      UserBlock
      |> where(
        [ub],
        (ub.blocker_id == ^user_a_id and ub.blocked_id == ^user_b_id) or
          (ub.blocker_id == ^user_b_id and ub.blocked_id == ^user_a_id)
      )
      |> Repo.exists?()

    if blocked?, do: :blocked, else: :ok
  end

  @doc """
  Checks if a specific user has blocked another.
  """
  def blocked_by?(blocker_id, blocked_id) do
    UserBlock
    |> where([ub], ub.blocker_id == ^blocker_id and ub.blocked_id == ^blocked_id)
    |> Repo.exists?()
  end

  @doc """
  Checks if messaging is allowed between two users.
  Returns true if neither has blocked the other and both have profiles.
  """
  def can_message?(sender_id, recipient_id) do
    cond do
      sender_id == recipient_id ->
        false

      true ->
        not blocked_by?(sender_id, recipient_id) and
          not blocked_by?(recipient_id, sender_id)
    end
  end

  # ============================================================================
  # Profile Visits
  # ============================================================================

  @doc """
  Records a profile visit from `visitor_id` to `visited_user_id`.

  Does nothing if:
    * the visitor is the profile owner
    * either user has blocked the other
    * the visitor is nil

  Repeated visits update the existing row with the latest timestamp.
  """
  def record_profile_visit(nil, _visited_user_id), do: :ok

  def record_profile_visit(visitor_id, visited_user_id) when visitor_id == visited_user_id,
    do: :ok

  def record_profile_visit(visitor_id, visited_user_id) do
    if is_blocked?(visitor_id, visited_user_id) == :blocked do
      :ok
    else
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %ProfileVisit{}
      |> ProfileVisit.changeset(%{
        visitor_id: visitor_id,
        visited_user_id: visited_user_id,
        visited_at: now
      })
      |> Repo.insert(
        on_conflict: [set: [visited_at: now, updated_at: now]],
        conflict_target: [:visitor_id, :visited_user_id]
      )
      |> case do
        {:ok, _} -> :ok
        {:error, _} -> :ok
      end
    end
  end

  @doc """
  Counts unique users who have visited the given user's profile.
  Excludes users who have blocked the owner or been blocked by the owner.
  """
  def count_visitors(user_id) do
    ProfileVisit
    |> where([pv], pv.visited_user_id == ^user_id)
    |> join(:inner, [pv], u in assoc(pv, :visitor))
    |> exclude_blocked_visitors(user_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Lists visitors of a user's profile, ordered by most recent visit first.
  Excludes users who have blocked the owner or been blocked by the owner.

  Options:
    * `:page` - page number (default 1)
    * `:per_page` - page size (default 24)
  """
  def list_visitors(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 24)

    ProfileVisit
    |> where([pv], pv.visited_user_id == ^user_id)
    |> join(:inner, [pv], u in assoc(pv, :visitor))
    |> exclude_blocked_visitors(user_id)
    |> preload([pv, u], visitor: [:profile, :stats])
    |> order_by([pv], desc: pv.visited_at)
    |> limit(^per_page)
    |> offset((^page - 1) * ^per_page)
    |> Repo.all()
    |> Enum.map(&%{user: &1.visitor, visited_at: &1.visited_at})
  end

  # Exclude visitors where either direction of block exists between the owner
  # and the visitor.
  defp exclude_blocked_visitors(query, user_id) do
    query
    |> join(:left, [pv, u], ub in UserBlock,
      on:
        (ub.blocker_id == ^user_id and ub.blocked_id == u.id) or
          (ub.blocked_id == ^user_id and ub.blocker_id == u.id)
    )
    |> where([pv, u, ub], is_nil(ub.id))
  end
end
