defmodule MedoruWeb.YoutubeEmbed do
  @moduledoc """
  Helper for detecting YouTube URLs and generating embed iframes.
  """

  @youtube_watch_regex ~r/https?:\/\/(?:www\.)?youtube\.com\/watch\?v=([A-Za-z0-9_-]{11})/
  @youtube_short_regex ~r/https?:\/\/(?:www\.)?youtube\.com\/shorts\/([A-Za-z0-9_-]{11})/
  @youtube_embed_regex ~r/https?:\/\/(?:www\.)?youtube\.com\/embed\/([A-Za-z0-9_-]{11})/
  @youtube_shortlink_regex ~r/https?:\/\/youtu\.be\/([A-Za-z0-9_-]{11})/

  @doc """
  Extracts a YouTube video ID from a URL if it matches known patterns.
  """
  @spec video_id(String.t()) :: {:ok, String.t()} | :error
  def video_id(url) when is_binary(url) do
    cond do
      Regex.match?(@youtube_watch_regex, url) ->
        [_, id] = Regex.run(@youtube_watch_regex, url)
        {:ok, id}

      Regex.match?(@youtube_short_regex, url) ->
        [_, id] = Regex.run(@youtube_short_regex, url)
        {:ok, id}

      Regex.match?(@youtube_embed_regex, url) ->
        [_, id] = Regex.run(@youtube_embed_regex, url)
        {:ok, id}

      Regex.match?(@youtube_shortlink_regex, url) ->
        [_, id] = Regex.run(@youtube_shortlink_regex, url)
        {:ok, id}

      true ->
        :error
    end
  end

  @doc """
  Returns an iframe HTML string for embedding a YouTube video.
  """
  @spec embed_html(String.t()) :: String.t()
  def embed_html(video_id) when is_binary(video_id) do
    ~s|<span class="block my-2"><iframe class="rounded-lg w-full max-w-[560px] aspect-video" src="https://www.youtube.com/embed/#{video_id}" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen loading="lazy"></iframe></span>|
  end
end
