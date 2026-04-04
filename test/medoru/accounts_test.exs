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

  describe "api_tokens" do
    import Medoru.AccountsFixtures
    alias Medoru.Accounts.ApiToken

    test "list_user_api_tokens/1 returns empty list when no tokens" do
      user = user_fixture()
      assert Accounts.list_user_api_tokens(user.id) == []
    end

    test "create_api_token/2 creates a token and returns plaintext" do
      user = user_fixture()

      assert {:ok, %ApiToken{} = token, plaintext} =
               Accounts.create_api_token(user.id, %{"name" => "Test Token"})

      assert token.user_id == user.id
      assert token.name == "Test Token"
      assert is_nil(token.expires_at)
      assert is_binary(plaintext)
      assert byte_size(plaintext) > 20
    end

    test "create_api_token/2 creates a token with expiration" do
      user = user_fixture()

      assert {:ok, %ApiToken{} = token, _plaintext} =
               Accounts.create_api_token(user.id, %{"name" => "Expiring", "expires_in_days" => "30"})

      assert token.name == "Expiring"
      assert token.expires_at != nil
      assert DateTime.diff(token.expires_at, DateTime.utc_now(), :day) >= 29
    end

    test "create_api_token/2 enforces max 3 tokens per user" do
      user = user_fixture()

      for i <- 1..3 do
        assert {:ok, %ApiToken{}, _plaintext} =
                 Accounts.create_api_token(user.id, %{"name" => "Token #{i}"})
      end

      assert {:error, :limit_reached} =
               Accounts.create_api_token(user.id, %{"name" => "Token 4"})
    end

    test "count_user_api_tokens/1 returns correct count" do
      user = user_fixture()
      assert Accounts.count_user_api_tokens(user.id) == 0

      {:ok, _, _} = Accounts.create_api_token(user.id, %{"name" => "One"})
      assert Accounts.count_user_api_tokens(user.id) == 1
    end

    test "delete_api_token/2 removes token for owner" do
      user = user_fixture()
      {:ok, token, _} = Accounts.create_api_token(user.id, %{"name" => "To Delete"})

      assert {:ok, %ApiToken{}} = Accounts.delete_api_token(user.id, token.id)
      assert Accounts.list_user_api_tokens(user.id) == []
    end

    test "delete_api_token/2 returns error for non-owner" do
      user = user_fixture()
      other_user = user_fixture(%{email: "other@example.com", provider_uid: "other123"})
      {:ok, token, _} = Accounts.create_api_token(user.id, %{"name" => "Mine"})

      assert {:error, :not_found} = Accounts.delete_api_token(other_user.id, token.id)
    end

    test "verify_api_token/1 returns token for valid token" do
      user = user_fixture()
      {:ok, _token, plaintext} = Accounts.create_api_token(user.id, %{"name" => "Valid"})

      assert {:ok, %ApiToken{}} = Accounts.verify_api_token(plaintext)
    end

    test "verify_api_token/1 returns error for invalid token" do
      assert {:error, :invalid} = Accounts.verify_api_token("invalid-token")
    end

    test "verify_api_token/1 returns error for expired token" do
      user = user_fixture()

      # Create token that expired yesterday with a valid hash
      expired = DateTime.add(DateTime.utc_now(), -1, :day)
      plaintext = "expired-test-token"
      token_hash = :crypto.hash(:sha256, plaintext) |> Base.encode16(case: :lower)

      {:ok, _token} =
        %ApiToken{}
        |> Ecto.Changeset.change(%{
          user_id: user.id,
          token_hash: token_hash,
          expires_at: expired
        })
        |> Medoru.Repo.insert()

      assert {:error, :expired} = Accounts.verify_api_token(plaintext)
    end

    test "touch_api_token/1 updates last_used_at" do
      user = user_fixture()
      {:ok, token, _} = Accounts.create_api_token(user.id, %{"name" => "To Touch"})
      assert is_nil(token.last_used_at)

      assert {:ok, %ApiToken{} = updated} = Accounts.touch_api_token(token)
      assert updated.last_used_at != nil
      assert DateTime.diff(DateTime.utc_now(), updated.last_used_at, :second) < 5
    end
  end
end
