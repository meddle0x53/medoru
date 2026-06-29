defmodule MedoruWeb.LinkPreviewSubscribers do
  @moduledoc """
  Helper for LiveViews to subscribe to link-preview updates for a collection
  of text items (posts, comments, chat messages).
  """

  require Logger

  alias Medoru.LinkPreviews

  @doc """
  Triggers fetches for any URLs in the given texts and subscribes the current
  process to their completion topics. The socket assigns are updated so that
  templates re-render when previews become available.

  Subscriptions are established before fetches are triggered, so a very fast
  async fetch cannot complete and broadcast before the LiveView is listening.
  Each preview is only fetched once per socket.
  """
  def subscribe_for_texts(socket, texts) when is_list(texts) do
    existing_ids = Map.get(socket.assigns, :subscribed_link_preview_ids, MapSet.new())
    triggered_ids = Map.get(socket.assigns, :triggered_link_preview_ids, MapSet.new())

    previews_with_urls =
      texts
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(fn text ->
        text
        |> LinkPreviews.extract_urls()
        |> Enum.reject(&youtube_url?/1)
        |> Enum.map(fn url ->
          {:ok, preview} = LinkPreviews.get_or_create_preview(url)
          {preview.id, {url, preview}}
        end)
      end)
      |> Enum.uniq_by(fn {id, _value} -> id end)
      |> Enum.map(fn {_id, value} -> value end)

    new_previews_with_urls =
      Enum.reject(previews_with_urls, fn {_url, preview} ->
        MapSet.member?(existing_ids, preview.id)
      end)

    # Subscribe first, then trigger the fetch. This ordering prevents a race
    # where the fetch finishes and broadcasts before we are subscribed.
    Enum.each(new_previews_with_urls, fn {url, preview} ->
      Logger.debug(
        "LinkPreviewSubscribers: subscribing to preview #{preview.id} for #{url} (status: #{preview.status})"
      )

      LinkPreviews.subscribe(preview)
    end)

    new_triggered_ids =
      Enum.flat_map(new_previews_with_urls, fn {url, preview} ->
        if LinkPreviews.needs_fetch?(preview) and not MapSet.member?(triggered_ids, preview.id) do
          Logger.debug("LinkPreviewSubscribers: triggering fetch for #{url}")
          LinkPreviews.trigger_fetch(preview, url)
          [preview.id]
        else
          []
        end
      end)

    all_ids =
      MapSet.union(existing_ids, MapSet.new(new_previews_with_urls, fn {_url, p} -> p.id end))

    all_triggered_ids = MapSet.union(triggered_ids, MapSet.new(new_triggered_ids))

    socket
    |> Phoenix.Component.assign(:subscribed_link_preview_ids, all_ids)
    |> Phoenix.Component.assign(:triggered_link_preview_ids, all_triggered_ids)
    |> Phoenix.Component.assign(:link_preview_tick, System.monotonic_time())
  end

  @doc """
  Should be called from `handle_info` when a `:link_preview_ready` message is
  received. Bumps the tick so templates re-render with the new preview data.
  """
  def handle_preview_ready(socket) do
    Logger.debug(
      "LinkPreviewSubscribers: bumping link_preview_tick for socket #{inspect(self())}"
    )

    Phoenix.Component.assign(socket, :link_preview_tick, System.monotonic_time())
  end

  defp youtube_url?(url) do
    MedoruWeb.YoutubeEmbed.video_id(url) != :error
  end
end
