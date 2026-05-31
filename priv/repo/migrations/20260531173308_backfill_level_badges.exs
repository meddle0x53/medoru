defmodule Medoru.Repo.Migrations.BackfillLevelBadges do
  @moduledoc """
  Backfills level badges for existing users based on their current level.
  Does NOT award XP to avoid inflating existing user stats.
  """

  use Ecto.Migration

  alias Medoru.Repo

  def up do
    # Get all level badges
    {:ok, %{rows: badge_rows}} =
      Repo.query("SELECT id, criteria_value FROM badges WHERE criteria_type = 'level' ORDER BY criteria_value ASC")

    level_badges =
      badge_rows
      |> Enum.map(fn [id, criteria_value] -> {criteria_value, id} end)
      |> Map.new()

    if map_size(level_badges) > 0 do
      # Get all users with their current level
      {:ok, %{rows: user_rows}} =
        Repo.query("""
        SELECT u.id, COALESCE(us.level, 0) as level
        FROM users u
        LEFT JOIN user_stats us ON us.user_id = u.id
        """)

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      now_naive = DateTime.to_naive(now)

      user_badges_to_insert =
        Enum.flat_map(user_rows, fn [user_id, level] ->
          eligible_badge_ids =
            level_badges
            |> Enum.filter(fn {criteria_value, _id} -> criteria_value <= level end)
            |> Enum.map(fn {_criteria_value, id} -> id end)

          Enum.map(eligible_badge_ids, fn badge_id ->
            %{
              id: Ecto.UUID.generate(),
              user_id: user_id,
              badge_id: badge_id,
              awarded_at: now_naive,
              is_featured: false,
              inserted_at: now_naive,
              updated_at: now_naive
            }
          end)
        end)

      if length(user_badges_to_insert) > 0 do
        # Insert with on_conflict nothing to skip duplicates
        Repo.insert_all("user_badges", user_badges_to_insert,
          on_conflict: :nothing,
          conflict_target: [:user_id, :badge_id]
        )
      end
    end
  end

  def down do
    # Remove all level badges from users
    Repo.query!("""
    DELETE FROM user_badges
    WHERE badge_id IN (SELECT id FROM badges WHERE criteria_type = 'level')
    """)
  end
end
