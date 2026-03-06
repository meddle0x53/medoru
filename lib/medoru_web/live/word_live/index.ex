defmodule MedoruWeb.WordLive.Index do
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :difficulty, 5)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    difficulty = parse_difficulty(params["difficulty"])
    words = Content.list_words_by_difficulty(difficulty)

    {:noreply,
     socket
     |> assign(:difficulty, difficulty)
     |> assign(:words, words)
     |> assign(:page_title, "JLPT N#{difficulty} Vocabulary")}
  end

  defp parse_difficulty(nil), do: 5

  defp parse_difficulty(difficulty) when is_binary(difficulty) do
    case Integer.parse(difficulty) do
      {n, _} when n in 1..5 -> n
      _ -> 5
    end
  end

  defp parse_difficulty(difficulty) when is_integer(difficulty) and difficulty in 1..5,
    do: difficulty

  defp parse_difficulty(_), do: 5
end
