defmodule Medoru.Notifications do
  @moduledoc """
  The Notifications context.

  This context handles user notifications for various events like:
  - Badge earned
  - Streak milestones
  - Lesson completion
  - Daily reminders
  """

  import Ecto.Query, warn: false
  alias Medoru.Repo
  alias Medoru.Notifications.Notification

  # ============================================================================
  # Queries
  # ============================================================================

  @doc """
  Returns the list of notifications for a user, ordered by newest first.

  ## Examples

      iex> list_notifications(user_id)
      [%Notification{}, ...]

  """
  def list_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Notification
    |> where([n], n.user_id == ^user_id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns unread notifications for a user.

  ## Examples

      iex> list_unread_notifications(user_id)
      [%Notification{}, ...]

  """
  def list_unread_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Notification
    |> where([n], n.user_id == ^user_id and is_nil(n.read_at))
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Counts unread notifications for a user.

  ## Examples

      iex> count_unread_notifications(user_id)
      5

  """
  def count_unread_notifications(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a single notification.

  Raises `Ecto.NoResultsError` if the Notification does not exist.

  ## Examples

      iex> get_notification!(123)
      %Notification{}

  """
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Gets a notification for a specific user (ensures user can only access their own).

  ## Examples

      iex> get_user_notification(user_id, notification_id)
      %Notification{}

      iex> get_user_notification(wrong_user_id, notification_id)
      nil

  """
  def get_user_notification(user_id, notification_id) do
    Notification
    |> where([n], n.id == ^notification_id and n.user_id == ^user_id)
    |> Repo.one()
  end

  # ============================================================================
  # CRUD Operations
  # ============================================================================

  @doc """
  Creates a notification.

  ## Examples

      iex> create_notification(%{user_id: 1, type: "badge_earned", ...})
      {:ok, %Notification{}}

  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Marks a notification as read.

  ## Examples

      iex> mark_as_read(notification)
      {:ok, %Notification{}}

  """
  def mark_as_read(%Notification{} = notification) do
    notification
    |> Notification.mark_as_read_changeset()
    |> Repo.update()
  end

  @doc """
  Marks all notifications as read for a user.

  ## Examples

      iex> mark_all_as_read(user_id)
      {:ok, _}

  """
  def mark_all_as_read(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: DateTime.utc_now()])

    {:ok, nil}
  end

  @doc """
  Deletes a notification.

  ## Examples

      iex> delete_notification(notification)
      {:ok, %Notification{}}

  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  # ============================================================================
  # Notification Creators
  # ============================================================================

  @doc """
  Creates a badge earned notification.

  ## Examples

      iex> notify_badge_earned(user_id, badge)
      {:ok, %Notification{}}

  """
  def notify_badge_earned(user_id, badge) do
    create_notification(%{
      user_id: user_id,
      type: "badge_earned",
      title: "🎉 Badge Earned!",
      message: "Congratulations! You've earned the \"#{badge.name}\" badge.",
      data: %{
        badge_id: badge.id,
        badge_name: badge.name,
        badge_icon: badge.icon,
        badge_color: badge.color
      }
    })
  end

  @doc """
  Creates a streak milestone notification.

  ## Examples

      iex> notify_streak_milestone(user_id, 7)
      {:ok, %Notification{}}

  """
  def notify_streak_milestone(user_id, streak_count) do
    create_notification(%{
      user_id: user_id,
      type: "streak_milestone",
      title: "🔥 Streak Milestone!",
      message: "Amazing! You've maintained a #{streak_count}-day learning streak!",
      data: %{
        streak_count: streak_count
      }
    })
  end

  @doc """
  Creates a lesson completion notification.

  ## Examples

      iex> notify_lesson_complete(user_id, lesson_title)
      {:ok, %Notification{}}

  """
  def notify_lesson_complete(user_id, lesson_title) do
    create_notification(%{
      user_id: user_id,
      type: "lesson_complete",
      title: "📚 Lesson Complete!",
      message: "Great job completing \"#{lesson_title}\"!",
      data: %{
        lesson_title: lesson_title
      }
    })
  end

  @doc """
  Creates a daily reminder notification.

  ## Examples

      iex> notify_daily_reminder(user_id, due_count)
      {:ok, %Notification{}}

  """
  def notify_daily_reminder(user_id, due_count) do
    message =
      if due_count > 0 do
        "You have #{due_count} items ready for review. Keep your streak going!"
      else
        "Time for your daily Japanese practice! Start a new lesson today."
      end

    create_notification(%{
      user_id: user_id,
      type: "daily_reminder",
      title: "📅 Daily Japanese Practice",
      message: message,
      data: %{
        due_count: due_count
      }
    })
  end

  # ============================================================================
  # Classroom Membership Notifications
  # ============================================================================

  @doc """
  Notifies a student that their application was approved.

  ## Examples

      iex> notify_application_approved(user_id, classroom_name, classroom_id)
      {:ok, %Notification{}}

  """
  def notify_application_approved(user_id, classroom_name, classroom_id) do
    create_notification(%{
      user_id: user_id,
      type: "classroom",
      title: "✅ Application Approved",
      message: "You have been approved to join \"#{classroom_name}\"!",
      data: %{
        classroom_id: classroom_id,
        classroom_name: classroom_name,
        action: "approved"
      }
    })
  end

  @doc """
  Notifies a student that their application was rejected.

  ## Examples

      iex> notify_application_rejected(user_id, classroom_name)
      {:ok, %Notification{}}

  """
  def notify_application_rejected(user_id, classroom_name) do
    create_notification(%{
      user_id: user_id,
      type: "classroom",
      title: "❌ Application Declined",
      message: "Your application to join \"#{classroom_name}\" was not accepted.",
      data: %{
        classroom_name: classroom_name,
        action: "rejected"
      }
    })
  end

  @doc """
  Notifies a teacher that a student applied to join their classroom.

  ## Examples

      iex> notify_new_application(teacher_id, student_email, classroom_name, classroom_id)
      {:ok, %Notification{}}

  """
  def notify_new_application(teacher_id, student_email, classroom_name, classroom_id) do
    create_notification(%{
      user_id: teacher_id,
      type: "classroom",
      title: "👋 New Student Application",
      message: "#{student_email} wants to join \"#{classroom_name}\".",
      data: %{
        classroom_id: classroom_id,
        classroom_name: classroom_name,
        student_email: student_email,
        action: "new_application"
      }
    })
  end

  @doc """
  Notifies a student that they were removed from a classroom.

  ## Examples

      iex> notify_removed_from_classroom(user_id, classroom_name)
      {:ok, %Notification{}}

  """
  def notify_removed_from_classroom(user_id, classroom_name) do
    create_notification(%{
      user_id: user_id,
      type: "classroom",
      title: "⚠️ Removed from Classroom",
      message: "You have been removed from \"#{classroom_name}\".",
      data: %{
        classroom_name: classroom_name,
        action: "removed"
      }
    })
  end
end
