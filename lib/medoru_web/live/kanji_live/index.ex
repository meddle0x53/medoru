defmodule MedoruWeb.KanjiLive.Index do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content

  embed_templates "*.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"

    {:ok,
     socket
     |> assign(:filter_type, :jlpt)
     |> assign(:jlpt_level, 5)
     |> assign(:school_level, nil)
     |> assign(:locale, locale)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    cond do
      # School level filter (SL1-SL6)
      params["sl"] not in [nil, ""] ->
        level = parse_school_level(params["sl"])
        kanji_list = Content.list_kanji_by_school_level(level)

        {:noreply,
         socket
         |> assign(:filter_type, :school)
         |> assign(:school_level, level)
         |> assign(:jlpt_level, nil)
         |> assign(:kanji_list, kanji_list)
         |> assign(:page_title, gettext("School Level %{level} Kanji", level: level))}

      # JLPT level filter (N1-N5) - default
      true ->
        level = parse_jlpt_level(params["level"])
        kanji_list = Content.list_kanji_by_level(level)

        {:noreply,
         socket
         |> assign(:filter_type, :jlpt)
         |> assign(:jlpt_level, level)
         |> assign(:school_level, nil)
         |> assign(:kanji_list, kanji_list)
         |> assign(:page_title, gettext("JLPT N%{level} Kanji", level: level))}
    end
  end

  defp parse_jlpt_level(nil), do: 5

  defp parse_jlpt_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {n, _} when n in 1..5 -> n
      _ -> 5
    end
  end

  defp parse_jlpt_level(level) when is_integer(level) and level in 1..5, do: level
  defp parse_jlpt_level(_), do: 5

  defp parse_school_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {n, _} when n in 1..6 -> n
      _ -> 1
    end
  end

  defp parse_school_level(level) when is_integer(level) and level in 1..6, do: level
  defp parse_school_level(_), do: 1

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
