defmodule MedoruWeb.KanjiLive.Index do
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :jlpt_level, 5)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    level = parse_level(params["level"])
    kanji_list = Content.list_kanji_by_level(level)

    {:noreply,
     socket
     |> assign(:jlpt_level, level)
     |> assign(:kanji_list, kanji_list)
     |> assign(:page_title, "JLPT N#{level} Kanji")}
  end

  defp parse_level(nil), do: 5

  defp parse_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {n, _} when n in 1..5 -> n
      _ -> 5
    end
  end

  defp parse_level(level) when is_integer(level) and level in 1..5, do: level
  defp parse_level(_), do: 5
end
