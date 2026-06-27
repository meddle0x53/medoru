defmodule Medoru.LinkPreviewsTest do
  use Medoru.DataCase

  alias Medoru.LinkPreviews
  alias Medoru.LinkPreviews.LinkPreview

  describe "normalize_url/1" do
    test "lowercases scheme and host" do
      assert LinkPreviews.Fetcher.normalize_url("HTTPS://EXAMPLE.COM/path") ==
               "https://example.com/path"
    end

    test "removes fragments" do
      assert LinkPreviews.Fetcher.normalize_url("https://example.com/path#section") ==
               "https://example.com/path"
    end

    test "strips trailing punctuation" do
      assert LinkPreviews.Fetcher.normalize_url("https://example.com/path.") ==
               "https://example.com/path"

      assert LinkPreviews.Fetcher.normalize_url("https://example.com/path)") ==
               "https://example.com/path"
    end
  end

  describe "validate_url/1" do
    test "allows public http urls" do
      assert LinkPreviews.Fetcher.validate_url("http://example.com") == :ok
    end

    test "allows public https urls" do
      assert LinkPreviews.Fetcher.validate_url("https://example.com") == :ok
    end

    test "rejects localhost" do
      assert {:error, :private_url} = LinkPreviews.Fetcher.validate_url("http://localhost")
    end

    test "rejects private ip ranges" do
      assert {:error, :private_url} = LinkPreviews.Fetcher.validate_url("http://192.168.1.1")
      assert {:error, :private_url} = LinkPreviews.Fetcher.validate_url("http://10.0.0.1")
    end

    test "rejects non-http schemes" do
      assert {:error, :invalid_url} = LinkPreviews.Fetcher.validate_url("ftp://example.com")
    end
  end

  describe "extract_urls/1" do
    test "extracts urls from text" do
      text = "Check out https://example.com and http://test.org/page"
      urls = LinkPreviews.extract_urls(text)
      assert "https://example.com" in urls
      assert "http://test.org/page" in urls
    end

    test "normalizes extracted urls" do
      text = "See https://EXAMPLE.COM/path."
      assert LinkPreviews.extract_urls(text) == ["https://example.com/path"]
    end
  end

  describe "cached_preview_for_text/1" do
    test "returns nil when no preview exists" do
      assert LinkPreviews.cached_preview_for_text("https://example.com/unknown") == nil
    end

    test "returns fetched preview when cached" do
      url = "https://example.com/cached"

      {:ok, preview} =
        LinkPreviews.create_preview(url, %{
          status: "fetched",
          title: "Cached Title"
        })

      assert LinkPreviews.cached_preview_for_text("Visit #{url} today!") == preview
    end

    test "ignores youtube urls" do
      text = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      assert LinkPreviews.cached_preview_for_text(text) == nil
    end
  end

  describe "get_or_fetch_preview/1" do
    test "creates pending preview for new url" do
      url = "https://example.com/new"
      assert Repo.get_by(LinkPreview, url: url) == nil

      {:ok, preview} = LinkPreviews.get_or_fetch_preview(url)

      assert preview.status == "pending"
      assert Repo.get_by(LinkPreview, url: url) != nil
    end

    test "returns existing preview" do
      url = "https://example.com/existing"
      {:ok, existing} = LinkPreviews.create_preview(url, %{status: "failed"})

      {:ok, preview} = LinkPreviews.get_or_fetch_preview(url)
      assert preview.id == existing.id
    end
  end

  describe "Fetcher.parse/2" do
    test "extracts Open Graph metadata" do
      html = """
      <html>
        <head>
          <title>Fallback Title</title>
          <meta property="og:title" content="OG Title">
          <meta property="og:description" content="OG Description">
          <meta property="og:image" content="/image.png">
          <meta property="og:site_name" content="Example Site">
          <link rel="icon" href="/favicon.ico">
        </head>
      </html>
      """

      assert %{
               title: "OG Title",
               description: "OG Description",
               image_url: "https://example.com/image.png",
               site_name: "Example Site",
               favicon_url: "https://example.com/favicon.ico",
               status: "fetched"
             } = LinkPreviews.Fetcher.parse(html, "https://example.com/page")
    end

    test "falls back to title and meta description" do
      html = """
      <html>
        <head>
          <title>Page Title</title>
          <meta name="description" content="Page description">
        </head>
      </html>
      """

      assert %{
               title: "Page Title",
               description: "Page description",
               site_name: "example.com",
               status: "fetched"
             } = LinkPreviews.Fetcher.parse(html, "https://example.com/page")
    end
  end
end
