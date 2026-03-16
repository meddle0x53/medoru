defmodule MedoruWeb.Admin.LessonLive.Form do
  @moduledoc """
  Admin form for creating and editing lessons.
  """
  use MedoruWeb, :live_view

  import MedoruWeb.CoreComponents

  alias Medoru.Content
  alias Medoru.Content.Lesson

  embed_templates "form/*"

  @lesson_types [
    {:reading, gettext("Reading")},
    {:writing, gettext("Writing")},
    {:listening, gettext("Listening")},
    {:speaking, gettext("Speaking")},
    {:grammar, gettext("Grammar")}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    {form_template(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :lesson_types, @lesson_types)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    changeset = Content.change_lesson(%Lesson{})

    socket
    |> assign(:page_title, gettext("Add New Lesson"))
    |> assign(:lesson, %Lesson{})
    |> assign(:form, to_form(changeset))
    |> assign(:lesson_words, [])
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    lesson = Content.get_lesson_with_words!(id)
    changeset = Content.change_lesson(lesson)

    socket
    |> assign(:page_title, gettext("Edit Lesson - %{title}", title: lesson.title))
    |> assign(:lesson, lesson)
    |> assign(:form, to_form(changeset))
    |> assign(:lesson_words, lesson.lesson_words || [])
  end

  @impl true
  def handle_event("validate", %{"lesson" => lesson_params}, socket) do
    changeset =
      socket.assigns.lesson
      |> Content.change_lesson(lesson_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"lesson" => lesson_params}, socket) do
    save_lesson(socket, socket.assigns.live_action, lesson_params)
  end

  defp save_lesson(socket, :new, lesson_params) do
    case Content.create_lesson(lesson_params) do
      {:ok, lesson} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Lesson created successfully."))
         |> push_navigate(to: ~p"/admin/lessons/#{lesson.id}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_lesson(socket, :edit, lesson_params) do
    case Content.update_lesson(socket.assigns.lesson, lesson_params) do
      {:ok, _lesson} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Lesson updated successfully."))
         |> push_navigate(to: ~p"/admin/lessons")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Helper function to format Ecto changeset errors for display
  def format_error({message, _metadata}) when is_binary(message), do: message
  def format_error(message) when is_binary(message), do: message
  def format_error(_), do: gettext("Invalid value")
end
