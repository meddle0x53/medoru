defmodule MedoruWeb.WhiteBoardPostRendererTest do
  use Medoru.DataCase

  import Medoru.AccountsFixtures
  import Medoru.ContentFixtures

  alias MedoruWeb.WhiteBoardPostRenderer

  describe "mature word filtering" do
    test "/word command renders placeholder for restricted viewer" do
      word = word_fixture(%{text: "成人", reading: "せいじん", mature: true})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 17, safety: false})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      html = WhiteBoardPostRenderer.render_post_content("/word #{word.text}", "post-1", user)

      assert html =~ "unsafe content detected"
      refute html =~ word.reading
    end

    test "/word command renders preview for unrestricted viewer" do
      word = word_fixture(%{text: "成人", reading: "せいじん", mature: true})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 18, safety: false})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      html = WhiteBoardPostRenderer.render_post_content("/word #{word.text}", "post-1", user)

      assert html =~ word.text
      assert html =~ word.reading
    end

    test "inline word link renders placeholder for restricted viewer" do
      word = word_fixture(%{text: "成人", reading: "せいじん", mature: true})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 17, safety: false})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      html =
        WhiteBoardPostRenderer.render_post_content("Check out |#{word.text}|", "post-1", user)

      assert html =~ "unsafe content detected"
      refute html =~ "href="
    end

    test "inline word link renders link for unrestricted viewer" do
      word = word_fixture(%{text: "成人", reading: "せいじん", mature: true})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 18, safety: false})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      html =
        WhiteBoardPostRenderer.render_post_content("Check out |#{word.text}|", "post-1", user)

      assert html =~ "href=\"/words/#{word.id}\""
    end

    test "comment content filters mature inline links" do
      word = word_fixture(%{text: "成人", reading: "せいじん", mature: true})
      user = user_fixture_with_profile()
      {:ok, _} = Medoru.Accounts.update_profile(user.profile, %{age: 17, safety: false})
      user = Medoru.Accounts.get_user_with_profile(user.id)

      html = WhiteBoardPostRenderer.render_comment_content("See |#{word.text}|", user)

      assert html =~ "unsafe content detected"
    end
  end
end
