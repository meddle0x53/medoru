defmodule Medoru.Repo.Migrations.AddSlugToGames do
  use Ecto.Migration

  alias Medoru.Games.Game
  alias Medoru.Repo
  alias Medoru.Slug

  import Ecto.Query

  def up do
    alter table(:games) do
      add :slug, :string
    end

    flush()

    backfill_game_slugs()

    flush()

    alter table(:games) do
      modify :slug, :string, null: false
    end

    create unique_index(:games, [:classroom_id, :slug])
  end

  def down do
    drop unique_index(:games, [:classroom_id, :slug])

    alter table(:games) do
      remove :slug
    end
  end

  defp backfill_game_slugs do
    games = Repo.all(from(g in Game, select: [:id, :classroom_id, :name]))

    Enum.each(games, fn game ->
      base = Slug.generate(game.name, "game")
      existing = fetch_existing_slugs(game.classroom_id, base)
      slug = Slug.ensure_unique(base, existing)

      Repo.update_all(
        from(g in Game, where: g.id == ^game.id),
        set: [slug: slug]
      )
    end)
  end

  defp fetch_existing_slugs(classroom_id, base) do
    from(g in Game,
      where:
        g.classroom_id == ^classroom_id and
          (g.slug == ^base or like(g.slug, ^"#{base}-%")),
      select: g.slug
    )
    |> Repo.all()
    |> Slug.matching_existing(base)
  end
end
