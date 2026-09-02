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
    test "list_users/2 returns users with display names or OAuth names" do
      user_with_profile_fixture()
      user_with_profile_fixture()
      user_fixture(%{name: "Named User"})
      user_fixture(%{name: nil})

      users = Social.list_users()
      assert length(users) == 3
    end

    test "list_users/2 includes users the viewer has blocked" do
      viewer = user_with_profile_fixture()
      blocked = user_with_profile_fixture()
      visible = user_with_profile_fixture()

      Social.block_user(viewer.id, blocked.id)

      users = Social.list_users(viewer.id)
      user_ids = Enum.map(users, & &1.id)

      # Viewer can still see blocked users to manage/unblock them
      assert blocked.id in user_ids
      assert visible.id in user_ids
    end

    test "list_users/2 excludes users who blocked the viewer" do
      viewer = user_with_profile_fixture()
      blocker = user_with_profile_fixture()
      visible = user_with_profile_fixture()

      Social.block_user(blocker.id, viewer.id)

      users = Social.list_users(viewer.id)
      user_ids = Enum.map(users, & &1.id)

      assert blocker.id not in user_ids
      assert visible.id in user_ids
    end

    test "block_user/3 auto-unfollows in both directions" do
      user_a = user_with_profile_fixture()
      user_b = user_with_profile_fixture()

      Social.follow_user(user_a.id, user_b.id)
      Social.follow_user(user_b.id, user_a.id)

      assert Social.following?(user_a.id, user_b.id)
      assert Social.following?(user_b.id, user_a.id)

      Social.block_user(user_a.id, user_b.id)

      refute Social.following?(user_a.id, user_b.id)
      refute Social.following?(user_b.id, user_a.id)
    end

    test "list_users/2 excludes users with private profiles" do
      viewer = user_with_profile_fixture()
      public_user = user_with_profile_fixture(%{display_name: "PublicUser"})
      private_user = user_with_profile_fixture(%{display_name: "PrivateUser"})

      Accounts.update_profile(private_user.profile, %{is_public: false})

      users = Social.list_users(viewer.id)
      user_ids = Enum.map(users, & &1.id)

      assert public_user.id in user_ids
      assert private_user.id not in user_ids
    end

    test "search_users/3 excludes users with private profiles" do
      viewer = user_with_profile_fixture()
      public_user = user_with_profile_fixture(%{display_name: "PublicSearch"})
      private_user = user_with_profile_fixture(%{display_name: "PrivateSearch"})

      Accounts.update_profile(private_user.profile, %{is_public: false})

      results = Social.search_users("Search", viewer.id)
      result_ids = Enum.map(results, & &1.id)

      assert public_user.id in result_ids
      assert private_user.id not in result_ids
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
      user_fixture(%{name: "Named User"})
      user_fixture(%{name: nil})

      assert Social.count_users() == 3
    end

    test "count_search_users/2 returns search result count" do
      user_with_profile_fixture(%{display_name: "AliceOne"})
      user_with_profile_fixture(%{display_name: "AliceTwo"})
      user_with_profile_fixture(%{display_name: "Bob"})

      assert Social.count_search_users("Alice") == 2
    end

    test "list_users/2 with only_following shows only followed users" do
      viewer = user_with_profile_fixture()
      followed = user_with_profile_fixture(%{display_name: "Followed"})
      not_followed = user_with_profile_fixture(%{display_name: "NotFollowed"})

      Social.follow_user(viewer.id, followed.id)

      users = Social.list_users(viewer.id, only_following: true)
      user_ids = Enum.map(users, & &1.id)

      assert followed.id in user_ids
      assert not_followed.id not in user_ids
    end

    test "list_users/2 with only_following excludes users who blocked the viewer" do
      viewer = user_with_profile_fixture()
      followed = user_with_profile_fixture(%{display_name: "Followed"})

      Social.follow_user(viewer.id, followed.id)
      Social.block_user(followed.id, viewer.id)

      users = Social.list_users(viewer.id, only_following: true)
      user_ids = Enum.map(users, & &1.id)

      assert followed.id not in user_ids
    end

    test "search_users/3 with only_following bypasses follow filter" do
      viewer = user_with_profile_fixture()
      not_followed = user_with_profile_fixture(%{display_name: "Searchable"})

      # Don't follow them
      results = Social.search_users("Searchable", viewer.id, only_following: true)
      assert length(results) == 1
      assert hd(results).id == not_followed.id
    end

    test "search_users/3 with only_following still excludes users who blocked the viewer" do
      viewer = user_with_profile_fixture()
      blocked = user_with_profile_fixture(%{display_name: "BlockedUser"})

      Social.block_user(blocked.id, viewer.id)

      results = Social.search_users("BlockedUser", viewer.id, only_following: true)
      assert results == []
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

  describe "mutual follows" do
    test "list_mutual_follows/1 returns only users who follow each other" do
      user = user_fixture()
      mutual = user_fixture()
      only_follows = user_fixture()
      only_follower = user_fixture()

      Social.follow_user(user.id, mutual.id)
      Social.follow_user(mutual.id, user.id)

      Social.follow_user(user.id, only_follows.id)
      Social.follow_user(only_follower.id, user.id)

      mutuals = Social.list_mutual_follows(user.id)
      mutual_ids = Enum.map(mutuals, & &1.id)

      assert mutual.id in mutual_ids
      assert only_follows.id not in mutual_ids
      assert only_follower.id not in mutual_ids
    end

    test "mutual_followers?/2 returns true only for mutual follows" do
      user_a = user_fixture()
      user_b = user_fixture()
      user_c = user_fixture()

      Social.follow_user(user_a.id, user_b.id)
      Social.follow_user(user_b.id, user_a.id)
      Social.follow_user(user_a.id, user_c.id)

      assert Social.mutual_followers?(user_a.id, user_b.id)
      refute Social.mutual_followers?(user_a.id, user_c.id)
    end
  end

  describe "profile visits" do
    test "record_profile_visit/2 creates a visit" do
      owner = user_fixture()
      visitor = user_fixture()

      assert :ok = Social.record_profile_visit(visitor.id, owner.id)
      assert Social.count_visitors(owner.id) == 1
    end

    test "record_profile_visit/2 deduplicates repeated visits" do
      owner = user_fixture()
      visitor = user_fixture()

      assert :ok = Social.record_profile_visit(visitor.id, owner.id)
      assert :ok = Social.record_profile_visit(visitor.id, owner.id)

      assert Social.count_visitors(owner.id) == 1
    end

    test "record_profile_visit/2 updates visited_at on repeated visits" do
      owner = user_fixture()
      visitor = user_fixture()

      old_time = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      %Social.ProfileVisit{}
      |> Social.ProfileVisit.changeset(%{
        visitor_id: visitor.id,
        visited_user_id: owner.id,
        visited_at: old_time
      })
      |> Medoru.Repo.insert!()

      assert :ok = Social.record_profile_visit(visitor.id, owner.id)

      [visit] =
        Social.ProfileVisit
        |> where([pv], pv.visited_user_id == ^owner.id)
        |> Medoru.Repo.all()

      assert DateTime.compare(visit.visited_at, old_time) == :gt
    end

    test "record_profile_visit/2 ignores self visits" do
      owner = user_fixture()

      assert :ok = Social.record_profile_visit(owner.id, owner.id)
      assert Social.count_visitors(owner.id) == 0
    end

    test "record_profile_visit/2 ignores nil visitor" do
      owner = user_fixture()

      assert :ok = Social.record_profile_visit(nil, owner.id)
      assert Social.count_visitors(owner.id) == 0
    end

    test "record_profile_visit/2 ignores visits when visitor blocked owner" do
      owner = user_fixture()
      visitor = user_fixture()

      Social.block_user(visitor.id, owner.id)

      assert :ok = Social.record_profile_visit(visitor.id, owner.id)
      assert Social.count_visitors(owner.id) == 0
    end

    test "record_profile_visit/2 ignores visits when owner blocked visitor" do
      owner = user_fixture()
      visitor = user_fixture()

      Social.block_user(owner.id, visitor.id)

      assert :ok = Social.record_profile_visit(visitor.id, owner.id)
      assert Social.count_visitors(owner.id) == 0
    end

    test "list_visitors/2 orders by most recent visit first" do
      owner = user_fixture()
      visitor_a = user_fixture_with_registration(%{name: "Visitor A"})
      visitor_b = user_fixture_with_registration(%{name: "Visitor B"})

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Insert older visit for A and newer visit for B directly to control timestamps.
      %Social.ProfileVisit{}
      |> Social.ProfileVisit.changeset(%{
        visitor_id: visitor_a.id,
        visited_user_id: owner.id,
        visited_at: DateTime.add(now, -3600, :second)
      })
      |> Medoru.Repo.insert!()

      %Social.ProfileVisit{}
      |> Social.ProfileVisit.changeset(%{
        visitor_id: visitor_b.id,
        visited_user_id: owner.id,
        visited_at: now
      })
      |> Medoru.Repo.insert!()

      visitors = Social.list_visitors(owner.id)
      assert length(visitors) == 2
      assert hd(visitors).user.id == visitor_b.id
      assert List.last(visitors).user.id == visitor_a.id
    end

    test "list_visitors/2 supports pagination" do
      owner = user_fixture()

      for _ <- 1..5 do
        visitor = user_fixture_with_registration()
        Social.record_profile_visit(visitor.id, owner.id)
        visitor
      end

      page1 = Social.list_visitors(owner.id, page: 1, per_page: 2)
      page2 = Social.list_visitors(owner.id, page: 2, per_page: 2)

      assert length(page1) == 2
      assert length(page2) == 2
      assert Enum.map(page1, & &1.user.id) != Enum.map(page2, & &1.user.id)
    end

    test "count_visitors/1 counts unique visitors" do
      owner = user_fixture()
      visitor_a = user_fixture()
      visitor_b = user_fixture()

      Social.record_profile_visit(visitor_a.id, owner.id)
      Social.record_profile_visit(visitor_a.id, owner.id)
      Social.record_profile_visit(visitor_b.id, owner.id)

      assert Social.count_visitors(owner.id) == 2
    end
  end

  describe "display_name_for_viewer/2" do
    test "returns the first nickname when the viewer has nicknamed the user" do
      viewer = user_with_profile_fixture()
      target = user_with_profile_fixture(%{display_name: "Real Name"})

      Social.upsert_relation(viewer.id, target.id, %{"nicknames" => ["Zazu", "Zaz"]})

      assert Social.display_name_for_viewer(target, viewer.id) == "Zazu"
      # other viewers still see the real name
      other = user_with_profile_fixture()
      assert Social.display_name_for_viewer(target, other.id) == "Real Name"
    end

    test "falls back to profile name, OAuth name, then Anonymous" do
      viewer = user_with_profile_fixture()
      named = user_with_profile_fixture(%{display_name: "Profile Name"})
      oauth_named = user_fixture(%{name: "OAuth Name"})
      unnamed = user_fixture(%{name: nil})

      assert Social.display_name_for_viewer(named, viewer.id) == "Profile Name"
      assert Social.display_name_for_viewer(oauth_named, viewer.id) == "OAuth Name"
      assert Social.display_name_for_viewer(unnamed, viewer.id) == "Anonymous"
    end

    test "reflects nickname edits and deletes (nickname map invalidation)" do
      viewer = user_with_profile_fixture()
      target = user_with_profile_fixture(%{display_name: "Real Name"})

      Social.upsert_relation(viewer.id, target.id, %{"nicknames" => ["First"]})
      assert Social.display_name_for_viewer(target, viewer.id) == "First"

      # adding a second nickname does not change the first
      Social.upsert_relation(viewer.id, target.id, %{"nicknames" => ["First", "Second"]})
      assert Social.display_name_for_viewer(target, viewer.id) == "First"

      # removing all nicknames falls back to the real name
      Social.upsert_relation(viewer.id, target.id, %{"nicknames" => []})
      assert Social.display_name_for_viewer(target, viewer.id) == "Real Name"

      # a fresh nickname shows again
      Social.upsert_relation(viewer.id, target.id, %{"nicknames" => ["Third"]})
      assert Social.display_name_for_viewer(target, viewer.id) == "Third"

      # deleting the relation falls back too
      Social.delete_relation(viewer.id, target.id)
      assert Social.display_name_for_viewer(target, viewer.id) == "Real Name"
    end
  end
end
