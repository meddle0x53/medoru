defmodule MedoruWeb.WordLive.Show do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content

  embed_templates "*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    word = Content.get_word_with_kanji!(id)

    {:noreply,
     socket
     |> assign(:word, word)
     |> assign(
       :page_title,
       gettext("%{word} - %{meaning}", word: word.text, meaning: word.meaning)
     )}
  end

  # Helper functions needed for shared templates
  def page_link_params(assigns, page) do
    assigns = Map.new(assigns)

    [
      difficulty: Map.get(assigns, :difficulty),
      search: Map.get(assigns, :search),
      page: page,
      sort_by: Map.get(assigns, :sort_by),
      sort_order: Map.get(assigns, :sort_order)
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  def sort_link_params(assigns, sort_by) do
    assigns = Map.new(assigns)
    current_sort_by = Map.get(assigns, :sort_by)
    current_sort_order = Map.get(assigns, :sort_order)

    sort_order =
      if current_sort_by == sort_by do
        toggle_order(current_sort_order)
      else
        default_order(sort_by)
      end

    [
      difficulty: Map.get(assigns, :difficulty),
      search: Map.get(assigns, :search),
      page: 1,
      sort_by: sort_by,
      sort_order: sort_order
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  def sort_indicator(assigns, column) do
    assigns = Map.new(assigns)

    if Map.get(assigns, :sort_by) == column do
      case Map.get(assigns, :sort_order) do
        :asc -> "↑"
        :desc -> "↓"
        _ -> ""
      end
    else
      ""
    end
  end

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  # Learning order: sort_score combines frequency + complexity (ascending)
  defp default_order(:sort_score), do: :asc
  # Most common words first (ascending frequency)
  defp default_order(:usage_frequency), do: :asc
  # JLPT: Easiest first (N5=5 -> N1=1, so descending)
  defp default_order(:difficulty), do: :desc
  defp default_order(:inserted_at), do: :desc
  defp default_order(_), do: :asc
end
