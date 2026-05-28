defmodule Medoru.Repo.Migrations.AddChatEnterSendsToUserProfiles do
  use Ecto.Migration

  def up do
    result =
      repo().query!("""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_profiles' AND column_name = 'chat_enter_sends'
      """)

    if result.num_rows == 0 do
      alter table(:user_profiles) do
        add :chat_enter_sends, :boolean, default: true, null: false
      end
    end
  end

  def down do
    alter table(:user_profiles) do
      remove :chat_enter_sends
    end
  end
end
