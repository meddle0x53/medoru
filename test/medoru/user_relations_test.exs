defmodule Medoru.UserRelationsTest do
  use Medoru.DataCase, async: true

  import Medoru.AccountsFixtures

  alias Medoru.Social
  alias Medoru.Social.UserRelation

  defp user_with_profile(attrs \\ %{}) do
    user = user_fixture_with_registration(attrs)
    display_name = attrs[:display_name] || "Display#{System.unique_integer([:positive])}"
    {:ok, profile} = Medoru.Accounts.update_profile(user.profile, %{display_name: display_name})
    %{user | profile: profile}
  end

  describe "user relations" do
    test "upsert_relation/3 creates a relation" do
      user = user_with_profile()
      target = user_with_profile(%{display_name: "Target"})

      assert {:ok, %UserRelation{}} =
               Social.upsert_relation(user.id, target.id, %{
                 "relationship_type" => "friend",
                 "address_style" => "informal",
                 "nicknames" => ["Buddy", "Pal"]
               })
    end

    test "upsert_relation/3 updates an existing relation" do
      user = user_with_profile()
      target = user_with_profile(%{display_name: "Target"})

      Social.upsert_relation(user.id, target.id, %{"relationship_type" => "friend"})

      assert {:ok, %UserRelation{relationship_type: "close-friend"}} =
               Social.upsert_relation(user.id, target.id, %{
                 "relationship_type" => "close-friend"
               })
    end

    test "relations are unilateral and private" do
      user_a = user_with_profile()
      user_b = user_with_profile()

      Social.upsert_relation(user_a.id, user_b.id, %{"relationship_type" => "friend"})

      assert Social.get_relation(user_a.id, user_b.id)
      refute Social.get_relation(user_b.id, user_a.id)
    end

    test "delete_relation/2 removes a relation" do
      user = user_with_profile()
      target = user_with_profile()

      Social.upsert_relation(user.id, target.id, %{"relationship_type" => "friend"})
      :ok = Social.delete_relation(user.id, target.id)

      refute Social.get_relation(user.id, target.id)
    end

    test "first_nickname/1 and nickname_at/2 fall back to display name" do
      user = user_with_profile()
      target = user_with_profile(%{display_name: "Target Name"})

      assert Social.first_nickname(nil) == nil
      assert Social.nickname_at(nil, 1) == nil

      Social.upsert_relation(user.id, target.id, %{"relationship_type" => "friend"})
      relation = Social.get_relation(user.id, target.id)

      assert Social.first_nickname(relation) == "Target Name"
      assert Social.nickname_at(relation, 1) == "Target Name"

      Social.upsert_relation(user.id, target.id, %{"nicknames" => ["Nick1", "Nick2"]})
      relation = Social.get_relation(user.id, target.id)

      assert Social.first_nickname(relation) == "Nick1"
      assert Social.nickname_at(relation, 2) == "Nick2"
      assert Social.nickname_at(relation, 3) == "Target Name"
    end
  end
end
