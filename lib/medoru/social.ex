defmodule Medoru.Social do
  @moduledoc """
  The Social context.

  Handles user directory, search, blocking, and privacy controls.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo

  alias Medoru.Social.UserBlock
  alias Medoru.Accounts.User

  # ============================================================================
  # User Directory & Search
  # ============================================================================

  @doc """
  Lists users for the public directory.
  Users with a display_name or OAuth name are shown.
  Blocked users are filtered out.
  """
  def list_users(viewer_id \\ nil, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 24)

    query =
      User
      |> join(:left, [u], p in assoc(u, :profile))
      |> where([u, p],
        (not is_nil(p.display_name) and p.display_name != "") or
        (not is_nil(u.name) and u.name != "")
      )
      |> preload([:profile, :stats])
      |> order_by([u], desc: u.inserted_at)

    query = filter_blocked_users(query, viewer_id)

    query
    |> limit(^per_page)
    |> offset((^page - 1) * ^per_page)
    |> Repo.all()
  end

  @doc """
  Searches users by display name or OAuth name.
  Blocked users are filtered out.
  """
  def search_users(query_term, viewer_id \\ nil, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 24)

    search_query =
      User
      |> join(:left, [u], p in assoc(u, :profile))
      |> where([u, p],
        (not is_nil(p.display_name) and p.display_name != "") or
        (not is_nil(u.name) and u.name != "")
      )
      |> where([u, p],
        ilike(p.display_name, ^"%#{query_term}%") or
        ilike(u.name, ^"%#{query_term}%")
      )
      |> preload([:profile, :stats])
      |> order_by([u, p], asc: p.display_name)

    search_query = filter_blocked_users(search_query, viewer_id)

    search_query
    |> limit(^per_page)
    |> offset((^page - 1) * ^per_page)
    |> Repo.all()
  end

  @doc """
  Counts total users in the directory (for pagination).
  """
  def count_users(viewer_id \\ nil) do
    query =
      User
      |> join(:left, [u], p in assoc(u, :profile))
      |> where([u, p],
        (not is_nil(p.display_name) and p.display_name != "") or
        (not is_nil(u.name) and u.name != "")
      )

    query = filter_blocked_users(query, viewer_id)
    Repo.aggregate(query, :count, :id)
  end

  @doc """
  Counts search results (for pagination).
  """
  def count_search_users(query_term, viewer_id \\ nil) do
    search_query =
      User
      |> join(:left, [u], p in assoc(u, :profile))
      |> where([u, p],
        (not is_nil(p.display_name) and p.display_name != "") or
        (not is_nil(u.name) and u.name != "")
      )
      |> where([u, p],
        ilike(p.display_name, ^"%#{query_term}%") or
        ilike(u.name, ^"%#{query_term}%")
      )

    search_query = filter_blocked_users(search_query, viewer_id)
    Repo.aggregate(search_query, :count, :id)
  end

  defp filter_blocked_users(query, nil), do: query

  defp filter_blocked_users(query, viewer_id) do
    blocked_subquery =
      UserBlock
      |> where([ub], ub.blocker_id == ^viewer_id)
      |> select([ub], ub.blocked_id)

    query
    |> where([u], u.id not in subquery(blocked_subquery))
  end

  # ============================================================================
  # Blocking
  # ============================================================================

  @doc """
  Blocks a user.
  """
  def block_user(blocker_id, blocked_id, reason \\ nil) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %UserBlock{}
    |> UserBlock.changeset(%{
      blocker_id: blocker_id,
      blocked_id: blocked_id,
      reason: reason,
      blocked_at: now
    })
    |> Repo.insert()
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
end
