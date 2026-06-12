defmodule MedoruWeb.YoutubeEmbedTest do
  use ExUnit.Case, async: true

  alias MedoruWeb.YoutubeEmbed

  describe "video_id/1" do
    test "extracts ID from watch URL" do
      assert YoutubeEmbed.video_id("https://www.youtube.com/watch?v=dQw4w9WgXcQ") ==
               {:ok, "dQw4w9WgXcQ"}

      assert YoutubeEmbed.video_id("https://youtube.com/watch?v=dQw4w9WgXcQ") ==
               {:ok, "dQw4w9WgXcQ"}

      assert YoutubeEmbed.video_id("http://www.youtube.com/watch?v=dQw4w9WgXcQ") ==
               {:ok, "dQw4w9WgXcQ"}
    end

    test "extracts ID from short URL (youtu.be)" do
      assert YoutubeEmbed.video_id("https://youtu.be/dQw4w9WgXcQ") == {:ok, "dQw4w9WgXcQ"}
      assert YoutubeEmbed.video_id("http://youtu.be/dQw4w9WgXcQ") == {:ok, "dQw4w9WgXcQ"}
    end

    test "extracts ID from embed URL" do
      assert YoutubeEmbed.video_id("https://www.youtube.com/embed/dQw4w9WgXcQ") ==
               {:ok, "dQw4w9WgXcQ"}
    end

    test "extracts ID from shorts URL" do
      assert YoutubeEmbed.video_id("https://www.youtube.com/shorts/dQw4w9WgXcQ") ==
               {:ok, "dQw4w9WgXcQ"}
    end

    test "returns :error for non-YouTube URLs" do
      assert YoutubeEmbed.video_id("https://example.com") == :error
      assert YoutubeEmbed.video_id("https://google.com") == :error
      assert YoutubeEmbed.video_id("not a url") == :error
    end

    test "returns :error for invalid YouTube URLs" do
      assert YoutubeEmbed.video_id("https://www.youtube.com/watch?v=SHORT") == :error
      assert YoutubeEmbed.video_id("https://www.youtube.com/") == :error
    end
  end

  describe "embed_html/1" do
    test "generates an iframe with the video ID" do
      html = YoutubeEmbed.embed_html("dQw4w9WgXcQ")

      assert html =~ ~s|src="https://www.youtube.com/embed/dQw4w9WgXcQ"|
      assert html =~ "<iframe"
      assert html =~ "</iframe>"
      assert html =~ "aspect-video"
      assert html =~ "allowfullscreen"
    end
  end
end
