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
  alias Medoru.Accounts
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
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)

    Notification
    |> where([n], n.user_id == ^user_id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
  end

  @doc """
  Counts total notifications for a user.

  ## Examples

      iex> count_notifications(user_id)
      42

  """
  def count_notifications(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns paginated notifications of a specific type for a user.

  ## Examples

      iex> list_notifications_by_type(user_id, "badge_earned", page: 1, per_page: 10)
      [%Notification{}, ...]

  """
  def list_notifications_by_type(user_id, type, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)

    Notification
    |> where([n], n.user_id == ^user_id and n.type == ^type)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
  end

  @doc """
  Counts notifications of a specific type for a user.
  """
  def count_notifications_by_type(user_id, type) do
    Notification
    |> where([n], n.user_id == ^user_id and n.type == ^type)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns unread notifications for a user.

  ## Examples

      iex> list_unread_notifications(user_id)
      [%Notification{}, ...]

  """
  def list_unread_notifications(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)

    Notification
    |> where([n], n.user_id == ^user_id and is_nil(n.read_at))
    |> order_by([n], desc: n.inserted_at)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
  end

  @doc """
  Counts unread notifications for a user.
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
    user_id = attrs[:user_id]
    type = attrs[:type]

    if user_id && type && notification_disabled?(user_id, type) do
      {:ok, nil}
    else
      %Notification{}
      |> Notification.changeset(attrs)
      |> Repo.insert()
    end
  end

  defp notification_disabled?(user_id, type) do
    profile = Accounts.get_user_profile(user_id)

    if profile do
      case type do
        t when t in ["chat_message", "chat_invite"] ->
          not profile.notify_messaging

        t when t in ["white_board_post", "white_board_comment"] ->
          not profile.notify_white_board

        t when t in ["badge_earned", "level_up", "streak_milestone", "lesson_complete"] ->
          not profile.notify_achievements

        _ ->
          false
      end
    else
      false
    end
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
  Marks all unread chat message notifications for a specific conversation as read.

  ## Examples

      iex> mark_chat_notifications_as_read(user_id, conversation_id)
      {:ok, count}

  """
  def mark_chat_notifications_as_read(user_id, conversation_id) do
    {count, _} =
      Notification
      |> where([n], n.user_id == ^user_id and is_nil(n.read_at) and n.type == "chat_message")
      |> where([n], fragment("?->>'conversation_id' = ?", n.data, ^conversation_id))
      |> Repo.update_all(set: [read_at: DateTime.utc_now()])

    {:ok, count}
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

  @doc """
  Deletes a notification scoped to a specific user.

  Returns `{:ok, %Notification{}}` on success, `{:error, :not_found}` if the
  notification does not exist or does not belong to the user.

  ## Examples

      iex> delete_user_notification(user_id, notification_id)
      {:ok, %Notification{}}

      iex> delete_user_notification(wrong_user_id, notification_id)
      {:error, :not_found}

  """
  def delete_user_notification(user_id, notification_id) do
    case get_user_notification(user_id, notification_id) do
      nil -> {:error, :not_found}
      notification -> Repo.delete(notification)
    end
  end

  @doc """
  Deletes all notifications for a user.

  ## Examples

      iex> delete_all_notifications(user_id)
      {:ok, count}

  """
  def delete_all_notifications(user_id) do
    {count, _} =
      Notification
      |> where([n], n.user_id == ^user_id)
      |> Repo.delete_all()

    {:ok, count}
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
  Creates a level up notification.

  ## Examples

      iex> notify_level_up(user_id, 5)
      {:ok, %Notification{}}

  """
  def notify_level_up(user_id, new_level) do
    create_notification(%{
      user_id: user_id,
      type: "level_up",
      title: "🆙 Level Up!",
      message: "Congratulations! You've reached level #{new_level}!",
      data: %{
        level: new_level
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

  @doc """
  Notifies students that a new lesson was published to their classroom.

  ## Examples

      iex> notify_classroom_lesson_published(user_id, "N5 Kanji", "Introduction", lesson_id, classroom_id)
      {:ok, %Notification{}}

  """
  def notify_classroom_lesson_published(
        user_id,
        classroom_name,
        lesson_title,
        lesson_id,
        classroom_id
      ) do
    create_notification(%{
      user_id: user_id,
      type: "classroom_lesson",
      title: "📚 New Lesson in #{classroom_name}",
      message: "\"#{lesson_title}\" has been published to your classroom.",
      data: %{
        classroom_id: classroom_id,
        classroom_name: classroom_name,
        lesson_id: lesson_id,
        lesson_title: lesson_title,
        action: "lesson_published"
      }
    })
    |> maybe_broadcast_notification(user_id)
  end

  @doc """
  Notifies students that a new test was published to their classroom.

  ## Examples

      iex> notify_classroom_test_published(user_id, "N5 Kanji", "Kanji Quiz", test_id, classroom_id)
      {:ok, %Notification{}}

  """
  def notify_classroom_test_published(user_id, classroom_name, test_title, test_id, classroom_id) do
    create_notification(%{
      user_id: user_id,
      type: "classroom_test",
      title: "📝 New Test in #{classroom_name}",
      message: "\"#{test_title}\" has been published to your classroom.",
      data: %{
        classroom_id: classroom_id,
        classroom_name: classroom_name,
        test_id: test_id,
        test_title: test_title,
        action: "test_published"
      }
    })
    |> maybe_broadcast_notification(user_id)
  end

  @doc """
  Creates a notification for a new chat message.
  """
  def notify_chat_message(
        user_id,
        sender_name,
        conversation_id,
        is_group,
        group_title,
        message_body \\ nil,
        classroom_id \\ nil
      ) do
    title =
      if is_group do
        "#{sender_name} in #{group_title || "Group Chat"}"
      else
        sender_name
      end

    data =
      %{
        conversation_id: conversation_id,
        sender_name: sender_name,
        is_group: is_group
      }
      |> then(fn d ->
        if classroom_id, do: Map.put(d, :classroom_id, classroom_id), else: d
      end)

    create_notification(%{
      user_id: user_id,
      type: "chat_message",
      title: title,
      message: message_body || "You have a new message",
      data: data
    })
    |> maybe_broadcast_notification(user_id)
  end

  @doc """
  Creates a notification inviting a user to set up encryption for a chat.
  """
  def notify_chat_invitation(user_id, sender_name, conversation_id) do
    create_notification(%{
      user_id: user_id,
      type: "chat_invite",
      title: "💬 #{sender_name} wants to chat",
      message: "Tap to open the conversation and set up encryption.",
      data: %{
        conversation_id: conversation_id,
        sender_name: sender_name
      }
    })
    |> maybe_broadcast_notification(user_id)
  end

  @doc """
  Notifies followers that a user posted on their white board.
  """
  def notify_white_board_post(user_id, poster_name, poster_id, post_id) do
    create_notification(%{
      user_id: user_id,
      type: "white_board_post",
      title: "📝 New Post from #{poster_name}",
      message: "#{poster_name} posted on their white board.",
      data: %{
        post_id: post_id,
        poster_id: poster_id,
        poster_name: poster_name
      }
    })
    |> maybe_broadcast_notification(user_id)
  end

  @doc """
  Notifies users that a new comment was added to a white board post.
  """
  def notify_white_board_comment(user_id, commenter_name, post_id, post_owner_id, post_owner_name) do
    create_notification(%{
      user_id: user_id,
      type: "white_board_comment",
      title: "💬 New Comment on #{post_owner_name}'s Post",
      message: "#{commenter_name} commented on a post.",
      data: %{
        post_id: post_id,
        post_owner_id: post_owner_id,
        commenter_name: commenter_name,
        post_owner_name: post_owner_name
      }
    })
    |> maybe_broadcast_notification(user_id)
  end

  defp maybe_broadcast_notification({:ok, notification}, user_id) do
    Phoenix.PubSub.broadcast(
      Medoru.PubSub,
      "notifications:#{user_id}",
      {:new_notification, notification}
    )

    {:ok, notification}
  end

  defp maybe_broadcast_notification(error, _user_id), do: error

  # ============================================================================
  # Push Subscriptions
  # ============================================================================

  alias Medoru.Notifications.PushSubscription

  @doc """
  Stores or updates a push subscription for a user.
  """
  def create_or_update_push_subscription(user_id, %{"endpoint" => endpoint, "keys" => keys}) do
    attrs = %{
      user_id: user_id,
      endpoint: endpoint,
      p256dh: keys["p256dh"],
      auth: keys["auth"]
    }

    case Repo.get_by(PushSubscription, user_id: user_id, endpoint: endpoint) do
      nil ->
        %PushSubscription{}
        |> PushSubscription.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> PushSubscription.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Removes a push subscription by endpoint.
  """
  def delete_push_subscription(user_id, endpoint) do
    PushSubscription
    |> where([s], s.user_id == ^user_id and s.endpoint == ^endpoint)
    |> Repo.delete_all()
  end

  @doc """
  Lists all push subscriptions for a user.
  """
  def list_push_subscriptions(user_id) do
    PushSubscription
    |> where([s], s.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Sends a push notification to all subscriptions for a user.
  """
  def send_push_notification(user_id, title, body, data \\ %{}) do
    subscriptions = list_push_subscriptions(user_id)

    payload =
      Jason.encode!(%{
        title: title,
        body: body,
        data: data,
        icon: "/images/pwa-icon-192.png",
        badge: "/images/pwa-icon-192.png"
      })

    Enum.each(subscriptions, fn sub ->
      subscription = %{
        endpoint: sub.endpoint,
        keys: %{
          auth: sub.auth,
          p256dh: sub.p256dh
        }
      }

      Task.start(fn ->
        case MedoruWeb.Push.send_web_push(payload, subscription) do
          {:ok, %{status: 410}} ->
            # Subscription expired or invalid
            delete_push_subscription(user_id, sub.endpoint)

          _ ->
            :ok
        end
      end)
    end)
  end
end
