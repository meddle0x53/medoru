defmodule Medoru.Repo.Migrations.FixDuplicateLessonOrderIndices do
  use Ecto.Migration

  def up do
    execute """
    WITH ranked_lessons AS (
      SELECT
        id,
        ROW_NUMBER() OVER (
          PARTITION BY classroom_id
          ORDER BY order_index ASC, published_at ASC
        ) as new_order_index
      FROM classroom_custom_lessons
    )
    UPDATE classroom_custom_lessons
    SET order_index = ranked_lessons.new_order_index
    FROM ranked_lessons
    WHERE classroom_custom_lessons.id = ranked_lessons.id;
    """
  end

  def down do
    # No reliable way to reverse this data fix
    :ok
  end
end
