defmodule Medoru.Repo.Migrations.AddSlugToCustomLessons do
  use Ecto.Migration

  alias Medoru.Content.CustomLesson
  alias Medoru.Repo
  alias Medoru.Slug

  import Ecto.Query

  def up do
    alter table(:custom_lessons) do
      add :slug, :string
    end

    flush()

    backfill_custom_lesson_slugs()

    flush()

    alter table(:custom_lessons) do
      modify :slug, :string, null: false
    end

    create unique_index(:custom_lessons, [:slug])
  end

  def down do
    drop unique_index(:custom_lessons, [:slug])

    alter table(:custom_lessons) do
      remove :slug
    end
  end

  defp backfill_custom_lesson_slugs do
    lessons = Repo.all(from(l in CustomLesson, select: [:id, :title]))

    Enum.each(lessons, fn lesson ->
      base = Slug.generate(lesson.title, "lesson")
      existing = fetch_existing_slugs(base)
      slug = Slug.ensure_unique(base, existing)

      Repo.update_all(
        from(l in CustomLesson, where: l.id == ^lesson.id),
        set: [slug: slug]
      )
    end)
  end

  defp fetch_existing_slugs(base) do
    from(l in CustomLesson,
      where: l.slug == ^base or like(l.slug, ^"#{base}-%"),
      select: l.slug
    )
    |> Repo.all()
    |> Slug.matching_existing(base)
  end
end
