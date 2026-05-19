defmodule Medoru.Repo.Migrations.ConvertIntroOutroToTextSteps do
  use Ecto.Migration

  def up do
    execute "UPDATE grammar_lesson_steps SET step_type = 'text' WHERE step_type IN ('intro', 'outro')"
  end

  def down do
    # Cannot reliably reverse
    :ok
  end
end
