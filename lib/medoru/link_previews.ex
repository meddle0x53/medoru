defmodule Medoru.LinkPreviews do
  @moduledoc """
  Context for fetching and caching external link previews.
  """

  require Logger

  alias Medoru.Repo
  alias Medoru.LinkPreviews.{Fetcher, LinkPreview}

  @pubsub Medoru.PubSub
  @topic_prefix "link_previews:"

  @doc """
  Returns a preview for the given URL, fetching and caching it if necessary.
  If a fetch is needed, it runs asynchronously so rendering is never blocked.
  """
  def get_or_fetch_preview(url) when is_binary(url) do
    normalized = Fetcher.normalize_url(url)

    case get_preview_by_url(normalized) do
      nil ->
        case create_preview(normalized, %{status: "pending"}) do
          {:ok, preview} ->
            trigger_fetch(preview, url)
            {:ok, preview}

          {:error, changeset} ->
            handle_create_conflict(changeset, normalized, fn preview ->
              if preview.status in ["fetched", "failed", "blocked"] and stale?(preview) do
                trigger_fetch(preview, url)
              end
            end)
        end

      %LinkPreview{status: "pending"} = preview ->
        {:ok, preview}

      %LinkPreview{status: status} = preview when status in ["fetched", "failed", "blocked"] ->
        if stale?(preview) do
          trigger_fetch(preview, url)
        end

        {:ok, preview}
    end
  end

  @doc """
  Returns an existing preview for the URL or creates a pending one without
  starting a fetch. Useful when the caller wants to subscribe before triggering
  the fetch to avoid missing the completion broadcast.
  """
  def get_or_create_preview(url) when is_binary(url) do
    normalized = Fetcher.normalize_url(url)

    case get_preview_by_url(normalized) do
      nil ->
        case create_preview(normalized, %{status: "pending"}) do
          {:ok, preview} ->
            {:ok, preview}

          {:error, changeset} ->
            handle_create_conflict(changeset, normalized, fn _preview -> :ok end)
        end

      preview ->
        {:ok, preview}
    end
  end

  @doc """
  Returns a cached preview by URL, or nil if not cached.
  """
  def get_preview(url) when is_binary(url) do
    url |> Fetcher.normalize_url() |> get_preview_by_url()
  end

  @doc """
  Returns the first preview for any URL found in the text, creating a pending
  record if necessary. Does not trigger a fetch; callers that want live updates
  should subscribe to the returned preview and then call `trigger_fetch/2`.
  """
  def preview_for_text(text) when is_binary(text) and text != "" do
    text
    |> extract_urls()
    |> Enum.reject(&youtube_url?/1)
    |> Enum.find_value(fn url ->
      case get_or_create_preview(url) do
        {:ok, %LinkPreview{} = preview} -> preview
        _ -> nil
      end
    end)
  end

  def preview_for_text(_text), do: nil

  @doc """
  Returns the first cached and usable preview for any URL found in the text.
  Does not trigger a fetch.
  """
  def cached_preview_for_text(text) when is_binary(text) and text != "" do
    text
    |> extract_urls()
    |> Enum.reject(&youtube_url?/1)
    |> Enum.find_value(fn url ->
      case get_preview(url) do
        %LinkPreview{status: "fetched"} = preview -> preview
        _ -> nil
      end
    end)
  end

  def cached_preview_for_text(_text), do: nil

  @doc """
  Extracts URLs from text using the project's shared regex.
  """
  def extract_urls(text) when is_binary(text) do
    url_regex = ~r/https?:\/\/[^\s<>"{}|\\^`\[\]]+/
    Regex.scan(url_regex, text) |> List.flatten() |> Enum.map(&Fetcher.normalize_url/1)
  end

  @doc """
  Creates a new link preview record.
  """
  def create_preview(url, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.put("url", url)

    %LinkPreview{}
    |> LinkPreview.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a link preview record.
  """
  def update_preview(%LinkPreview{} = preview, attrs) do
    attrs = Map.new(attrs, fn {k, v} -> {to_string(k), v} end)

    preview
    |> LinkPreview.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Subscribes the current process to updates for a given preview.
  """
  def subscribe(%LinkPreview{id: id}), do: subscribe(id)

  def subscribe(id) when is_binary(id) do
    Phoenix.PubSub.subscribe(@pubsub, "#{@topic_prefix}#{id}")
  end

  @doc """
  Broadcasts that a preview has been updated.
  """
  def broadcast_update(%LinkPreview{id: id} = preview) do
    Logger.debug(
      "LinkPreviews: broadcasting :link_preview_ready for preview #{id} (status: #{preview.status}) to topic #{@topic_prefix}#{id}"
    )

    Phoenix.PubSub.broadcast(@pubsub, "#{@topic_prefix}#{id}", {:link_preview_ready, preview})
  end

  defp get_preview_by_url(url) do
    Repo.get_by(LinkPreview, url: url)
  end

  # Handles the race where another process inserts the same URL between our
  # get and create. In that case we return the existing record instead of
  # crashing on the unique constraint.
  defp handle_create_conflict(changeset, normalized, on_existing) do
    if unique_url_error?(changeset) do
      case get_preview_by_url(normalized) do
        nil ->
          {:error, changeset}

        preview ->
          on_existing.(preview)
          {:ok, preview}
      end
    else
      {:error, changeset}
    end
  end

  defp unique_url_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:url, {"has already been taken", opts}} ->
        Keyword.get(opts, :constraint) == :unique

      _ ->
        false
    end)
  end

  @doc """
  Triggers an asynchronous fetch for the given preview.
  In test mode the fetch runs synchronously.
  """
  def trigger_fetch(%LinkPreview{id: id}, original_url) do
    # Run synchronously in test mode to avoid Ecto sandbox issues with spawned tasks.
    if Application.fetch_env!(:medoru, :env) == :test do
      do_fetch_and_update(id, original_url)
    else
      Task.start(fn -> do_fetch_and_update(id, original_url) end)
    end
  end

  defp do_fetch_and_update(id, original_url) do
    Logger.debug("LinkPreviews: fetching #{original_url}")

    case Fetcher.fetch(original_url) do
      {:ok, attrs} ->
        Logger.debug("LinkPreviews: fetch succeeded for #{original_url}")

        with preview when not is_nil(preview) <- get_preview_by_id(id),
             {:ok, updated} <-
               update_preview(preview, Map.merge(attrs, %{"fetched_at" => DateTime.utc_now()})) do
          broadcast_update(updated)
        end

      {:error, reason} ->
        error_message = inspect(reason)
        Logger.warning("LinkPreviews: fetch failed for #{original_url}: #{error_message}")

        with preview when not is_nil(preview) <- get_preview_by_id(id),
             {:ok, updated} <-
               update_preview(preview, %{
                 "status" => "failed",
                 "error_message" => error_message,
                 "fetched_at" => DateTime.utc_now()
               }) do
          broadcast_update(updated)
        end
    end
  end

  defp get_preview_by_id(id) do
    Repo.get(LinkPreview, id)
  end

  @doc """
  Returns true if the preview should be fetched (pending or stale).
  """
  def needs_fetch?(%LinkPreview{status: "pending"}), do: true
  def needs_fetch?(%LinkPreview{} = preview), do: stale?(preview)

  defp stale?(%LinkPreview{fetched_at: nil}), do: false

  defp stale?(%LinkPreview{status: "fetched", fetched_at: fetched_at}) do
    DateTime.diff(DateTime.utc_now(), fetched_at, :day) >= 7
  end

  defp stale?(%LinkPreview{status: status, fetched_at: fetched_at})
       when status in ["failed", "blocked"] do
    DateTime.diff(DateTime.utc_now(), fetched_at, :hour) >= 24
  end

  defp stale?(_), do: false

  defp youtube_url?(url) do
    MedoruWeb.YoutubeEmbed.video_id(url) != :error
  end
end
