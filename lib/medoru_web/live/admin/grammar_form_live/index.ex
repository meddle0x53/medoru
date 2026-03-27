defmodule MedoruWeb.Admin.GrammarFormLive.Index do
  @moduledoc """
  Admin interface for listing and managing grammar forms.
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
  def handle_params(params, _url, socket) do
    word_type_filter = params["word_type"]

    grammar_forms =
      if word_type_filter do
        Content.list_grammar_forms(word_type: word_type_filter)
      else
        Content.list_grammar_forms()
      end

    {:noreply,
     socket
     |> assign(:page_title, gettext("Admin - Grammar Forms"))
     |> assign(:grammar_forms, grammar_forms)
     |> assign(:word_type_filter, word_type_filter)}
  end

  @impl true
  def handle_event("filter_word_type", %{"word_type" => word_type}, socket) do
    filter_param = if word_type == "", do: nil, else: word_type

    {:noreply,
     socket
     |> push_patch(to: ~p"/admin/grammar-forms?#{%{word_type: filter_param}}")}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, socket |> push_patch(to: ~p"/admin/grammar-forms")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    grammar_form = Content.get_grammar_form!(id)

    case Content.delete_grammar_form(grammar_form) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Grammar form deleted successfully."))
         |> push_patch(to: ~p"/admin/grammar-forms")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to delete grammar form. It may be in use."))}
    end
  end

  defp word_type_label("verb"), do: gettext("Verb")
  defp word_type_label("adjective"), do: gettext("Adjective")
  defp word_type_label("noun"), do: gettext("Noun")
  defp word_type_label(_), do: gettext("Other")

  defp word_type_badge_color("verb"), do: "badge-primary"
  defp word_type_badge_color("adjective"), do: "badge-secondary"
  defp word_type_badge_color("noun"), do: "badge-accent"
  defp word_type_badge_color(_), do: "badge-ghost"
end
