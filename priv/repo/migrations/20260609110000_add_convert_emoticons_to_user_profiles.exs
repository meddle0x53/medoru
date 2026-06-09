defmodule Medoru.Repo.Migrations.AddConvertEmoticonsToUserProfiles do
  use Ecto.Migration

  def up do
    result =
      repo().query!("""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_profiles' AND column_name = 'convert_emoticons'
      """)

    if result.num_rows == 0 do
      alter table(:user_profiles) do
        add :convert_emoticons, :boolean, default: true, null: false
      end
    end
  end

  def down do
    alter table(:user_profiles) do
      remove :convert_emoticons
    end
  end
end
