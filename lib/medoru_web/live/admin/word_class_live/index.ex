defmodule MedoruWeb.Admin.WordClassLive.Index do
  @moduledoc """
  Admin interface for listing and managing word classes.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content

  embed_templates "index/*"

  @impl true
  def render(assigns) do
    ~H"""
    {index(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    word_classes = Content.list_word_classes()

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Word Classes"))
     |> assign(:word_classes, word_classes)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    word_class = Content.get_word_class!(id)

    case Content.delete_word_class(word_class) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word class deleted successfully."))
         |> push_patch(to: ~p"/admin/word-classes")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete word class. It may be in use."))}
    end
  end
end
