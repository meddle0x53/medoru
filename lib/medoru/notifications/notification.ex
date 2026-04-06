defmodule Medoru.Notifications.Notification do
  @moduledoc """
  Schema for user notifications.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field :type, :string
    field :title, :string
    field :message, :string
    field :read_at, :utc_datetime
    field :data, :map, default: %{}

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :type, :title, :message, :read_at, :data])
    |> validate_required([:user_id, :type, :title, :message])
    |> validate_inclusion(
      :type,
      ~w(badge_earned streak_milestone lesson_complete daily_reminder classroom classroom_lesson classroom_test)
    )
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Marks a notification as read.
  """
  def mark_as_read_changeset(notification) do
    change(notification, %{read_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end
end
