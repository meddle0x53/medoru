defmodule MedoruWeb.Admin.WordClassLive.Form do
  @moduledoc """
  Admin form for creating and editing word classes.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Content.WordClass

  embed_templates "form/*"

  @impl true
  def render(assigns) do
    ~H"""
    {form_template(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {word_class, changeset} =
      case socket.assigns.live_action do
        :new ->
          word_class = %WordClass{}
          changeset = Content.change_word_class(word_class)
          {word_class, changeset}

        :edit ->
          word_class = Content.get_word_class!(params["id"])
          changeset = Content.change_word_class(word_class)
          {word_class, changeset}
      end

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:word_class, word_class)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"word_class" => class_params}, socket) do
    changeset =
      socket.assigns.word_class
      |> Content.change_word_class(class_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"word_class" => class_params}, socket) do
    save_word_class(socket, socket.assigns.live_action, class_params)
  end

  defp save_word_class(socket, :edit, class_params) do
    case Content.update_word_class(socket.assigns.word_class, class_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word class updated successfully."))
         |> push_navigate(to: ~p"/admin/word-classes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_word_class(socket, :new, class_params) do
    case Content.create_word_class(class_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Word class created successfully."))
         |> push_navigate(to: ~p"/admin/word-classes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp page_title(:new), do: gettext("New Word Class")
  defp page_title(:edit), do: gettext("Edit Word Class")
end
