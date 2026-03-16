defmodule MedoruWeb.Admin.WordLive.Form do
  @moduledoc """
  Admin form for creating and editing words.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.CoreComponents

  alias Medoru.Content
  alias Medoru.Content.Word

  embed_templates "form/*"

  @word_types [
    {gettext("Noun"), "noun"},
    {gettext("Verb"), "verb"},
    {gettext("Adjective"), "adjective"},
    {gettext("Adverb"), "adverb"},
    {gettext("Particle"), "particle"},
    {gettext("Pronoun"), "pronoun"},
    {gettext("Counter"), "counter"},
    {gettext("Expression"), "expression"},
    {gettext("Other"), "other"}
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
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    changeset = Content.change_word(%Word{})

    socket
    |> assign(:page_title, gettext("Add New Word"))
    |> assign(:word, %Word{})
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    word = Content.get_word!(id)
    changeset = Content.change_word(word)

    socket
    |> assign(:page_title, gettext("Edit Word - %{text}", text: word.text))
    |> assign(:word, word)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def handle_event("validate", %{"word" => word_params}, socket) do
    changeset =
      socket.assigns.word
      |> Content.change_word(word_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"word" => word_params}, socket) do
    save_word(socket, socket.assigns.live_action, word_params)
  end

  defp save_word(socket, :new, word_params) do
    case Content.create_word(word_params) do
      {:ok, _word} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word created successfully."))
         |> push_navigate(to: ~p"/admin/words")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_word(socket, :edit, word_params) do
    case Content.update_word(socket.assigns.word, word_params) do
      {:ok, word} ->
        changeset = Content.change_word(word)

        {:noreply,
         socket
         |> assign(:word, word)
         |> assign(:form, to_form(changeset))
         |> put_flash(:info, gettext("Word updated successfully."))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Helper function to format Ecto changeset errors for display
  def format_error({message, _metadata}) when is_binary(message), do: message
  def format_error(message) when is_binary(message), do: message
  def format_error(_), do: gettext("Invalid value")
end
