defmodule Medoru.Repo.Migrations.AddSlugToTests do
  use Ecto.Migration

  alias Medoru.Repo
  alias Medoru.Slug
  alias Medoru.Tests.Test

  import Ecto.Query

  def up do
    alter table(:tests) do
      add :slug, :string
    end

    flush()

    backfill_teacher_test_slugs()

    create unique_index(:tests, [:slug])
  end

  def down do
    drop unique_index(:tests, [:slug])

    alter table(:tests) do
      remove :slug
    end
  end

  defp backfill_teacher_test_slugs do
    tests = Repo.all(from(t in Test, where: t.test_type == :teacher, select: [:id, :title]))

    Enum.each(tests, fn test ->
      base = Slug.generate(test.title, "test")
      existing = fetch_existing_slugs(base)
      slug = Slug.ensure_unique(base, existing)

      Repo.update_all(
        from(t in Test, where: t.id == ^test.id),
        set: [slug: slug]
      )
    end)
  end

  defp fetch_existing_slugs(base) do
    from(t in Test,
      where: t.slug == ^base or like(t.slug, ^"#{base}-%"),
      select: t.slug
    )
    |> Repo.all()
    |> Slug.matching_existing(base)
  end
end
