defmodule Medoru.Repo.Migrations.MakeMessageCiphertextNullable do
  use Ecto.Migration

  def up do
    alter table(:messages) do
      modify :ciphertext, :binary, null: true
      modify :iv, :binary, null: true
      modify :encrypted_at, :utc_datetime, null: true
    end
  end

  def down do
    alter table(:messages) do
      modify :ciphertext, :binary, null: false
      modify :iv, :binary, null: false
      modify :encrypted_at, :utc_datetime, null: false
    end
  end
end
