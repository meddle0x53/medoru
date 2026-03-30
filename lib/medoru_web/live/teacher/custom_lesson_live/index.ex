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
       |> put_flash(:error, gettext("Only teachers can access this page."))
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
     |> assign(:page_title, gettext("My Custom Lessons"))
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
      {:noreply, put_flash(socket, :error, gettext("You can only archive your own lessons."))}
    else
      case Content.archive_custom_lesson(lesson) do
        {:ok, _} ->
          lessons =
            case socket.assigns.current_filter do
              "all" -> Content.list_teacher_custom_lessons(user.id)
              status -> Content.list_teacher_custom_lessons(user.id, status: status)
            end

          {:noreply,
           socket
           |> put_flash(:info, gettext("Lesson archived successfully."))
           |> assign(:lessons, lessons)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to archive lesson."))}
      end
    end
  end

  @impl true
  def handle_event("unarchive", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.current_user
    lesson = Content.get_custom_lesson!(id)

    # Verify ownership
    if lesson.creator_id != user.id do
      {:noreply, put_flash(socket, :error, gettext("You can only unarchive your own lessons."))}
    else
      case Content.unarchive_custom_lesson(lesson) do
        {:ok, _} ->
          lessons =
            case socket.assigns.current_filter do
              "all" -> Content.list_teacher_custom_lessons(user.id)
              status -> Content.list_teacher_custom_lessons(user.id, status: status)
            end

          {:noreply,
           socket
           |> put_flash(:info, gettext("Lesson restored successfully."))
           |> assign(:lessons, lessons)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to restore lesson."))}
      end
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.current_user
    lesson = Content.get_custom_lesson!(id)

    # Verify ownership
    if lesson.creator_id != user.id do
      {:noreply, put_flash(socket, :error, gettext("You can only delete your own lessons."))}
    else
      # Only archived lessons can be deleted
      if lesson.status != "archived" do
        {:noreply, put_flash(socket, :error, gettext("Only archived lessons can be deleted."))}
      else
        case Content.delete_custom_lesson(lesson) do
          {:ok, _} ->
            lessons =
              case socket.assigns.current_filter do
                "all" -> Content.list_teacher_custom_lessons(user.id)
                status -> Content.list_teacher_custom_lessons(user.id, status: status)
              end

            {:noreply,
             socket
             |> put_flash(:info, gettext("Lesson deleted permanently."))
             |> assign(:lessons, lessons)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to delete lesson."))}
        end
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
          <div>
            <h1 class="text-2xl sm:text-3xl font-bold text-base-content">
              {gettext("My Custom Lessons")}
            </h1>
            <p class="text-secondary mt-1 text-sm sm:text-base">
              {gettext("Create and manage reading lessons for your classrooms")}
            </p>
          </div>
          <div class="flex gap-2">
            <.link navigate={~p"/teacher/custom-lessons/new"} class="btn btn-primary w-full sm:w-auto">
              <.icon name="hero-plus" class="w-5 h-5 mr-2" /> {gettext("New Vocabulary Lesson")}
            </.link>
            <.link
              navigate={~p"/teacher/grammar-lessons/new"}
              class="btn btn-secondary w-full sm:w-auto"
            >
              <.icon name="hero-plus" class="w-5 h-5 mr-2" /> {gettext("New Grammar Lesson")}
            </.link>
          </div>
        </div>

        <%!-- Filters --%>
        <div class="flex flex-wrap gap-2 mb-6">
          <button
            phx-click="filter"
            phx-value-status="all"
            class={["btn btn-sm", (@current_filter == "all" && "btn-primary") || "btn-ghost"]}
          >
            {gettext("All")}
          </button>
          <button
            phx-click="filter"
            phx-value-status="draft"
            class={["btn btn-sm", (@current_filter == "draft" && "btn-primary") || "btn-ghost"]}
          >
            {gettext("Drafts")}
          </button>
          <button
            phx-click="filter"
            phx-value-status="published"
            class={["btn btn-sm", (@current_filter == "published" && "btn-primary") || "btn-ghost"]}
          >
            {gettext("Published")}
          </button>
          <button
            phx-click="filter"
            phx-value-status="archived"
            class={["btn btn-sm", (@current_filter == "archived" && "btn-primary") || "btn-ghost"]}
          >
            {gettext("Archived")}
          </button>
        </div>

        <%!-- Lessons Grid --%>
        <%= if @lessons == [] do %>
          <div class="card bg-base-200">
            <div class="card-body text-center py-12">
              <.icon name="hero-book-open" class="w-16 h-16 mx-auto text-base-300 mb-4" />
              <h3 class="text-lg font-medium text-base-content">{gettext("No lessons yet")}</h3>
              <p class="text-secondary mt-2 mb-4">
                {gettext("Create your first custom reading lesson")}
              </p>
              <div class="flex flex-col sm:flex-row gap-2 justify-center">
                <.link navigate={~p"/teacher/custom-lessons/new"} class="btn btn-primary">
                  <.icon name="hero-plus" class="w-5 h-5 mr-2" /> {gettext("Create Vocabulary Lesson")}
                </.link>
                <.link navigate={~p"/teacher/grammar-lessons/new"} class="btn btn-secondary">
                  <.icon name="hero-plus" class="w-5 h-5 mr-2" /> {gettext("Create Grammar Lesson")}
                </.link>
              </div>
            </div>
          </div>
        <% else %>
          <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            <%= for lesson <- @lessons do %>
              <% # Determine card styling based on lesson type
              {type_badge_class, type_label, type_icon} =
                case lesson.lesson_subtype do
                  "grammar" -> {"badge-secondary", gettext("Grammar"), "hero-beaker"}
                  _ -> {"badge-primary", gettext("Vocabulary"), "hero-bookmark"}
                end

              # Border color based on type
              card_border_class =
                case lesson.lesson_subtype do
                  "grammar" -> "border-secondary/30 hover:border-secondary/60"
                  _ -> "border-primary/30 hover:border-primary/60"
                end %>
              <div class={[
                "card bg-base-100 border hover:shadow-lg transition-all flex flex-col h-full",
                card_border_class
              ]}>
                <div class="card-body flex flex-col flex-1">
                  <%!-- Header with type and status badges --%>
                  <div class="flex flex-col gap-2 mb-2">
                    <div class="flex items-center justify-between">
                      <span class={["badge badge-sm", type_badge_class]}>
                        <.icon name={type_icon} class="w-3 h-3 mr-1" />
                        {type_label}
                      </span>
                      <%= case lesson.status do %>
                        <% "draft" -> %>
                          <span class="badge badge-ghost badge-sm">{gettext("Draft")}</span>
                        <% "published" -> %>
                          <span class="badge badge-success badge-sm">{gettext("Published")}</span>
                        <% "archived" -> %>
                          <span class="badge badge-neutral badge-sm">{gettext("Archived")}</span>
                      <% end %>
                    </div>
                    <h3 class="card-title text-base sm:text-lg text-base-content line-clamp-1">
                      {lesson.title}
                    </h3>
                  </div>

                  <%!-- Description --%>
                  <p class="text-secondary text-sm line-clamp-2 mb-4">
                    {lesson.description || gettext("No description")}
                  </p>

                  <%!-- Meta info --%>
                  <div class="flex items-center gap-4 text-sm text-secondary mb-4">
                    <span class="flex items-center gap-1">
                      <%= if lesson.lesson_subtype == "grammar" do %>
                        <.icon name="hero-beaker" class="w-4 h-4" />
                        {lesson.word_count} {gettext("steps")}
                      <% else %>
                        <.icon name="hero-bookmark" class="w-4 h-4" />
                        {lesson.word_count} {gettext("words")}
                      <% end %>
                    </span>
                    <%= if lesson.difficulty do %>
                      <span class="flex items-center gap-1">
                        <.icon name="hero-signal" class="w-4 h-4" /> N{lesson.difficulty}
                      </span>
                    <% end %>
                  </div>

                  <%!-- Actions --%>
                  <div class="card-actions justify-start sm:justify-end mt-auto pt-2">
                    <%= if lesson.status != "archived" do %>
                      <% edit_path =
                        if lesson.lesson_subtype == "grammar",
                          do: ~p"/teacher/grammar-lessons/#{lesson.id}/edit",
                          else: ~p"/teacher/custom-lessons/#{lesson.id}/edit" %>
                      <.link
                        navigate={edit_path}
                        class="btn btn-ghost btn-sm flex-1 sm:flex-none"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4 sm:mr-1" />
                        <span class="hidden sm:inline">{gettext("Edit")}</span>
                      </.link>
                      <%= if lesson.status == "published" do %>
                        <.link
                          navigate={~p"/teacher/custom-lessons/#{lesson.id}/publish"}
                          class="btn btn-ghost btn-sm flex-1 sm:flex-none"
                        >
                          <.icon name="hero-share" class="w-4 h-4 sm:mr-1" />
                          <span class="hidden sm:inline">{gettext("Share")}</span>
                        </.link>
                      <% end %>
                      <button
                        phx-click="archive"
                        phx-value-id={lesson.id}
                        data-confirm={
                          gettext(
                            "Archive this lesson? It will no longer be available for new students."
                          )
                        }
                        class="btn btn-ghost btn-sm text-error flex-1 sm:flex-none"
                      >
                        <.icon name="hero-archive-box" class="w-4 h-4 sm:mr-1" />
                        <span class="hidden sm:inline">{gettext("Archive")}</span>
                      </button>
                    <% else %>
                      <button
                        phx-click="unarchive"
                        phx-value-id={lesson.id}
                        class="btn btn-ghost btn-sm text-success flex-1 sm:flex-none"
                      >
                        <.icon name="hero-arrow-uturn-left" class="w-4 h-4 sm:mr-1" />
                        <span class="hidden sm:inline">{gettext("Restore")}</span>
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-id={lesson.id}
                        data-confirm={
                          gettext("Permanently delete this lesson? This action cannot be undone.")
                        }
                        class="btn btn-ghost btn-sm text-error flex-1 sm:flex-none"
                      >
                        <.icon name="hero-trash" class="w-4 h-4 sm:mr-1" />
                        <span class="hidden sm:inline">{gettext("Delete")}</span>
                      </button>
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
