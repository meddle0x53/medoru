defmodule Medoru.SocialTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures

  alias Medoru.Social
  alias Medoru.Social.UserBlock
  alias Medoru.Accounts

  defp user_with_profile_fixture(attrs \\ %{}) do
    user = user_fixture_with_registration(attrs)
    display_name = attrs[:display_name] || "Display#{System.unique_integer([:positive])}"
    {:ok, profile} = Accounts.update_profile(user.profile, %{display_name: display_name})
    %{user | profile: profile}
  end

  describe "user directory" do
    test "list_users/2 returns users with display names" do
      user_with_profile_fixture()
      user_with_profile_fixture()
      user_fixture(%{name: "No Profile"})

      users = Social.list_users()
      assert length(users) == 2
    end

    test "list_users/2 excludes blocked users" do
      viewer = user_with_profile_fixture()
      blocked = user_with_profile_fixture()
      visible = user_with_profile_fixture()

      Social.block_user(viewer.id, blocked.id)

      users = Social.list_users(viewer.id)
      user_ids = Enum.map(users, & &1.id)

      assert blocked.id not in user_ids
      assert visible.id in user_ids
    end

    test "list_users/2 supports pagination" do
      for _ <- 1..5 do
        user_with_profile_fixture()
      end

      users_page1 = Social.list_users(nil, page: 1, per_page: 2)
      assert length(users_page1) == 2

      users_page2 = Social.list_users(nil, page: 2, per_page: 2)
      assert length(users_page2) == 2
    end

    test "search_users/3 filters by display name" do
      user_with_profile_fixture(%{display_name: "AliceWonder"})
      user_with_profile_fixture(%{display_name: "BobBuilder"})

      results = Social.search_users("Alice")
      assert length(results) == 1
      assert hd(results).profile.display_name == "AliceWonder"
    end

    test "search_users/3 is case insensitive" do
      user_with_profile_fixture(%{display_name: "AliceWonder"})

      results = Social.search_users("alice")
      assert length(results) == 1
    end

    test "count_users/1 returns total directory count" do
      user_with_profile_fixture()
      user_with_profile_fixture()
      user_fixture()

      assert Social.count_users() == 2
    end

    test "count_search_users/2 returns search result count" do
      user_with_profile_fixture(%{display_name: "AliceOne"})
      user_with_profile_fixture(%{display_name: "AliceTwo"})
      user_with_profile_fixture(%{display_name: "Bob"})

      assert Social.count_search_users("Alice") == 2
    end
  end

  describe "blocking" do
    test "block_user/3 creates a block" do
      blocker = user_fixture()
      blocked = user_fixture()

      assert {:ok, %UserBlock{}} = Social.block_user(blocker.id, blocked.id, "Spam")

      assert Social.blocked_by?(blocker.id, blocked.id) == true
    end

    test "block_user/3 prevents duplicate blocks" do
      blocker = user_fixture()
      blocked = user_fixture()

      {:ok, _} = Social.block_user(blocker.id, blocked.id)
      assert {:error, %Ecto.Changeset{}} = Social.block_user(blocker.id, blocked.id)
    end

    test "unblock_user/2 removes a block" do
      blocker = user_fixture()
      blocked = user_fixture()

      Social.block_user(blocker.id, blocked.id)
      assert Social.blocked_by?(blocker.id, blocked.id) == true

      :ok = Social.unblock_user(blocker.id, blocked.id)
      assert Social.blocked_by?(blocker.id, blocked.id) == false
    end

    test "list_blocked_users/1 returns blocked users" do
      blocker = user_fixture()
      blocked1 = user_fixture()
      blocked2 = user_fixture()

      Social.block_user(blocker.id, blocked1.id)
      Social.block_user(blocker.id, blocked2.id)

      blocks = Social.list_blocked_users(blocker.id)
      assert length(blocks) == 2
    end

    test "is_blocked?/2 checks both directions" do
      user_a = user_fixture()
      user_b = user_fixture()
      user_c = user_fixture()

      Social.block_user(user_a.id, user_b.id)

      assert Social.is_blocked?(user_a.id, user_b.id) == :blocked
      assert Social.is_blocked?(user_b.id, user_a.id) == :blocked
      assert Social.is_blocked?(user_a.id, user_c.id) == :ok
    end

    test "can_message?/2 returns false for self" do
      user = user_fixture()
      assert Social.can_message?(user.id, user.id) == false
    end

    test "can_message?/2 returns false when blocked" do
      user_a = user_fixture()
      user_b = user_fixture()

      Social.block_user(user_a.id, user_b.id)

      assert Social.can_message?(user_a.id, user_b.id) == false
      assert Social.can_message?(user_b.id, user_a.id) == false
    end

    test "can_message?/2 returns true when not blocked" do
      user_a = user_fixture()
      user_b = user_fixture()

      assert Social.can_message?(user_a.id, user_b.id) == true
    end
  end
end
