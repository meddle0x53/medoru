defmodule Medoru.NotificationsTest do
  use Medoru.DataCase

  alias Medoru.Notifications
  alias Medoru.Notifications.Notification

  import Medoru.AccountsFixtures

  describe "notifications" do
    @valid_attrs %{
      type: "badge_earned",
      title: "Badge Earned!",
      message: "You earned a badge",
      data: %{badge_id: 1}
    }

    def notification_fixture(user_id, attrs \\ %{}) do
      attrs =
        attrs
        |> Enum.into(@valid_attrs)
        |> Map.put(:user_id, user_id)

      {:ok, notification} = Notifications.create_notification(attrs)
      notification
    end

    test "list_notifications/1 returns all notifications for user" do
      user = user_fixture()
      n1 = notification_fixture(user.id, %{title: "First"})
      n2 = notification_fixture(user.id, %{title: "Second"})

      notifications = Notifications.list_notifications(user.id)
      assert length(notifications) == 2
      # Both notifications should be returned
      ids = Enum.map(notifications, & &1.id) |> Enum.sort()
      assert ids == Enum.sort([n1.id, n2.id])
    end

    test "list_notifications/2 respects limit option" do
      user = user_fixture()

      for i <- 1..5 do
        notification_fixture(user.id, %{title: "Notification #{i}"})
      end

      notifications = Notifications.list_notifications(user.id, limit: 3)
      assert length(notifications) == 3
    end

    test "list_unread_notifications/1 returns only unread notifications" do
      user = user_fixture()
      unread = notification_fixture(user.id, %{title: "Unread"})
      read = notification_fixture(user.id, %{title: "Read"})

      # Mark one as read
      Notifications.mark_as_read(read)

      unread_notifications = Notifications.list_unread_notifications(user.id)
      assert length(unread_notifications) == 1
      assert hd(unread_notifications).id == unread.id
    end

    test "count_unread_notifications/1 returns count of unread notifications" do
      user = user_fixture()
      notification_fixture(user.id)
      notification_fixture(user.id)

      assert Notifications.count_unread_notifications(user.id) == 2

      # Mark one as read
      [first | _] = Notifications.list_notifications(user.id)
      Notifications.mark_as_read(first)

      assert Notifications.count_unread_notifications(user.id) == 1
    end

    test "get_notification!/1 returns the notification" do
      user = user_fixture()
      notification = notification_fixture(user.id)

      assert Notifications.get_notification!(notification.id).id == notification.id
    end

    test "get_user_notification/2 returns notification if it belongs to user" do
      user = user_fixture()
      notification = notification_fixture(user.id)

      assert Notifications.get_user_notification(user.id, notification.id).id == notification.id
    end

    test "get_user_notification/2 returns nil if notification belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      notification = notification_fixture(user1.id)

      assert Notifications.get_user_notification(user2.id, notification.id) == nil
    end

    test "create_notification/1 with valid data creates a notification" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :user_id, user.id)

      assert {:ok, %Notification{} = notification} = Notifications.create_notification(attrs)
      assert notification.type == "badge_earned"
      assert notification.title == "Badge Earned!"
      assert notification.read_at == nil
      # JSONB stores keys as strings when loaded from DB
      badge_id = notification.data["badge_id"] || notification.data[:badge_id]
      assert badge_id == 1 or notification.data[:badge_id] == 1
    end

    test "create_notification/1 with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} = Notifications.create_notification(%{type: nil})
    end

    test "mark_as_read/1 marks notification as read" do
      user = user_fixture()
      notification = notification_fixture(user.id)
      assert notification.read_at == nil

      assert {:ok, updated} = Notifications.mark_as_read(notification)
      assert updated.read_at != nil
    end

    test "mark_all_as_read/1 marks all user notifications as read" do
      user = user_fixture()
      notification_fixture(user.id)
      notification_fixture(user.id)

      assert Notifications.count_unread_notifications(user.id) == 2

      assert {:ok, _} = Notifications.mark_all_as_read(user.id)

      assert Notifications.count_unread_notifications(user.id) == 0
    end

    test "delete_notification/1 deletes the notification" do
      user = user_fixture()
      notification = notification_fixture(user.id)

      assert {:ok, _} = Notifications.delete_notification(notification)
      assert_raise Ecto.NoResultsError, fn -> Notifications.get_notification!(notification.id) end
    end
  end

  describe "notification creators" do
    setup do
      user = user_fixture()
      {:ok, user: user}
    end

    test "notify_badge_earned/2 creates badge notification", %{user: user} do
      badge = %{id: 1, name: "Test Badge", icon: "star", color: "blue"}

      assert {:ok, notification} = Notifications.notify_badge_earned(user.id, badge)
      assert notification.type == "badge_earned"
      assert notification.title == "🎉 Badge Earned!"
      assert notification.message =~ "Test Badge"
      # Check data was stored (JSONB may use atom or string keys)
      assert notification.data[:badge_id] == 1 or notification.data["badge_id"] == 1
    end

    test "notify_streak_milestone/2 creates streak notification", %{user: user} do
      assert {:ok, notification} = Notifications.notify_streak_milestone(user.id, 7)
      assert notification.type == "streak_milestone"
      assert notification.title == "🔥 Streak Milestone!"
      assert notification.message =~ "7-day"
      # Check data was stored (JSONB may use atom or string keys)
      assert notification.data[:streak_count] == 7 or notification.data["streak_count"] == 7
    end

    test "notify_lesson_complete/2 creates lesson notification", %{user: user} do
      assert {:ok, notification} = Notifications.notify_lesson_complete(user.id, "Lesson 1")
      assert notification.type == "lesson_complete"
      assert notification.title == "📚 Lesson Complete!"
      assert notification.message =~ "Lesson 1"
    end

    test "notify_daily_reminder/2 creates reminder notification with due items", %{user: user} do
      assert {:ok, notification} = Notifications.notify_daily_reminder(user.id, 5)
      assert notification.type == "daily_reminder"
      assert notification.title == "📅 Daily Japanese Practice"
      assert notification.message =~ "5 items"
    end

    test "notify_daily_reminder/2 creates reminder notification without due items", %{user: user} do
      assert {:ok, notification} = Notifications.notify_daily_reminder(user.id, 0)
      assert notification.type == "daily_reminder"
      assert notification.message =~ "Start a new lesson"
    end
  end
end
