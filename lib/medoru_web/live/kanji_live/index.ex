defmodule MedoruWeb.KanjiLive.Index do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content

  embed_templates "*.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, socket |> assign(:jlpt_level, 5) |> assign(:locale, locale)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    level = parse_level(params["level"])
    kanji_list = Content.list_kanji_by_level(level)

    {:noreply,
     socket
     |> assign(:jlpt_level, level)
     |> assign(:kanji_list, kanji_list)
     |> assign(:page_title, gettext("JLPT N%{level} Kanji", level: level))}
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

  # Helper for template: get first localized kanji meaning
  def localized_kanji_meaning(kanji, locale) do
    meanings = Content.get_localized_kanji_meanings(kanji, locale)
    List.first(meanings, "")
  end

  # Helper for template: get localized word meaning (needed for shared templates)
  def localized_word_meaning(word, locale) do
    Content.get_localized_meaning(word, locale)
  end
end
