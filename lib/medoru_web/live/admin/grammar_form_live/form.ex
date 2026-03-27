defmodule MedoruWeb.Admin.GrammarFormLive.Form do
  @moduledoc """
  Admin form for creating and editing grammar forms.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Content.GrammarForm

  embed_templates "form/*"

  @word_types [
    {"Verb", "verb"},
    {"Adjective", "adjective"},
    {"Noun", "noun"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    {form_template(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :word_types, @word_types)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {form, changeset} =
      case socket.assigns.live_action do
        :new ->
          form = %GrammarForm{}
          changeset = Content.change_grammar_form(form)
          {form, changeset}

        :edit ->
          form = Content.get_grammar_form!(params["id"])
          changeset = Content.change_grammar_form(form)
          {form, changeset}
      end

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:form, form)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"grammar_form" => form_params}, socket) do
    changeset =
      socket.assigns.form
      |> Content.change_grammar_form(form_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"grammar_form" => form_params}, socket) do
    save_grammar_form(socket, socket.assigns.live_action, form_params)
  end

  defp save_grammar_form(socket, :edit, form_params) do
    case Content.update_grammar_form(socket.assigns.form, form_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Grammar form updated successfully."))
         |> push_navigate(to: ~p"/admin/grammar-forms")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_grammar_form(socket, :new, form_params) do
    case Content.create_grammar_form(form_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Grammar form created successfully."))
         |> push_navigate(to: ~p"/admin/grammar-forms")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp page_title(:new), do: gettext("New Grammar Form")
  defp page_title(:edit), do: gettext("Edit Grammar Form")
end
