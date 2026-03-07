defmodule Medoru.GamificationTest do
  use Medoru.DataCase

  alias Medoru.Gamification
  alias Medoru.Gamification.{Badge, UserBadge}

  import Medoru.AccountsFixtures

  describe "badges" do
    @valid_attrs %{
      name: "Test Badge",
      description: "A test badge",
      icon: "star",
      color: "blue",
      criteria_type: :manual,
      criteria_value: 1,
      order_index: 1
    }
    @update_attrs %{
      description: "Updated description",
      color: "green"
    }
    @invalid_attrs %{
      name: nil,
      description: nil,
      icon: nil
    }

    def badge_fixture(attrs \\ %{}) do
      {:ok, badge} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Gamification.create_badge()

      badge
    end

    test "list_badges/0 returns all badges ordered by order_index" do
      _badge1 = badge_fixture(%{name: "Badge 1", order_index: 2})
      badge2 = badge_fixture(%{name: "Badge 2", order_index: 1})

      badges = Gamification.list_badges()
      assert length(badges) == 2
      assert hd(badges).id == badge2.id
    end

    test "list_badges_by_criteria/1 returns badges for specific criteria" do
      badge1 = badge_fixture(%{name: "Streak Badge", criteria_type: :streak})
      _badge2 = badge_fixture(%{name: "Kanji Badge", criteria_type: :kanji_count})

      streak_badges = Gamification.list_badges_by_criteria(:streak)
      assert length(streak_badges) == 1
      assert hd(streak_badges).id == badge1.id
    end

    test "get_badge!/1 returns the badge with given id" do
      badge = badge_fixture()
      assert Gamification.get_badge!(badge.id) == badge
    end

    test "get_badge_by_name/1 returns the badge with given name" do
      badge = badge_fixture()
      assert Gamification.get_badge_by_name(badge.name) == badge
    end

    test "get_badge_by_name/1 returns nil for non-existent badge" do
      assert Gamification.get_badge_by_name("Nonexistent") == nil
    end

    test "create_badge/1 with valid data creates a badge" do
      assert {:ok, %Badge{} = badge} = Gamification.create_badge(@valid_attrs)
      assert badge.name == "Test Badge"
      assert badge.description == "A test badge"
      assert badge.icon == "star"
      assert badge.color == "blue"
      assert badge.criteria_type == :manual
    end

    test "create_badge/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Gamification.create_badge(@invalid_attrs)
    end

    test "create_badge/1 with duplicate name returns error" do
      badge_fixture(%{name: "Unique Badge"})

      assert {:error, %Ecto.Changeset{}} =
               Gamification.create_badge(%{
                 name: "Unique Badge",
                 description: "Test",
                 icon: "star"
               })
    end

    test "update_badge/2 with valid data updates the badge" do
      badge = badge_fixture()
      assert {:ok, %Badge{} = badge} = Gamification.update_badge(badge, @update_attrs)
      assert badge.description == "Updated description"
      assert badge.color == "green"
    end

    test "update_badge/2 with invalid data returns error changeset" do
      badge = badge_fixture()
      assert {:error, %Ecto.Changeset{}} = Gamification.update_badge(badge, @invalid_attrs)
      assert badge == Gamification.get_badge!(badge.id)
    end

    test "delete_badge/1 deletes the badge" do
      badge = badge_fixture()
      assert {:ok, %Badge{}} = Gamification.delete_badge(badge)
      assert_raise Ecto.NoResultsError, fn -> Gamification.get_badge!(badge.id) end
    end

    test "change_badge/1 returns a badge changeset" do
      badge = badge_fixture()
      assert %Ecto.Changeset{} = Gamification.change_badge(badge)
    end
  end

  describe "user_badges" do
    setup do
      user = user_fixture()
      badge = Gamification.create_badge!(%{name: "Test Badge", description: "Test", icon: "star"})
      {:ok, user: user, badge: badge}
    end

    test "list_user_badges/1 returns all badges for a user", %{user: user, badge: badge} do
      {:ok, _user_badge} = Gamification.award_badge(user.id, badge.id)

      badges = Gamification.list_user_badges(user.id)
      assert length(badges) == 1
      assert hd(badges).badge_id == badge.id
    end

    test "list_user_badge_ids/1 returns badge ids for a user", %{user: user, badge: badge} do
      {:ok, _} = Gamification.award_badge(user.id, badge.id)

      badge_ids = Gamification.list_user_badge_ids(user.id)
      assert badge_ids == [badge.id]
    end

    test "user_has_badge?/2 returns true if user has badge", %{user: user, badge: badge} do
      assert Gamification.user_has_badge?(user.id, badge.id) == false
      {:ok, _} = Gamification.award_badge(user.id, badge.id)
      assert Gamification.user_has_badge?(user.id, badge.id) == true
    end

    test "award_badge/2 creates a user badge", %{user: user, badge: badge} do
      assert {:ok, %UserBadge{} = user_badge} = Gamification.award_badge(user.id, badge.id)
      assert user_badge.user_id == user.id
      assert user_badge.badge_id == badge.id
      assert user_badge.awarded_at != nil
    end

    test "award_badge/2 returns existing badge if already awarded", %{user: user, badge: badge} do
      {:ok, first} = Gamification.award_badge(user.id, badge.id)
      {:ok, second} = Gamification.award_badge(user.id, badge.id)
      assert first.id == second.id
    end

    test "get_user_badge/2 returns the user badge", %{user: user, badge: badge} do
      {:ok, user_badge} = Gamification.award_badge(user.id, badge.id)
      assert Gamification.get_user_badge(user.id, badge.id).id == user_badge.id
    end

    test "set_featured_badge/2 sets a badge as featured", %{user: user, badge: badge} do
      {:ok, _} = Gamification.award_badge(user.id, badge.id)

      assert {:ok, %UserBadge{} = user_badge} = Gamification.set_featured_badge(user.id, badge.id)
      assert user_badge.is_featured == true
    end

    test "set_featured_badge/2 un-features previous featured badge", %{user: user, badge: badge1} do
      badge2 =
        Gamification.create_badge!(%{name: "Second Badge", description: "Test", icon: "star"})

      {:ok, _} = Gamification.award_badge(user.id, badge1.id)
      {:ok, _} = Gamification.award_badge(user.id, badge2.id)

      {:ok, _} = Gamification.set_featured_badge(user.id, badge1.id)
      {:ok, _} = Gamification.set_featured_badge(user.id, badge2.id)

      # First badge should no longer be featured
      user_badge1 = Gamification.get_user_badge(user.id, badge1.id)
      assert user_badge1.is_featured == false

      # Second badge should be featured
      user_badge2 = Gamification.get_user_badge(user.id, badge2.id)
      assert user_badge2.is_featured == true
    end

    test "get_featured_badge/1 returns the featured badge", %{user: user, badge: badge} do
      {:ok, _} = Gamification.award_badge(user.id, badge.id)
      {:ok, _} = Gamification.set_featured_badge(user.id, badge.id)

      featured = Gamification.get_featured_badge(user.id)
      assert featured.badge_id == badge.id
      assert featured.is_featured == true
    end

    test "remove_featured_badge/1 removes the featured badge", %{user: user, badge: badge} do
      {:ok, _} = Gamification.award_badge(user.id, badge.id)
      {:ok, _} = Gamification.set_featured_badge(user.id, badge.id)

      assert {:ok, _} = Gamification.remove_featured_badge(user.id)
      assert Gamification.get_featured_badge(user.id) == nil
    end
  end

  describe "badge auto-award checks" do
    setup do
      user = user_fixture()

      # Create badges for testing
      {:ok, streak_badge_3} =
        Gamification.create_badge(%{
          name: "Streak 3",
          description: "3 day streak",
          icon: "fire",
          criteria_type: :streak,
          criteria_value: 3,
          order_index: 1
        })

      {:ok, streak_badge_7} =
        Gamification.create_badge(%{
          name: "Streak 7",
          description: "7 day streak",
          icon: "bolt",
          criteria_type: :streak,
          criteria_value: 7,
          order_index: 2
        })

      {:ok, kanji_badge} =
        Gamification.create_badge(%{
          name: "10 Kanji",
          description: "10 kanji",
          icon: "book",
          criteria_type: :kanji_count,
          criteria_value: 10,
          order_index: 3
        })

      {:ok, words_badge} =
        Gamification.create_badge(%{
          name: "25 Words",
          description: "25 words",
          icon: "doc",
          criteria_type: :words_count,
          criteria_value: 25,
          order_index: 4
        })

      {:ok, lesson_badge} =
        Gamification.create_badge(%{
          name: "First Lesson",
          description: "First lesson",
          icon: "cap",
          criteria_type: :lessons_completed,
          criteria_value: 1,
          order_index: 5
        })

      {:ok,
       user: user,
       badges: %{
         streak_3: streak_badge_3,
         streak_7: streak_badge_7,
         kanji: kanji_badge,
         words: words_badge,
         lesson: lesson_badge
       }}
    end

    test "check_streak_badges/2 awards appropriate streak badges", %{user: user, badges: badges} do
      awarded = Gamification.check_streak_badges(user.id, 3)
      assert length(awarded) == 1
      assert hd(awarded).badge_id == badges.streak_3.id
    end

    test "check_streak_badges/2 awards multiple badges if applicable", %{
      user: user,
      badges: badges
    } do
      awarded = Gamification.check_streak_badges(user.id, 7)
      assert length(awarded) == 2
      badge_ids = Enum.map(awarded, & &1.badge_id)
      assert badges.streak_3.id in badge_ids
      assert badges.streak_7.id in badge_ids
    end

    test "check_streak_badges/2 doesn't award already earned badges", %{
      user: user,
      badges: badges
    } do
      # First, earn the 3-day streak badge
      {:ok, _} = Gamification.award_badge(user.id, badges.streak_3.id)

      # Now check with 7 days - should only get the 7-day badge
      awarded = Gamification.check_streak_badges(user.id, 7)
      assert length(awarded) == 1
      assert hd(awarded).badge_id == badges.streak_7.id
    end

    test "check_kanji_badges/2 awards appropriate kanji badges", %{user: user, badges: badges} do
      awarded = Gamification.check_kanji_badges(user.id, 10)
      assert length(awarded) == 1
      assert hd(awarded).badge_id == badges.kanji.id
    end

    test "check_words_badges/2 awards appropriate word badges", %{user: user, badges: badges} do
      awarded = Gamification.check_words_badges(user.id, 25)
      assert length(awarded) == 1
      assert hd(awarded).badge_id == badges.words.id
    end

    test "check_lesson_badges/2 awards appropriate lesson badges", %{user: user, badges: badges} do
      awarded = Gamification.check_lesson_badges(user.id, 1)
      assert length(awarded) == 1
      assert hd(awarded).badge_id == badges.lesson.id
    end
  end
end
