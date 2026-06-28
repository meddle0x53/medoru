defmodule Medoru.Repo.Migrations.FixClassroomTestAttemptsTestIdOnDelete do
  use Ecto.Migration

  @moduledoc """
  Change classroom_test_attempts.test_id foreign key from :nilify_all to :delete_all.

  The column is NOT NULL, so :nilify_all caused a not-null violation whenever a
  test with attempts was deleted. Deleting the attempts alongside the test is the
  desired behavior.
  """

  def up do
    drop constraint(:classroom_test_attempts, "classroom_test_attempts_test_id_fkey")

    alter table(:classroom_test_attempts) do
      modify :test_id, references(:tests, type: :binary_id, on_delete: :delete_all),
        null: false
    end
  end

  def down do
    drop constraint(:classroom_test_attempts, "classroom_test_attempts_test_id_fkey")

    alter table(:classroom_test_attempts) do
      modify :test_id, references(:tests, type: :binary_id, on_delete: :nilify_all),
        null: false
    end
  end
end
