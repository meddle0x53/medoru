defmodule MedoruWeb.Teacher.CustomLessonLive.Index do
  @moduledoc """
  LiveView for teachers to manage their custom lessons.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Verify user is a teacher
    if user.type not in ["teacher", "admin"] do
      {:ok,
       socket
       |> put_flash(:error, "Only teachers can access this page.")
       |> push_navigate(to: ~p"/classrooms")}
    else
      lessons = Content.list_teacher_custom_lessons(user.id)
      {:ok, assign(socket, :lessons, lessons)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    status = params["status"] || "all"
    user = socket.assigns.current_scope.current_user

    lessons =
      case status do
        "all" -> Content.list_teacher_custom_lessons(user.id)
        status -> Content.list_teacher_custom_lessons(user.id, status: status)
      end

    {:noreply,
     socket
     |> assign(:page_title, "My Custom Lessons")
     |> assign(:lessons, lessons)
     |> assign(:current_filter, status)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    user = socket.assigns.current_scope.current_user

    lessons =
      case status do
        "all" -> Content.list_teacher_custom_lessons(user.id)
        status -> Content.list_teacher_custom_lessons(user.id, status: status)
      end

    {:noreply,
     socket
     |> assign(:lessons, lessons)
     |> assign(:current_filter, status)}
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.current_user
    lesson = Content.get_custom_lesson!(id)

    # Verify ownership
    if lesson.creator_id != user.id do
      {:noreply, put_flash(socket, :error, "You can only archive your own lessons.")}
    else
      case Content.archive_custom_lesson(lesson) do
        {:ok, _} ->
          lessons = Content.list_teacher_custom_lessons(user.id)
          {:noreply,
           socket
           |> put_flash(:info, "Lesson archived successfully.")
           |> assign(:lessons, lessons)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to archive lesson.")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold text-base-content">My Custom Lessons</h1>
            <p class="text-secondary mt-1">Create and manage reading lessons for your classrooms</p>
          </div>
          <.link navigate={~p"/teacher/custom-lessons/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="w-5 h-5 mr-2" /> New Lesson
          </.link>
        </div>

        <%!-- Filters --%>
        <div class="flex gap-2 mb-6">
          <button
            phx-click="filter"
            phx-value-status="all"
            class={["btn btn-sm", @current_filter == "all" && "btn-primary" || "btn-ghost"]}
          >
            All
          </button>
          <button
            phx-click="filter"
            phx-value-status="draft"
            class={["btn btn-sm", @current_filter == "draft" && "btn-primary" || "btn-ghost"]}
          >
            Drafts
          </button>
          <button
            phx-click="filter"
            phx-value-status="published"
            class={["btn btn-sm", @current_filter == "published" && "btn-primary" || "btn-ghost"]}
          >
            Published
          </button>
          <button
            phx-click="filter"
            phx-value-status="archived"
            class={["btn btn-sm", @current_filter == "archived" && "btn-primary" || "btn-ghost"]}
          >
            Archived
          </button>
        </div>

        <%!-- Lessons Grid --%>
        <%= if @lessons == [] do %>
          <div class="card bg-base-200">
            <div class="card-body text-center py-12">
              <.icon name="hero-book-open" class="w-16 h-16 mx-auto text-base-300 mb-4" />
              <h3 class="text-lg font-medium text-base-content">No lessons yet</h3>
              <p class="text-secondary mt-2 mb-4">Create your first custom reading lesson</p>
              <.link navigate={~p"/teacher/custom-lessons/new"} class="btn btn-primary">
                <.icon name="hero-plus" class="w-5 h-5 mr-2" /> Create Lesson
              </.link>
            </div>
          </div>
        <% else %>
          <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            <%= for lesson <- @lessons do %>
              <div class="card bg-base-100 border border-base-300 hover:shadow-lg transition-shadow">
                <div class="card-body">
                  <%!-- Header with status badge --%>
                  <div class="flex items-start justify-between mb-2">
                    <h3 class="card-title text-lg text-base-content line-clamp-1">{lesson.title}</h3>
                    <%= case lesson.status do %>
                      <% "draft" -> %>
                        <span class="badge badge-ghost badge-sm">Draft</span>
                      <% "published" -> %>
                        <span class="badge badge-success badge-sm">Published</span>
                      <% "archived" -> %>
                        <span class="badge badge-neutral badge-sm">Archived</span>
                    <% end %>
                  </div>

                  <%!-- Description --%>
                  <p class="text-secondary text-sm line-clamp-2 mb-4">
                    <%= lesson.description || "No description" %>
                  </p>

                  <%!-- Meta info --%>
                  <div class="flex items-center gap-4 text-sm text-secondary mb-4">
                    <span class="flex items-center gap-1">
                      <.icon name="hero-bookmark" class="w-4 h-4" />
                      {lesson.word_count} words
                    </span>
                    <%= if lesson.difficulty do %>
                      <span class="flex items-center gap-1">
                        <.icon name="hero-signal" class="w-4 h-4" />
                        N{lesson.difficulty}
                      </span>
                    <% end %>
                  </div>

                  <%!-- Actions --%>
                  <div class="card-actions justify-end">
                    <%= if lesson.status != "archived" do %>
                      <.link
                        navigate={~p"/teacher/custom-lessons/#{lesson.id}/edit"}
                        class="btn btn-ghost btn-sm"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </.link>
                      <%= if lesson.status == "published" do %>
                        <.link
                          navigate={~p"/teacher/custom-lessons/#{lesson.id}/publish"}
                          class="btn btn-ghost btn-sm"
                        >
                          <.icon name="hero-share" class="w-4 h-4" />
                        </.link>
                      <% end %>
                      <button
                        phx-click="archive"
                        phx-value-id={lesson.id}
                        data-confirm="Archive this lesson? It will no longer be available for new students."
                        class="btn btn-ghost btn-sm text-error"
                      >
                        <.icon name="hero-archive-box" class="w-4 h-4" />
                      </button>
                    <% else %>
                      <span class="text-sm text-secondary">Archived</span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
