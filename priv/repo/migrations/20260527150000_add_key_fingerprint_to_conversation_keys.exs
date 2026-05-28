defmodule Medoru.Repo.Migrations.AddKeyFingerprintToConversationKeys do
  use Ecto.Migration

  def up do
    # Idempotent: only add column if it doesn't exist
    result =
      repo().query!("""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'conversation_keys' AND column_name = 'key_fingerprint'
      """)

    if result.num_rows == 0 do
      alter table(:conversation_keys) do
        add :key_fingerprint, :string
      end
    end

    # Drop the old unique index that enforces one key per user per conversation.
    # We replace it with a composite unique index that allows multiple keys
    # per user as long as they have different fingerprints.
    # PostgreSQL treats NULLs as distinct, so one NULL-fingerprint row
    # (legacy) plus multiple fingerprinted rows (multi-device) is valid.
    drop_if_exists unique_index(:conversation_keys, [:conversation_id, :user_id],
                     name: :conversation_keys_conversation_id_user_id_index
                   )

    create_if_not_exists unique_index(
                           :conversation_keys,
                           [:conversation_id, :user_id, :key_fingerprint],
                           name: :conversation_keys_conversation_id_user_id_key_fingerprint_index
                         )
  end

  def down do
    drop unique_index(:conversation_keys, [:conversation_id, :user_id, :key_fingerprint],
           name: :conversation_keys_conversation_id_user_id_key_fingerprint_index
         )

    create unique_index(:conversation_keys, [:conversation_id, :user_id],
             name: :conversation_keys_conversation_id_user_id_index
           )

    alter table(:conversation_keys) do
      remove :key_fingerprint
    end
  end
end
