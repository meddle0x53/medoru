defmodule MedoruWeb.Teacher.CustomLessonLive.Publish do
  @moduledoc """
  LiveView for publishing custom lessons to classrooms.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Classrooms

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Verify user is a teacher
    if user.type not in ["teacher", "admin"] do
      {:ok,
       socket
       |> put_flash(:error, "Only teachers can publish lessons.")
       |> push_navigate(to: ~p"/classrooms")}
    else
      lesson = Content.get_custom_lesson_with_words!(id)

      # Verify ownership and published status
      cond do
        lesson.creator_id != user.id ->
          {:ok,
           socket
           |> put_flash(:error, "You can only publish your own lessons.")
           |> push_navigate(to: ~p"/teacher/custom-lessons")}

        lesson.status != "published" ->
          {:ok,
           socket
           |> put_flash(:error, "Lesson must be published first.")
           |> push_navigate(to: ~p"/teacher/custom-lessons/#{lesson.id}/edit")}

        true ->
          classrooms = Classrooms.list_teacher_classrooms(user.id)
          published = Content.list_classroom_custom_lessons(lesson.id, status: nil)

          published_map =
            published
            |> Enum.map(fn pc -> {pc.classroom_id, pc} end)
            |> Enum.into(%{})

          {:ok,
           socket
           |> assign(:lesson, lesson)
           |> assign(:classrooms, classrooms)
           |> assign(:published_map, published_map)}
      end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, "Publish: #{socket.assigns.lesson.title}")}
  end

  @impl true
  def handle_event("publish", %{"classroom_id" => classroom_id}, socket) do
    user = socket.assigns.current_scope.current_user
    lesson = socket.assigns.lesson

    case Content.publish_lesson_to_classroom(lesson.id, classroom_id, user.id) do
      {:ok, published} ->
        published_map = Map.put(socket.assigns.published_map, classroom_id, published)

        {:noreply,
         socket
         |> assign(:published_map, published_map)
         |> put_flash(:info, "Published to classroom!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to publish.")}
    end
  end

  @impl true
  def handle_event("unpublish", %{"classroom_id" => classroom_id}, socket) do
    user = socket.assigns.current_scope.current_user

    case Map.get(socket.assigns.published_map, classroom_id) do
      nil ->
        {:noreply, socket}

      published ->
        case Content.unpublish_lesson_from_classroom(published, user.id) do
          {:ok, _} ->
            published_map = Map.delete(socket.assigns.published_map, classroom_id)

            {:noreply,
             socket
             |> assign(:published_map, published_map)
             |> put_flash(:info, "Unpublished from classroom.")}

          {:error, :not_authorized} ->
            {:noreply, put_flash(socket, :error, "Not authorized.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to unpublish.")}
        end
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
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Lessons
          </.link>
          <h1 class="text-2xl font-bold text-base-content">Publish Lesson</h1>
          <p class="text-secondary">{@lesson.title} • {length(@lesson.custom_lesson_words)} words</p>
        </div>

        <%!-- Classrooms List --%>
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <h2 class="card-title text-lg mb-4">Select Classrooms</h2>

            <%= if @classrooms == [] do %>
              <div class="text-center py-8">
                <.icon name="hero-users" class="w-12 h-12 mx-auto text-base-300 mb-4" />
                <p class="text-secondary">You don't have any classrooms yet.</p>
                <.link navigate={~p"/teacher/classrooms/new"} class="btn btn-primary btn-sm mt-4">
                  Create Classroom
                </.link>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for classroom <- @classrooms do %>
                  <% published = Map.get(@published_map, classroom.id) %>
                  <div class="flex items-center justify-between p-4 bg-base-200 rounded-lg">
                    <div>
                      <h3 class="font-medium text-base-content">{classroom.name}</h3>
                      <p class="text-sm text-secondary">
                        <%= case classroom.status do %>
                          <% :active -> %>
                            <%= published && "Published" || "Not published" %>
                          <% :closed -> %>
                            Closed
                          <% :archived -> %>
                            Archived
                        <% end %>
                      </p>
                    </div>

                    <%= cond do %>
                      <% classroom.status != :active -> %>
                        <span class="badge badge-neutral">Inactive</span>

                      <% published -> %>
                        <button
                          phx-click="unpublish"
                          phx-value-classroom_id={classroom.id}
                          class="btn btn-ghost btn-sm text-error"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4 mr-1" />
                          Unpublish
                        </button>

                      <% true -> %>
                        <button
                          phx-click="publish"
                          phx-value-classroom_id={classroom.id}
                          class="btn btn-primary btn-sm"
                        >
                          <.icon name="hero-share" class="w-4 h-4 mr-1" />
                          Publish
                        </button>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Info Box --%>
        <div class="alert alert-info mt-6 text-sm">
          <.icon name="hero-information-circle" class="w-5 h-5" />
          <div>
            <p class="font-medium">What happens when you publish?</p>
            <ul class="list-disc list-inside mt-1 opacity-90">
              <li>Students in the classroom can see and study the lesson</li>
              <li>Students earn points upon completion</li>
              <li>You can unpublish at any time</li>
            </ul>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
