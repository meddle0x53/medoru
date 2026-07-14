defmodule MedoruWeb.WhiteBoardPostRendererTest do
  use Medoru.DataCase
  use MedoruWeb, :verified_routes

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

  describe "link previews" do
    test "renders preview card for cached url in post content" do
      url = "https://example.com/article"

      {:ok, _preview} =
        Medoru.LinkPreviews.create_preview(url, %{
          status: "fetched",
          title: "Article Title",
          description: "Article description",
          site_name: "example.com"
        })

      html = WhiteBoardPostRenderer.render_post_content("Read this: #{url}", "post-1", nil)

      assert html =~ "Article Title"
      assert html =~ "Article description"
      assert html =~ "example.com"
    end

    test "renders preview card for cached url in comment content" do
      url = "https://example.com/comment-link"

      {:ok, _preview} =
        Medoru.LinkPreviews.create_preview(url, %{
          status: "fetched",
          title: "Comment Link",
          site_name: "example.com"
        })

      html = WhiteBoardPostRenderer.render_comment_content("See #{url}", nil)

      assert html =~ "Comment Link"
    end

    test "does not render preview card when no cached preview exists" do
      url = "https://example.com/unknown"
      html = WhiteBoardPostRenderer.render_post_content("Check #{url}", "post-1", nil)

      refute html =~ "link-preview-card"
      assert html =~ url
    end

    test "displays percent-encoded Japanese URLs as decoded text in posts" do
      url = "https://example.com/%E6%97%A5%E6%9C%AC"

      html = WhiteBoardPostRenderer.render_post_content("See #{url}", "post-1", nil)

      assert html =~ "https://example.com/日本"
      assert html =~ ~s|href="https://example.com/%E6%97%A5%E6%9C%AC"|
    end

    test "displays percent-encoded Japanese URLs as decoded text in comments" do
      url = "https://example.com/%E6%97%A5%E6%9C%AC"

      html = WhiteBoardPostRenderer.render_comment_content("See #{url}", nil)

      assert html =~ "https://example.com/日本"
      assert html =~ ~s|href="https://example.com/%E6%97%A5%E6%9C%AC"|
    end

    test "preserves text after the link" do
      url = "https://example.com/article"

      {:ok, _preview} =
        Medoru.LinkPreviews.create_preview(url, %{
          status: "fetched",
          title: "Article Title",
          fetched_at: DateTime.utc_now()
        })

      html =
        WhiteBoardPostRenderer.render_post_content(
          "Before #{url} and after text",
          "post-1",
          nil
        )

      assert html =~ "Before"
      assert html =~ "and after text"
      assert html =~ "Article Title"
    end

    test "strips trailing punctuation from autolinked urls" do
      url = "https://example.com/article"

      html =
        WhiteBoardPostRenderer.render_post_content(
          "See #{url}, and #{url}).",
          "post-1",
          nil
        )

      assert html =~ ~s|href="#{url}"|
      refute html =~ ~s|href="#{url}."|
      refute html =~ ~s|href="#{url})"|
      assert html =~ "See"
      assert html =~ ", and"
      assert html =~ ")."
    end

    test "preserves text after a link that starts the line" do
      url = "https://example.com/article"

      html =
        WhiteBoardPostRenderer.render_post_content(
          "#{url} some text after",
          "post-1",
          nil
        )

      assert html =~ url
      assert html =~ "some text after"
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
      assert html =~ ~p"/kanji/#{kanji.character}"
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
      assert html =~ ~p"/kanji/#{kanji.character}"
    end
  end
end
