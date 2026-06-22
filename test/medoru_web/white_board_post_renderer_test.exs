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

  describe "command spacing" do
    test "/w with extra spaces around expression renders word preview" do
      word = word_fixture(%{text: "たべる", reading: "たべる"})
      html = WhiteBoardPostRenderer.render_post_content("/w   #{word.text}   ", "post-1", nil)

      assert html =~ word.text
      assert html =~ word.reading
    end

    test "/word with extra spaces around expression renders word preview" do
      word = word_fixture(%{text: "のむ", reading: "のむ"})
      html = WhiteBoardPostRenderer.render_post_content("/word   #{word.text}   ", "post-1", nil)

      assert html =~ word.text
      assert html =~ word.reading
    end

    test "\\w with extra spaces around expression renders word preview" do
      word = word_fixture(%{text: "みる", reading: "みる"})
      html = WhiteBoardPostRenderer.render_post_content("\\w   #{word.text}   ", "post-1", nil)

      assert html =~ word.text
      assert html =~ word.reading
    end

    test "/grammar with extra spaces around expression renders grammar preview" do
      grammar = grammar_definition_fixture(%{title: "te-form spacing"})

      html =
        WhiteBoardPostRenderer.render_post_content(
          "/grammar   #{grammar.title}   ",
          "post-1",
          nil
        )

      assert html =~ grammar.title
      assert html =~ "/grammars/#{grammar.slug}"
    end

    test "/g with extra spaces around expression renders grammar preview" do
      grammar = grammar_definition_fixture(%{title: "g spacing"})

      html = WhiteBoardPostRenderer.render_post_content("/g   #{grammar.title}   ", "post-1", nil)

      assert html =~ grammar.title
      assert html =~ "/grammars/#{grammar.slug}"
    end

    test "/k with extra spaces around expression renders kanji preview" do
      kanji = kanji_fixture(%{character: "山"})

      html =
        WhiteBoardPostRenderer.render_post_content("/k   #{kanji.character}   ", "post-1", nil)

      assert html =~ "kanji-chat-preview"
      assert html =~ "/kanji/#{kanji.id}"
    end

    test "/kanji with extra spaces around expression renders kanji preview" do
      kanji = kanji_fixture(%{character: "川"})

      html =
        WhiteBoardPostRenderer.render_post_content(
          "/kanji   #{kanji.character}   ",
          "post-1",
          nil
        )

      assert html =~ "kanji-chat-preview"
      assert html =~ "/kanji/#{kanji.id}"
    end
  end
end
