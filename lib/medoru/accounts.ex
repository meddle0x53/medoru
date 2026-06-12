defmodule Medoru.Accounts do
  @moduledoc """
  The Accounts context handles user management, authentication, and profiles.
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Accounts.{ApiToken, User, UserProfile, UserStats, XpTransaction}
  alias Medoru.Gamification
  alias Medoru.Notifications

  @doc """
  Returns the list of users.
  """
  def list_users do
    User
    |> where([u], u.is_deleted == false)
    |> Repo.all()
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.
  """
  def get_user!(id) do
    User
    |> where([u], u.is_deleted == false)
    |> Repo.get!(id)
  end

  @doc """
  Gets a single user by id.

  Returns nil if the User does not exist.
  """
  def get_user(id) do
    User
    |> where([u], u.is_deleted == false)
    |> Repo.get(id)
  end

  @doc """
  Gets a single user with preloaded profile.
  Returns nil if the User does not exist.
  """
  def get_user_with_profile(id) do
    User
    |> where(id: ^id)
    |> where([u], u.is_deleted == false)
    |> preload([:profile])
    |> Repo.one()
  end

  @doc """
  Gets a single user with preloaded profile and stats.
  """
  def get_user_with_profile_and_stats!(id) do
    User
    |> where(id: ^id)
    |> where([u], u.is_deleted == false)
    |> preload([:profile, :stats])
    |> Repo.one!()
  end

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    User
    |> where(email: ^email)
    |> where([u], u.is_deleted == false)
    |> Repo.one()
  end

  @doc """
  Gets a user by provider and provider_uid.
  """
  def get_user_by_provider_uid(provider, provider_uid) do
    User
    |> where(provider: ^provider, provider_uid: ^provider_uid)
    |> where([u], u.is_deleted == false)
    |> Repo.one()
  end

  @doc """
  Gets a user by provider and provider_uid, including deleted users.
  Used during OAuth callback to detect suspended accounts.
  """
  def get_user_by_provider_uid_including_deleted(provider, provider_uid) do
    User
    |> where(provider: ^provider, provider_uid: ^provider_uid)
    |> Repo.one()
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
           {:ok, _profile} <- create_user_profile(user, %{avatar: user_attrs[:avatar_url]}),
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
  Soft-deletes a user. The user will not be able to log in,
  but their data is preserved.
  """
  def delete_user(%User{} = user) do
    user
    |> User.soft_delete_changeset(%{is_deleted: true})
    |> Repo.update()
  end

  @doc """
  Restores a soft-deleted user.
  """
  def restore_user(%User{} = user) do
    user
    |> User.soft_delete_changeset(%{is_deleted: false})
    |> Repo.update()
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
    show_deleted = Keyword.get(opts, :show_deleted, false)

    offset = (page - 1) * per_page

    query =
      User
      |> maybe_filter_deleted(show_deleted)
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

  defp maybe_filter_deleted(query, true), do: where(query, [u], u.is_deleted == true)
  defp maybe_filter_deleted(query, _), do: where(query, [u], u.is_deleted == false)

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
  Updates a user's moderator flag.
  """
  def update_user_moderator(%User{} = user, moderator) when is_boolean(moderator) do
    user
    |> User.moderator_changeset(%{moderator: moderator})
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
  Gets a single user with profile and stats, including deleted users.
  Returns nil if the User does not exist.
  """
  def get_user_with_profile_including_deleted(id) do
    User
    |> where(id: ^id)
    |> preload([:profile])
    |> Repo.one()
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
  Resets all progress for a user. This deletes:
  - Test step answers and test sessions
  - Lesson progress and classroom lesson progress
  - User stats (XP, level, streak)
  - Classroom membership points

  Returns {:ok, stats} with the count of deleted records.
  """
  def reset_user_progress(user_id) do
    import Ecto.Query

    # Delete test step answers for user's sessions
    {test_step_answers_deleted, _} =
      Repo.delete_all(
        from tsa in Medoru.Tests.TestStepAnswer,
          where:
            tsa.test_session_id in subquery(
              from ts in Medoru.Tests.TestSession,
                where: ts.user_id == ^user_id,
                select: ts.id
            )
      )

    # Delete test sessions
    {test_sessions_deleted, _} =
      Repo.delete_all(from ts in Medoru.Tests.TestSession, where: ts.user_id == ^user_id)

    # Delete lesson progress
    {lesson_progress_deleted, _} =
      Repo.delete_all(from lp in Medoru.Learning.LessonProgress, where: lp.user_id == ^user_id)

    # Delete classroom lesson progress
    {classroom_progress_deleted, _} =
      Repo.delete_all(
        from clp in Medoru.Classrooms.ClassroomLessonProgress, where: clp.user_id == ^user_id
      )

    # Delete classroom test attempts
    {test_attempts_deleted, _} =
      Repo.delete_all(
        from cta in Medoru.Classrooms.ClassroomTestAttempt, where: cta.user_id == ^user_id
      )

    # Reset classroom membership points
    {memberships_updated, _} =
      Repo.update_all(
        from(cm in Medoru.Classrooms.ClassroomMembership,
          where: cm.user_id == ^user_id,
          update: [set: [points: 0]]
        ),
        []
      )

    # Reset user stats
    {stats_updated, _} =
      Repo.update_all(
        from(us in UserStats,
          where: us.user_id == ^user_id,
          update: [set: [xp: 0, level: 0, streak: 0, longest_streak: 0]]
        ),
        []
      )

    # Delete user progress (kanji/word learning records)
    {user_progress_deleted, _} =
      Repo.delete_all(from up in Medoru.Learning.UserProgress, where: up.user_id == ^user_id)

    stats = %{
      test_step_answers_deleted: test_step_answers_deleted,
      test_sessions_deleted: test_sessions_deleted,
      lesson_progress_deleted: lesson_progress_deleted,
      classroom_progress_deleted: classroom_progress_deleted,
      test_attempts_deleted: test_attempts_deleted,
      memberships_updated: memberships_updated,
      stats_reset: stats_updated,
      user_progress_deleted: user_progress_deleted
    }

    {:ok, stats}
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
    |> where([u], u.is_deleted == false)
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
    |> where([u], u.is_deleted == false)
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
  Adds XP to a user, creates an audit transaction, and levels them up if needed.

  Returns `{:ok, %{stats: UserStats, transaction: XpTransaction, leveled_up: boolean}}`.

  ## Examples

      iex> add_xp(user, 50, source_type: "test_step", description: "Correct answer")
      {:ok, %{stats: %UserStats{}, transaction: %XpTransaction{}, leveled_up: false}}

  """
  def add_xp(user_or_id, amount, opts \\ [])

  def add_xp(%User{} = user, amount, opts) when is_integer(amount) and amount > 0 do
    stats = get_or_create_user_stats(user.id)
    old_level = stats.level
    new_xp = stats.xp + amount
    new_level = calculate_level(new_xp)
    leveled_up = new_level > old_level

    # Build transaction
    source_type = Keyword.get(opts, :source_type, "unknown")
    source_id = Keyword.get(opts, :source_id)
    description = Keyword.get(opts, :description)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    transaction_attrs = %{
      user_id: user.id,
      amount: amount,
      source_type: source_type,
      source_id: source_id,
      description: description,
      awarded_at: now
    }

    result =
      Repo.transaction(fn ->
        # Update stats
        {:ok, updated_stats} =
          stats
          |> UserStats.changeset(%{xp: new_xp, level: new_level})
          |> Repo.update()

        # Create audit log
        transaction =
          %XpTransaction{}
          |> XpTransaction.changeset(transaction_attrs)
          |> Repo.insert!()

        %{stats: updated_stats, transaction: transaction, leveled_up: leveled_up}
      end)

    # Check for level-up badges and notify (skip if triggered by badge XP to avoid recursion)
    with {:ok, %{leveled_up: true, stats: updated_stats}} <- result,
         true <- source_type != "badge_earned" do
      Gamification.check_level_badges(user.id, updated_stats.level)
      _ = Notifications.notify_level_up(user.id, updated_stats.level)
    end

    result
  end

  def add_xp(user_id, amount, opts)
      when is_binary(user_id) and is_integer(amount) and amount > 0 do
    user = get_user!(user_id)
    add_xp(user, amount, opts)
  end

  @doc """
  Calculates the level for a given total XP amount.

  Formula: level is the largest n where 100n² + 900n <= total_xp.
  """
  def calculate_level(total_xp) when is_integer(total_xp) and total_xp >= 0 do
    # Solve 100n² + 900n - xp = 0 using quadratic formula
    # n = (-900 + sqrt(900² + 400*xp)) / 200
    discriminant = 900 * 900 + 400 * total_xp
    n = (-900 + :math.sqrt(discriminant)) / 200
    trunc(n)
  end

  @doc """
  Returns the total XP required to reach a given level.
  """
  def xp_for_level(level) when is_integer(level) and level >= 0 do
    100 * level * level + 900 * level
  end

  @doc """
  Returns XP progress info: current XP, XP needed for current level,
  XP needed for next level, and progress percentage.
  """
  def xp_progress(%UserStats{xp: xp, level: level}) do
    current_level_xp = xp_for_level(level)
    next_level_xp = xp_for_level(level + 1)
    xp_into_level = xp - current_level_xp
    xp_needed = next_level_xp - current_level_xp

    progress =
      cond do
        xp_needed <= 0 -> 100
        xp_into_level >= xp_needed -> 100
        xp_into_level <= 0 -> 0
        true -> trunc(xp_into_level / xp_needed * 100)
      end

    %{
      current_xp: xp,
      current_level: level,
      xp_into_level: max(xp_into_level, 0),
      xp_needed_for_next: xp_needed,
      xp_to_level_up: max(xp_needed - xp_into_level, 0),
      progress_percent: progress
    }
  end

  # ============================================================================
  # Badge Functions
  # ============================================================================

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
  # API Tokens
  # ============================================================================

  @max_api_tokens 3

  @doc """
  Returns the list of API tokens for a user.
  """
  def list_user_api_tokens(user_id) do
    ApiToken
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the count of API tokens for a user.
  """
  def count_user_api_tokens(user_id) do
    ApiToken
    |> where([t], t.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Creates a new API token for a user.

  Returns `{:ok, token_struct, plaintext_token}` on success.
  Returns `{:error, :limit_reached}` if the user already has 3 tokens.
  Returns `{:error, changeset}` on validation failure.

  The plaintext token is shown only once to the user.
  """
  def create_api_token(user_id, attrs \\ %{}) do
    if count_user_api_tokens(user_id) >= @max_api_tokens do
      {:error, :limit_reached}
    else
      plaintext = generate_token()
      token_hash = hash_token(plaintext)

      expires_at =
        case attrs["expires_in_days"] || attrs[:expires_in_days] do
          nil ->
            nil

          "" ->
            nil

          days when is_binary(days) ->
            case Integer.parse(days) do
              {n, _} when n > 0 -> DateTime.utc_now() |> DateTime.add(n, :day)
              _ -> nil
            end

          days when is_integer(days) and days > 0 ->
            DateTime.utc_now() |> DateTime.add(days, :day)

          _ ->
            nil
        end

      api_token_attrs = %{
        user_id: user_id,
        name: attrs["name"] || attrs[:name],
        token_hash: token_hash,
        expires_at: expires_at
      }

      %ApiToken{}
      |> ApiToken.changeset(api_token_attrs)
      |> Repo.insert()
      |> case do
        {:ok, token} -> {:ok, token, plaintext}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  @doc """
  Deletes an API token ensuring it belongs to the given user.
  """
  def delete_api_token(user_id, token_id) do
    ApiToken
    |> where([t], t.id == ^token_id and t.user_id == ^user_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      token -> Repo.delete(token)
    end
  end

  @doc """
  Verifies a raw API token and returns the associated token struct if valid.

  Returns `{:ok, token}` if the token is valid and not expired.
  Returns `{:error, :invalid}` otherwise.
  """
  def verify_api_token(plaintext) do
    token_hash = hash_token(plaintext)

    ApiToken
    |> where([t], t.token_hash == ^token_hash)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :invalid}

      token ->
        if token.expires_at && DateTime.compare(token.expires_at, DateTime.utc_now()) == :lt do
          {:error, :expired}
        else
          {:ok, token}
        end
    end
  end

  @doc """
  Updates the last_used_at timestamp for an API token.
  """
  def touch_api_token(%ApiToken{} = token) do
    token
    |> ApiToken.changeset(%{last_used_at: DateTime.utc_now()})
    |> Repo.update()
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp hash_token(plaintext) do
    :crypto.hash(:sha256, plaintext) |> Base.encode16(case: :lower)
  end

  # ============================================================================
  # Admin Stats Functions
  # ============================================================================

  @doc """
  Returns system statistics for admin dashboard.
  """
  def get_admin_stats do
    total_users =
      User
      |> where([u], u.is_deleted == false)
      |> Repo.aggregate(:count, :id)

    users_by_type =
      User
      |> where([u], u.is_deleted == false)
      |> group_by([u], u.type)
      |> select([u], {u.type, count(u.id)})
      |> Repo.all()
      |> Enum.into(%{})

    new_users_today =
      User
      |> where([u], u.is_deleted == false)
      |> where([u], fragment("?::date", u.inserted_at) == fragment("CURRENT_DATE"))
      |> Repo.aggregate(:count, :id)

    new_users_this_week =
      User
      |> where([u], u.is_deleted == false)
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
