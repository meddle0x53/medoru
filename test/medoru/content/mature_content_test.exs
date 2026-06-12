defmodule Medoru.Content.MatureContentTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias Medoru.Content.MatureContent

  describe "mature_word_visible_to_user?/2" do
    test "non-mature words are visible to everyone" do
      word = word_fixture(%{mature: false})
      user = user_fixture_with_profile()

      assert MatureContent.mature_word_visible_to_user?(word, nil)
      assert MatureContent.mature_word_visible_to_user?(word, user)
    end

    test "mature words are hidden from anonymous users" do
      word = word_fixture(%{mature: true})

      refute MatureContent.mature_word_visible_to_user?(word, nil)
    end

    test "mature words are hidden from users without a profile" do
      word = word_fixture(%{mature: true})
      user = user_fixture()

      refute MatureContent.mature_word_visible_to_user?(word, user)
    end

    test "mature words are hidden from users without age" do
      word = word_fixture(%{mature: true})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: nil})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      refute MatureContent.mature_word_visible_to_user?(word, user)
    end

    test "mature words are hidden from users under 18" do
      word = word_fixture(%{mature: true})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 17, safety: false})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      refute MatureContent.mature_word_visible_to_user?(word, user)
    end

    test "mature words are hidden from users with safety mode enabled" do
      word = word_fixture(%{mature: true})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 25, safety: true})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      refute MatureContent.mature_word_visible_to_user?(word, user)
    end

    test "mature words are visible to adult users with safety mode disabled" do
      word = word_fixture(%{mature: true})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 18, safety: false})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      assert MatureContent.mature_word_visible_to_user?(word, user)
    end
  end

  describe "viewer_restricted_from_mature?/1" do
    test "anonymous viewers are restricted" do
      assert MatureContent.viewer_restricted_from_mature?(nil)
    end

    test "adult users with safety disabled are not restricted" do
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 30, safety: false})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      refute MatureContent.viewer_restricted_from_mature?(user)
    end
  end
end
