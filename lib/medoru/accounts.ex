defmodule Medoru.Accounts do
  @moduledoc """
  The Accounts context handles user management, authentication, and profiles.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Accounts.{User, UserProfile, UserStats}

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by id.

  Returns nil if the User does not exist.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a single user with preloaded profile.
  Returns nil if the User does not exist.
  """
  def get_user_with_profile(id) do
    User
    |> where(id: ^id)
    |> preload([:profile])
    |> Repo.one()
  end

  @doc """
  Gets a single user with preloaded profile and stats.
  """
  def get_user_with_profile_and_stats!(id) do
    User
    |> where(id: ^id)
    |> preload([:profile, :stats])
    |> Repo.one!()
  end

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by provider and provider_uid.
  """
  def get_user_by_provider_uid(provider, provider_uid) do
    Repo.get_by(User, provider: provider, provider_uid: provider_uid)
  end

  @doc """
  Registers a new user from OAuth data.

  ## Examples

      iex> register_user_with_oauth(%{email: "user@example.com", provider: "google", ...})
      {:ok, %User{}}

      iex> register_user_with_oauth(%{email: nil})
      {:error, %Ecto.Changeset{}}
  """
  def register_user_with_oauth(attrs) do
    Repo.transaction(fn ->
      email = attrs[:email] || attrs["email"]

      # Auto-assign admin role for specific email, otherwise use provided type or default to student
      type =
        cond do
          email == "n.tzvetinov@gmail.com" -> "admin"
          attrs[:type] || attrs["type"] -> attrs[:type] || attrs["type"]
          true -> "student"
        end

      user_attrs = %{
        email: email,
        provider: attrs[:provider] || attrs["provider"],
        provider_uid: attrs[:provider_uid] || attrs["provider_uid"],
        name: attrs[:name] || attrs["name"],
        avatar_url: attrs[:avatar_url] || attrs["avatar_url"],
        type: type
      }

      with {:ok, user} <- create_user(user_attrs),
           {:ok, _profile} <- create_user_profile(user),
           {:ok, _stats} <- create_user_stats(user) do
        user |> Repo.preload([:profile, :stats])
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user and all associated data.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  # Admin User Management

  @doc """
  Returns a paginated list of users for admin.
  Supports filtering by type and searching by email/name.
  Returns {users, total_count} tuple.
  """
  def list_users_for_admin(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    type_filter = Keyword.get(opts, :type)
    search = Keyword.get(opts, :search)

    offset = (page - 1) * per_page

    query =
      User
      |> maybe_filter_by_type(type_filter)
      |> maybe_search_users(search)

    users =
      query
      |> order_by([u], desc: u.inserted_at)
      |> preload([:profile, :stats])
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    total_count = Repo.aggregate(query, :count, :id)

    {users, total_count}
  end

  defp maybe_filter_by_type(query, nil), do: query

  defp maybe_filter_by_type(query, type) when type in ["student", "teacher", "admin"] do
    where(query, type: ^type)
  end

  defp maybe_filter_by_type(query, _), do: query

  defp maybe_search_users(query, nil), do: query
  defp maybe_search_users(query, ""), do: query

  defp maybe_search_users(query, search) do
    search_term = "%#{search}%"

    query
    |> where(
      [u],
      ilike(u.email, ^search_term) or
        ilike(u.name, ^search_term)
    )
  end

  @doc """
  Updates a user's type (admin only).
  """
  def update_user_type(%User{} = user, type) when type in ["student", "teacher", "admin"] do
    user
    |> User.type_changeset(%{type: type})
    |> Repo.update()
  end

  @doc """
  Gets a single user with profile and stats for admin.
  """
  def get_user_for_admin!(id) do
    User
    |> where(id: ^id)
    |> preload([:profile, :stats])
    |> Repo.one!()
  end

  @doc """
  Gets a user by email for admin operations.
  """
  def get_user_by_email_for_admin(email) when is_binary(email) do
    User
    |> where(email: ^email)
    |> preload([:profile, :stats])
    |> Repo.one()
  end

  @doc """
  Gets a user profile by user id.
  """
  def get_profile_by_user!(user_id) do
    UserProfile
    |> where(user_id: ^user_id)
    |> Repo.one!()
  end

  @doc """
  Gets a user profile by user id, returns nil if not found.
  """
  def get_user_profile(user_id) do
    UserProfile
    |> where(user_id: ^user_id)
    |> Repo.one()
  end

  @doc """
  Gets a user with their profile and stats by display name.
  Returns nil if not found.
  """
  def get_user_by_display_name(display_name) when is_binary(display_name) do
    User
    |> join(:inner, [u], p in assoc(u, :profile))
    |> where([u, p], p.display_name == ^display_name)
    |> preload([:profile, :stats])
    |> Repo.one()
  end

  @doc """
  Gets a user with their profile and stats by id.
  """
  def get_user_with_profile!(id) do
    User
    |> where(id: ^id)
    |> preload([:profile, :stats])
    |> Repo.one!()
  end

  @doc """
  Creates a user profile for a user.
  """
  def create_user_profile(%User{} = user, attrs \\ %{}) do
    %UserProfile{user_id: user.id}
    |> UserProfile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user profile.
  """
  def update_profile(%UserProfile{} = profile, attrs) do
    profile
    |> UserProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking profile changes.
  """
  def change_profile(%UserProfile{} = profile, attrs \\ %{}) do
    UserProfile.changeset(profile, attrs)
  end

  @doc """
  Updates user settings (stored in profile).
  """
  def update_settings(%User{} = user, settings_attrs) do
    profile = get_profile_by_user!(user.id)
    update_profile(profile, settings_attrs)
  end

  @doc """
  Updates user's daily test step type preferences.
  """
  def update_user_daily_test_preferences(user_id, step_types) when is_list(step_types) do
    profile = get_profile_by_user!(user_id)

    update_profile(profile, %{daily_test_step_types: step_types})
  end

  @doc """
  Gets user stats by user id.
  """
  def get_stats_by_user!(user_id) do
    UserStats
    |> where(user_id: ^user_id)
    |> Repo.one!()
  end

  @doc """
  Creates user stats for a user.
  """
  def create_user_stats(%User{} = user, attrs \\ %{}) do
    %UserStats{user_id: user.id}
    |> UserStats.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets or creates user stats for a user.
  """
  def get_or_create_user_stats(user_id) do
    case Repo.get_by(UserStats, user_id: user_id) do
      nil ->
        %UserStats{user_id: user_id}
        |> UserStats.changeset(%{})
        |> Repo.insert!()

      stats ->
        stats
    end
  end

  @doc """
  Updates user stats.
  """
  def update_stats(%UserStats{} = stats, attrs) do
    stats
    |> UserStats.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Adds XP to a user and potentially levels them up.
  """
  def add_xp(%User{} = user, amount) when is_integer(amount) and amount > 0 do
    stats = get_stats_by_user!(user.id)
    new_xp = stats.xp + amount
    new_level = calculate_level(new_xp)

    update_stats(stats, %{
      xp: new_xp,
      level: new_level
    })
  end

  defp calculate_level(xp) do
    # Simple level formula: level = floor(sqrt(xp / 100)) + 1
    # Level 1: 0 XP
    # Level 2: 100 XP
    # Level 3: 400 XP
    # Level 4: 900 XP
    trunc(:math.sqrt(xp / 100)) + 1
  end

  # ============================================================================
  # Badge Functions
  # ============================================================================

  alias Medoru.Gamification

  @doc """
  Gets all badges earned by a user.
  """
  def get_user_badges(user_id) do
    Gamification.list_user_badges(user_id)
  end

  @doc """
  Sets a user's featured badge.
  """
  def set_user_featured_badge(user_id, badge_id) do
    Gamification.set_featured_badge(user_id, badge_id)
  end

  @doc """
  Removes a user's featured badge.
  """
  def remove_user_featured_badge(user_id) do
    Gamification.remove_featured_badge(user_id)
  end

  @doc """
  Gets a user's featured badge.
  """
  def get_user_featured_badge(user_id) do
    Gamification.get_featured_badge(user_id)
  end

  @doc """
  Awards a badge to a user.
  """
  def award_badge_to_user(user_id, badge_id) do
    Gamification.award_badge(user_id, badge_id)
  end

  # ============================================================================
  # Admin Stats Functions
  # ============================================================================

  @doc """
  Returns system statistics for admin dashboard.
  """
  def get_admin_stats do
    total_users = Repo.aggregate(User, :count, :id)

    users_by_type =
      User
      |> group_by([u], u.type)
      |> select([u], {u.type, count(u.id)})
      |> Repo.all()
      |> Enum.into(%{})

    new_users_today =
      User
      |> where([u], fragment("?::date", u.inserted_at) == fragment("CURRENT_DATE"))
      |> Repo.aggregate(:count, :id)

    new_users_this_week =
      User
      |> where(
        [u],
        fragment("?::date", u.inserted_at) >= fragment("CURRENT_DATE - INTERVAL '7 days'")
      )
      |> Repo.aggregate(:count, :id)

    %{
      total_users: total_users,
      users_by_type: users_by_type,
      new_users_today: new_users_today,
      new_users_this_week: new_users_this_week
    }
  end
end
