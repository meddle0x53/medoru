defmodule Medoru.Repo.Migrations.UpdateUserPublicKeysAlgorithm do
  use Ecto.Migration

  def up do
    # Update existing keys to note they were migrated
    execute "UPDATE user_public_keys SET algorithm = 'ECDH-P-256-LEGACY' WHERE algorithm = 'ECDH-P-256'"
  end

  def down do
    execute "UPDATE user_public_keys SET algorithm = 'ECDH-P-256' WHERE algorithm = 'ECDH-P-256-LEGACY'"
  end
end
