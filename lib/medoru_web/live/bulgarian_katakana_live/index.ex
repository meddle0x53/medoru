defmodule MedoruWeb.BulgarianKatakanaLive.Index do
  @moduledoc """
  Index page showing the Bulgarian alphabet as a katakana reading chart.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content.BulgarianKatakana

  embed_templates "index.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, :locale, locale)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    letters = BulgarianKatakana.list_letters()

    {:noreply,
     socket
     |> assign(:letters, letters)
     |> assign(:page_title, gettext("Bulgarian Katakana"))}
  end
end
