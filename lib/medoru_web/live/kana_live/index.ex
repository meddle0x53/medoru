defmodule MedoruWeb.KanaLive.Index do
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content.Kana

  embed_templates "index.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, :locale, locale)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    type = parse_type_from_url(url)

    kana_list =
      case type do
        :hiragana -> Kana.list_hiragana()
        :katakana -> Kana.list_katakana()
      end

    groups =
      Kana.gojuon_groups()
      |> Enum.map(fn group ->
        {
          group,
          group_label(group),
          Kana.by_group(kana_list, group)
        }
      end)
      |> Enum.reject(fn {_, _, items} -> items == [] end)

    {:noreply,
     socket
     |> assign(:type, type)
     |> assign(:groups, groups)
     |> assign(:page_title, page_title(type))}
  end

  defp parse_type_from_url(url) do
    path = URI.parse(url).path || ""

    if String.starts_with?(path, "/katakana") do
      :katakana
    else
      :hiragana
    end
  end

  defp page_title(:hiragana), do: gettext("Hiragana")
  defp page_title(:katakana), do: gettext("Katakana")

  defp group_label(:a), do: "a"
  defp group_label(:ka), do: "ka"
  defp group_label(:sa), do: "sa"
  defp group_label(:ta), do: "ta"
  defp group_label(:na), do: "na"
  defp group_label(:ha), do: "ha"
  defp group_label(:ma), do: "ma"
  defp group_label(:ya), do: "ya"
  defp group_label(:ra), do: "ra"
  defp group_label(:wa), do: "wa"
  defp group_label(:ga), do: "ga"
  defp group_label(:za), do: "za"
  defp group_label(:da), do: "da"
  defp group_label(:ba), do: "ba"
  defp group_label(:pa), do: "pa"
  defp group_label(:small), do: gettext("Small")
  defp group_label(:va), do: "va"
  defp group_label(_), do: "?"
end
