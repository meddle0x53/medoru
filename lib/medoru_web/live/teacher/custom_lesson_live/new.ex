defmodule MedoruWeb.Teacher.CustomLessonLive.New do
  @moduledoc """
  LiveView for creating a new custom lesson.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Content.CustomLesson

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Verify user is a teacher
    if user.type not in ["teacher", "admin"] do
      {:ok,
       socket
       |> put_flash(:error, gettext("Only teachers can create lessons."))
       |> push_navigate(to: ~p"/classrooms")}
    else
      changeset = Content.change_custom_lesson(%CustomLesson{})
      {:ok, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, gettext("New Custom Lesson"))}
  end

  @impl true
  def handle_event("validate", %{"custom_lesson" => lesson_params}, socket) do
    changeset =
      %CustomLesson{}
      |> Content.change_custom_lesson(lesson_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"custom_lesson" => lesson_params}, socket) do
    user = socket.assigns.current_scope.current_user

    attrs =
      lesson_params
      |> Map.put("creator_id", user.id)
      |> Map.put("status", "draft")

    case Content.create_custom_lesson(attrs) do
      {:ok, lesson} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Lesson created! Now add some words."))
         |> push_navigate(to: ~p"/teacher/custom-lessons/#{lesson.id}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/custom-lessons"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Lessons")}
          </.link>
          <h1 class="text-2xl font-bold text-base-content">{gettext("Create New Lesson")}</h1>
          <p class="text-secondary">{gettext("Start with the basics, then add words")}</p>
        </div>

        <%!-- Form --%>
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <.form
              for={@form}
              id="lesson-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-6"
            >
              <%!-- Title --%>
              <div>
                <.input
                  field={@form[:title]}
                  type="text"
                  label={gettext("Lesson Title")}
                  placeholder={gettext("e.g., Spring Vocabulary Set 1")}
                  required
                />
              </div>

              <%!-- Description --%>
              <div>
                <.input
                  field={@form[:description]}
                  type="textarea"
                  label={gettext("Description (optional)")}
                  placeholder={gettext("What will students learn in this lesson?")}
                  rows={3}
                />
                <p class="text-xs text-secondary mt-1">{gettext("Maximum 500 characters")}</p>
              </div>

              <%!-- Difficulty --%>
              <div>
                <label class="block text-sm font-medium text-base-content mb-2">
                  {gettext("Difficulty Level (optional)")}
                </label>
                <div class="flex gap-2">
                  <%= for level <- [5, 4, 3, 2, 1] do %>
                    <label class="cursor-pointer">
                      <input
                        type="radio"
                        name="custom_lesson[difficulty]"
                        value={level}
                        checked={to_string(@form[:difficulty].value) == to_string(level)}
                        class="peer sr-only"
                      />
                      <span class="btn btn-sm btn-outline peer-checked:btn-primary peer-checked:text-primary-content">
                        N{level}
                      </span>
                    </label>
                  <% end %>
                </div>
                <p class="text-xs text-secondary mt-1">
                  {gettext("Helps students find appropriate lessons. Leave blank for mixed levels.")}
                </p>
              </div>

              <%!-- Submit --%>
              <div class="flex gap-4 pt-4 border-t border-base-200">
                <.link
                  navigate={~p"/teacher/custom-lessons"}
                  class="btn btn-ghost flex-1"
                >
                  {gettext("Cancel")}
                </.link>
                <button type="submit" class="btn btn-primary flex-1">
                  <.icon name="hero-arrow-right" class="w-5 h-5 mr-2" />
                  {gettext("Create & Add Words")}
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
