defmodule MedoruWeb.LinkPreviewController do
  use MedoruWeb, :controller

  alias Medoru.LinkPreviews

  def show(conn, %{"url" => url}) do
    {:ok, preview} = LinkPreviews.get_or_fetch_preview(url)
    json(conn, preview_to_json(preview))
  end

  defp preview_to_json(preview) do
    %{
      id: preview.id,
      url: preview.url,
      title: preview.title,
      description: preview.description,
      image_url: preview.image_url,
      site_name: preview.site_name,
      favicon_url: preview.favicon_url,
      status: preview.status,
      error_message: preview.error_message,
      fetched_at: preview.fetched_at
    }
  end
end
