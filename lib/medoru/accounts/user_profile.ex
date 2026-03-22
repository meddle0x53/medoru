defmodule Medoru.Accounts.UserProfile do
  @moduledoc """
  User profile schema for display name, avatar, bio, and preferences.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_profiles" do
    field :display_name, :string
    field :avatar, :string
    field :bio, :string
    field :timezone, :string, default: "UTC"
    field :daily_goal, :integer, default: 10
    field :theme, :string, default: "light"
    field :daily_test_step_types, {:array, :string}, default: ["word_to_meaning", "word_to_reading", "reading_text", "image_to_meaning"]

    belongs_to :user, Medoru.Accounts.User
    belongs_to :featured_badge, Medoru.Gamification.Badge

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:display_name, :avatar, :bio, :timezone, :daily_goal, :theme, :daily_test_step_types])
    |> validate_length(:display_name, min: 1, max: 50)
    |> validate_format(:display_name, ~r/^[a-zA-Z0-9_\-\s]+$/,
      message: "can only contain letters, numbers, spaces, underscores, and hyphens"
    )
    |> validate_length(:bio, max: 500)
    |> validate_inclusion(:theme, ["light", "dark", "system"])
    |> validate_number(:daily_goal, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_daily_test_step_types()
    |> unique_constraint(:display_name,
      name: :user_profiles_display_name_index,
      message: "is already taken"
    )
  end

  defp validate_daily_test_step_types(changeset) do
    types = get_field(changeset, :daily_test_step_types) || []
    valid_types = ["word_to_meaning", "word_to_reading", "reading_text", "image_to_meaning", "kanji_writing"]

    if types == [] do
      add_error(changeset, :daily_test_step_types, "must select at least one question type")
    else
      invalid = Enum.reject(types, &(&1 in valid_types))
      if invalid != [] do
        add_error(changeset, :daily_test_step_types, "contains invalid question types")
      else
        changeset
      end
    end
  end
end
