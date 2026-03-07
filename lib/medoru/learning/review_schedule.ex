defmodule Medoru.Learning.ReviewSchedule do
  @moduledoc """
  SRS scheduling for spaced repetition reviews.
  Uses SM-2 algorithm for calculating next review intervals.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "review_schedules" do
    field :next_review_at, :utc_datetime
    field :interval, :integer, default: 1
    field :ease_factor, :float, default: 2.5
    field :repetitions, :integer, default: 0

    belongs_to :user, Medoru.Accounts.User
    belongs_to :user_progress, Medoru.Learning.UserProgress

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(review_schedule, attrs) do
    review_schedule
    |> cast(attrs, [
      :next_review_at,
      :interval,
      :ease_factor,
      :repetitions,
      :user_id,
      :user_progress_id
    ])
    |> validate_required([:interval, :ease_factor, :repetitions])
    |> validate_number(:interval, greater_than_or_equal_to: 0)
    |> validate_number(:ease_factor, greater_than_or_equal_to: 1.3)
    |> validate_number(:repetitions, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:user_progress_id)
    |> unique_constraint([:user_id, :user_progress_id])
  end
end
