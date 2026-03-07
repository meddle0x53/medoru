defmodule Medoru.Gamification do
  @moduledoc """
  The Gamification context.

  This context handles badges, achievements, and user rewards.
  It provides functions to:
  - Manage badge definitions
  - Award badges to users
  - Track user achievements
  - Display featured badges on profiles
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Gamification.{Badge, UserBadge}
  alias Medoru.Notifications

  # ============================================================================
  # Badge Management
  # ============================================================================

  @doc """
  Returns the list of all badges ordered by order_index.

  ## Examples

      iex> list_badges()
      [%Badge{}, ...]

  """
  def list_badges do
    Badge
    |> order_by([b], b.order_index)
    |> Repo.all()
  end

  @doc """
  Returns the list of badges by criteria type.

  ## Examples

      iex> list_badges_by_criteria(:streak)
      [%Badge{criteria_type: :streak}, ...]

  """
  def list_badges_by_criteria(criteria_type) do
    Badge
    |> where([b], b.criteria_type == ^criteria_type)
    |> order_by([b], b.order_index)
    |> Repo.all()
  end

  @doc """
  Gets a single badge.

  Raises `Ecto.NoResultsError` if the Badge does not exist.

  ## Examples

      iex> get_badge!(123)
      %Badge{}

      iex> get_badge!(456)
      ** (Ecto.NoResultsError)

  """
  def get_badge!(id), do: Repo.get!(Badge, id)

  @doc """
  Gets a single badge by name.

  Returns nil if the Badge does not exist.

  ## Examples

      iex> get_badge_by_name("First Steps")
      %Badge{}

      iex> get_badge_by_name("Nonexistent")
      nil

  """
  def get_badge_by_name(name) do
    Badge
    |> where([b], b.name == ^name)
    |> Repo.one()
  end

  @doc """
  Creates a badge.

  ## Examples

      iex> create_badge(%{name: "First Steps", ...})
      {:ok, %Badge{}}

      iex> create_badge(%{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_badge(attrs \\ %{}) do
    %Badge{}
    |> Badge.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a badge and raises on error.

  ## Examples

      iex> create_badge!(%{name: "First Steps", ...})
      %Badge{}

  """
  def create_badge!(attrs \\ %{}) do
    %Badge{}
    |> Badge.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Updates a badge.

  ## Examples

      iex> update_badge(badge, %{description: "new description"})
      {:ok, %Badge{}}

      iex> update_badge(badge, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_badge(%Badge{} = badge, attrs) do
    badge
    |> Badge.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a badge.

  ## Examples

      iex> delete_badge(badge)
      {:ok, %Badge{}}

      iex> delete_badge(badge)
      {:error, %Ecto.Changeset{}}

  """
  def delete_badge(%Badge{} = badge) do
    Repo.delete(badge)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking badge changes.

  ## Examples

      iex> change_badge(badge)
      %Ecto.Changeset{data: %Badge{}}

  """
  def change_badge(%Badge{} = badge, attrs \\ %{}) do
    Badge.changeset(badge, attrs)
  end

  # ============================================================================
  # User Badge Management
  # ============================================================================

  @doc """
  Returns the list of badges earned by a user.

  ## Examples

      iex> list_user_badges(user_id)
      [%UserBadge{badge: %Badge{}}, ...]

  """
  def list_user_badges(user_id) do
    UserBadge
    |> where([ub], ub.user_id == ^user_id)
    |> preload(:badge)
    |> order_by([ub], desc: ub.awarded_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of badge IDs earned by a user.

  ## Examples

      iex> list_user_badge_ids(user_id)
      [1, 2, 3]

  """
  def list_user_badge_ids(user_id) do
    UserBadge
    |> where([ub], ub.user_id == ^user_id)
    |> select([ub], ub.badge_id)
    |> Repo.all()
  end

  @doc """
  Checks if a user has earned a specific badge.

  ## Examples

      iex> user_has_badge?(user_id, badge_id)
      true

  """
  def user_has_badge?(user_id, badge_id) do
    UserBadge
    |> where([ub], ub.user_id == ^user_id and ub.badge_id == ^badge_id)
    |> Repo.exists?()
  end

  @doc """
  Awards a badge to a user.

  ## Examples

      iex> award_badge(user_id, badge_id)
      {:ok, %UserBadge{}}

      iex> award_badge(user_id, badge_id)  # already has badge
      {:ok, %UserBadge{}}  # returns existing

  """
  def award_badge(user_id, badge_id) do
    case user_has_badge?(user_id, badge_id) do
      true ->
        # Return existing user_badge
        {:ok, get_user_badge(user_id, badge_id)}

      false ->
        badge = get_badge!(badge_id)

        result =
          %UserBadge{}
          |> UserBadge.changeset(%{
            user_id: user_id,
            badge_id: badge_id,
            awarded_at: DateTime.utc_now()
          })
          |> Repo.insert()

        # Create notification for new badge
        with {:ok, user_badge} <- result do
          Notifications.notify_badge_earned(user_id, badge)
          {:ok, user_badge}
        end
    end
  end

  @doc """
  Gets a specific user badge record.

  ## Examples

      iex> get_user_badge(user_id, badge_id)
      %UserBadge{}

  """
  def get_user_badge(user_id, badge_id) do
    UserBadge
    |> where([ub], ub.user_id == ^user_id and ub.badge_id == ^badge_id)
    |> preload(:badge)
    |> Repo.one()
  end

  @doc """
  Sets a badge as featured for a user.

  Only one badge can be featured at a time. This will un-feature any
  previously featured badge.

  ## Examples

      iex> set_featured_badge(user_id, badge_id)
      {:ok, %UserBadge{}}

  """
  def set_featured_badge(user_id, badge_id) do
    Repo.transaction(fn ->
      # Un-feature any currently featured badge
      UserBadge
      |> where([ub], ub.user_id == ^user_id and ub.is_featured == true)
      |> Repo.update_all(set: [is_featured: false])

      # Feature the new badge
      user_badge = get_user_badge(user_id, badge_id)

      if user_badge do
        user_badge
        |> UserBadge.changeset(%{is_featured: true})
        |> Repo.update!()
      else
        Repo.rollback(:badge_not_found)
      end
    end)
  end

  @doc """
  Gets the featured badge for a user.

  ## Examples

      iex> get_featured_badge(user_id)
      %UserBadge{badge: %Badge{}}

      iex> get_featured_badge(user_id)  # no featured badge
      nil

  """
  def get_featured_badge(user_id) do
    UserBadge
    |> where([ub], ub.user_id == ^user_id and ub.is_featured == true)
    |> preload(:badge)
    |> Repo.one()
  end

  @doc """
  Removes the featured badge for a user.

  ## Examples

      iex> remove_featured_badge(user_id)
      {:ok, _}

  """
  def remove_featured_badge(user_id) do
    UserBadge
    |> where([ub], ub.user_id == ^user_id and ub.is_featured == true)
    |> Repo.update_all(set: [is_featured: false])

    {:ok, nil}
  end

  # ============================================================================
  # Auto-Award Logic
  # ============================================================================

  @doc """
  Checks and awards badges based on streak count.

  ## Examples

      iex> check_streak_badges(user_id, 7)
      [%UserBadge{}, ...]

  """
  def check_streak_badges(user_id, streak_count) do
    Badge
    |> where([b], b.criteria_type == :streak)
    |> where([b], b.criteria_value <= ^streak_count)
    |> Repo.all()
    |> Enum.filter(fn badge -> not user_has_badge?(user_id, badge.id) end)
    |> Enum.map(fn badge ->
      case award_badge(user_id, badge.id) do
        {:ok, user_badge} -> user_badge
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Checks and awards badges based on kanji count.

  ## Examples

      iex> check_kanji_badges(user_id, 50)
      [%UserBadge{}, ...]

  """
  def check_kanji_badges(user_id, kanji_count) do
    Badge
    |> where([b], b.criteria_type == :kanji_count)
    |> where([b], b.criteria_value <= ^kanji_count)
    |> Repo.all()
    |> Enum.filter(fn badge -> not user_has_badge?(user_id, badge.id) end)
    |> Enum.map(fn badge ->
      case award_badge(user_id, badge.id) do
        {:ok, user_badge} -> user_badge
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Checks and awards badges based on word count.

  ## Examples

      iex> check_words_badges(user_id, 25)
      [%UserBadge{}, ...]

  """
  def check_words_badges(user_id, word_count) do
    Badge
    |> where([b], b.criteria_type == :words_count)
    |> where([b], b.criteria_value <= ^word_count)
    |> Repo.all()
    |> Enum.filter(fn badge -> not user_has_badge?(user_id, badge.id) end)
    |> Enum.map(fn badge ->
      case award_badge(user_id, badge.id) do
        {:ok, user_badge} -> user_badge
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Checks and awards badges based on completed lessons count.

  ## Examples

      iex> check_lesson_badges(user_id, 5)
      [%UserBadge{}, ...]

  """
  def check_lesson_badges(user_id, lessons_count) do
    Badge
    |> where([b], b.criteria_type == :lessons_completed)
    |> where([b], b.criteria_value <= ^lessons_count)
    |> Repo.all()
    |> Enum.filter(fn badge -> not user_has_badge?(user_id, badge.id) end)
    |> Enum.map(fn badge ->
      case award_badge(user_id, badge.id) do
        {:ok, user_badge} -> user_badge
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Checks and awards badges based on daily reviews count.

  ## Examples

      iex> check_daily_reviews_badges(user_id, 10)
      [%UserBadge{}, ...]

  """
  def check_daily_reviews_badges(user_id, reviews_count) do
    Badge
    |> where([b], b.criteria_type == :daily_reviews)
    |> where([b], b.criteria_value <= ^reviews_count)
    |> Repo.all()
    |> Enum.filter(fn badge -> not user_has_badge?(user_id, badge.id) end)
    |> Enum.map(fn badge ->
      case award_badge(user_id, badge.id) do
        {:ok, user_badge} -> user_badge
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
