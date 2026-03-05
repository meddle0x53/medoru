defmodule Medoru.AccountsTest do
  use Medoru.DataCase

  alias Medoru.Accounts
  alias Medoru.Accounts.{User, UserProfile, UserStats}

  describe "users" do
    import Medoru.AccountsFixtures

    @invalid_attrs %{email: nil, provider: nil, provider_uid: nil}

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "get_user/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user(user.id) == user
    end

    test "get_user/1 returns nil for non-existent id" do
      assert Accounts.get_user(Ecto.UUID.generate()) == nil
    end

    test "get_user_by_email/1 returns the user with given email" do
      user = user_fixture()
      assert Accounts.get_user_by_email(user.email) == user
    end

    test "get_user_by_provider_uid/2 returns the user with given provider and uid" do
      user = user_fixture()
      assert Accounts.get_user_by_provider_uid(user.provider, user.provider_uid) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{
        email: "test@example.com",
        provider: "google",
        provider_uid: "123456789",
        name: "Test User"
      }

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.email == "test@example.com"
      assert user.provider == "google"
      assert user.provider_uid == "123456789"
      assert user.name == "Test User"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "create_user/1 with invalid email returns error changeset" do
      attrs = %{
        email: "not-an-email",
        provider: "google",
        provider_uid: "123"
      }

      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(attrs)
    end

    test "create_user/1 with invalid provider returns error changeset" do
      attrs = %{
        email: "test@example.com",
        provider: "invalid",
        provider_uid: "123"
      }

      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      update_attrs = %{name: "Updated Name"}

      assert {:ok, %User{} = user} = Accounts.update_user(user, update_attrs)
      assert user.name == "Updated Name"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  describe "register_user_with_oauth/1" do
    import Medoru.AccountsFixtures

    test "creates user with profile and stats" do
      attrs = %{
        email: "oauth@example.com",
        provider: "google",
        provider_uid: "oauth123",
        name: "OAuth User",
        avatar_url: "https://example.com/avatar.jpg"
      }

      assert {:ok, %User{} = user} = Accounts.register_user_with_oauth(attrs)
      assert user.email == "oauth@example.com"
      assert user.provider == "google"
      assert user.provider_uid == "oauth123"

      # Profile should be created
      profile = Accounts.get_profile_by_user!(user.id)
      assert profile.user_id == user.id
      assert profile.timezone == "UTC"
      assert profile.daily_goal == 10
      assert profile.theme == "light"

      # Stats should be created
      stats = Accounts.get_stats_by_user!(user.id)
      assert stats.user_id == user.id
      assert stats.xp == 0
      assert stats.level == 1
      assert stats.current_streak == 0
    end

    test "returns error changeset if email is taken" do
      existing_user = user_fixture()

      attrs = %{
        email: existing_user.email,
        provider: "google",
        provider_uid: "unique123",
        name: "Another User"
      }

      assert {:error, %Ecto.Changeset{}} = Accounts.register_user_with_oauth(attrs)
    end

    test "returns error changeset if provider_uid is taken" do
      existing_user = user_fixture()

      attrs = %{
        email: "different@example.com",
        provider: existing_user.provider,
        provider_uid: existing_user.provider_uid,
        name: "Another User"
      }

      assert {:error, %Ecto.Changeset{}} = Accounts.register_user_with_oauth(attrs)
    end
  end

  describe "user_profiles" do
    import Medoru.AccountsFixtures

    test "get_profile_by_user!/1 returns profile for user" do
      user = user_fixture_with_profile()
      profile = Accounts.get_profile_by_user!(user.id)
      assert profile.user_id == user.id
    end

    test "update_profile/2 with valid data updates the profile" do
      user = user_fixture_with_profile()
      profile = Accounts.get_profile_by_user!(user.id)

      update_attrs = %{
        display_name: "New Display Name",
        theme: "dark",
        daily_goal: 20
      }

      assert {:ok, %UserProfile{} = profile} = Accounts.update_profile(profile, update_attrs)
      assert profile.display_name == "New Display Name"
      assert profile.theme == "dark"
      assert profile.daily_goal == 20
    end

    test "update_profile/2 with invalid theme returns error changeset" do
      user = user_fixture_with_profile()
      profile = Accounts.get_profile_by_user!(user.id)

      assert {:error, %Ecto.Changeset{}} = Accounts.update_profile(profile, %{theme: "invalid"})
    end

    test "update_profile/2 with invalid daily_goal returns error changeset" do
      user = user_fixture_with_profile()
      profile = Accounts.get_profile_by_user!(user.id)

      assert {:error, %Ecto.Changeset{}} = Accounts.update_profile(profile, %{daily_goal: 0})
      assert {:error, %Ecto.Changeset{}} = Accounts.update_profile(profile, %{daily_goal: 101})
    end

    test "update_settings/2 updates user profile settings" do
      user = user_fixture_with_profile()

      settings = %{theme: "dark", daily_goal: 15}
      assert {:ok, %UserProfile{} = profile} = Accounts.update_settings(user, settings)
      assert profile.theme == "dark"
      assert profile.daily_goal == 15
    end
  end

  describe "user_stats" do
    import Medoru.AccountsFixtures

    test "get_stats_by_user!/1 returns stats for user" do
      user = user_fixture_with_stats()
      stats = Accounts.get_stats_by_user!(user.id)
      assert stats.user_id == user.id
      assert stats.xp == 0
      assert stats.level == 1
    end

    test "update_stats/2 updates user stats" do
      user = user_fixture_with_stats()
      stats = Accounts.get_stats_by_user!(user.id)

      update_attrs = %{
        xp: 150,
        total_kanji_learned: 5,
        current_streak: 3
      }

      assert {:ok, %UserStats{} = stats} = Accounts.update_stats(stats, update_attrs)
      assert stats.xp == 150
      assert stats.total_kanji_learned == 5
      assert stats.current_streak == 3
    end

    test "add_xp/2 adds XP to user" do
      user = user_fixture_with_stats()
      stats = Accounts.get_stats_by_user!(user.id)
      assert stats.xp == 0

      assert {:ok, %UserStats{} = stats} = Accounts.add_xp(user, 50)
      assert stats.xp == 50

      # Level should stay at 1 with 50 XP (needs 100 for level 2)
      assert stats.level == 1
    end

    test "add_xp/2 levels up user when threshold reached" do
      user = user_fixture_with_stats()

      # Add 100 XP to reach level 2
      assert {:ok, %UserStats{} = stats} = Accounts.add_xp(user, 100)
      assert stats.xp == 100
      assert stats.level == 2

      # Add more XP for level 3 (needs 400 total)
      assert {:ok, %UserStats{} = stats} = Accounts.add_xp(user, 300)
      assert stats.xp == 400
      assert stats.level == 3
    end
  end
end
