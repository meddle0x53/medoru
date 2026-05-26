defmodule Medoru.Notifications.PushSubscription do
  @moduledoc """
  Schema for storing Web Push API subscriptions per user.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Medoru.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "push_subscriptions" do
    field :endpoint, :string
    field :p256dh, :string
    field :auth, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(push_subscription, attrs) do
    push_subscription
    |> cast(attrs, [:user_id, :endpoint, :p256dh, :auth])
    |> validate_required([:user_id, :endpoint, :p256dh, :auth])
    |> unique_constraint([:user_id, :endpoint])
  end
end
