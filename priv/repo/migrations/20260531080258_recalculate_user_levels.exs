defmodule Medoru.Repo.Migrations.RecalculateUserLevels do
  use Ecto.Migration

  def up do
    # Recalculate all user levels using the new formula:
    # level = trunc((-900 + sqrt(810000 + 400 * xp)) / 200)
    # For xp = 0, this gives 0. For xp < 1000, level = 0.
    execute """
    UPDATE user_stats
    SET level = GREATEST(0, TRUNC((-900 + SQRT(810000.0 + 400.0 * xp)) / 200))
    """
  end

  def down do
    # Restore old formula: level = trunc(sqrt(xp / 100)) + 1
    execute """
    UPDATE user_stats
    SET level = GREATEST(1, TRUNC(SQRT(xp / 100.0)) + 1)
    """
  end
end
