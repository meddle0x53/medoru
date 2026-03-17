defmodule MedoruWeb.ClassroomLive.CustomLesson do
  @moduledoc """
  LiveView for students to study a custom lesson.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.Content

  @impl true
  def mount(%{"id" => classroom_id, "lesson_id" => lesson_id}, session, socket) do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user
    practice = session["practice"] == true

    # Verify user is an approved member
    case Classrooms.get_user_membership(classroom_id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not a member of this classroom."))
         |> push_navigate(to: ~p"/classrooms")}

      membership ->
        if membership.status != :approved do
          {:ok,
           socket
           |> put_flash(:error, gettext("Your membership is pending approval."))
           |> push_navigate(to: ~p"/classrooms/#{classroom_id}")}
        else
          load_lesson(socket, classroom_id, lesson_id, user, locale, practice)
        end
    end
  end

  defp load_lesson(socket, classroom_id, lesson_id, user, locale, practice \\ false) do
    classroom = Classrooms.get_classroom!(classroom_id)
    lesson = Content.get_custom_lesson_with_words!(lesson_id)

    # Verify lesson is published to this classroom
    published_lessons = Content.list_classroom_custom_lessons(classroom_id)
    lesson_ids = Enum.map(published_lessons, fn pc -> pc.custom_lesson_id end)

    if lesson_id not in lesson_ids do
      {:ok,
       socket
       |> put_flash(:error, gettext("This lesson is not available in this classroom."))
       |> push_navigate(to: ~p"/classrooms/#{classroom_id}")}
    else
      # Get existing progress (don't create new one in practice mode)
      progress = Classrooms.get_custom_lesson_progress(classroom_id, user.id, lesson_id)
      is_completed = progress && progress.status == "completed"

      # In practice mode, we can always access the lesson
      # For new lessons, create progress
      progress =
        if is_nil(progress) and not practice do
          {:ok, prog} = Classrooms.start_custom_lesson(classroom_id, user.id, lesson_id)
          prog
        else
          progress
        end

      lesson_words = Content.list_lesson_words(lesson_id)
      current_index = 0
      current_word = Enum.at(lesson_words, current_index)

      {:ok,
       socket
       |> assign(:locale, locale)
       |> assign(:classroom, classroom)
       |> assign(:lesson, lesson)
       |> assign(:lesson_words, lesson_words)
       |> assign(:progress, progress)
       |> assign(:is_completed, is_completed)
       |> assign(:practice, practice)
       |> assign(:current_index, current_index)
       |> assign(:current_word, current_word)
       |> assign(:total_words, length(lesson_words))}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(
       socket,
       :page_title,
       Content.get_localized_lesson_title(socket.assigns.lesson, socket.assigns.locale)
     )}
  end

  @impl true
  def handle_event("next", _params, socket) do
    current_index = socket.assigns.current_index
    total = socket.assigns.total_words

    if current_index < total - 1 do
      next_index = current_index + 1

      {:noreply,
       socket
       |> assign(:current_index, next_index)
       |> assign(:current_word, Enum.at(socket.assigns.lesson_words, next_index))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev", _params, socket) do
    current_index = socket.assigns.current_index

    if current_index > 0 do
      prev_index = current_index - 1

      {:noreply,
       socket
       |> assign(:current_index, prev_index)
       |> assign(:current_word, Enum.at(socket.assigns.lesson_words, prev_index))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("complete", _params, socket) do
    classroom_id = socket.assigns.classroom.id
    user = socket.assigns.current_scope.current_user
    lesson_id = socket.assigns.lesson.id
    lesson = socket.assigns.lesson
    practice = socket.assigns.practice

    # In practice mode, just show completion without awarding points
    if practice do
      {:noreply,
       socket
       |> push_navigate(
         to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}/complete?practice=true"
       )}
    else
      # Check if test is required
      if lesson.requires_test and lesson.test_id do
        # Check if test is already completed
        case Medoru.Tests.get_completed_test_session(user.id, lesson.test_id) do
          nil ->
            # Redirect to test
            {:noreply,
             socket
             |> push_navigate(to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}/test")}

          _session ->
            # Test already completed, show already completed message
            {:noreply,
             socket
             |> put_flash(:info, gettext("You've already completed this lesson. Use Practice Mode to review."))
             |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=lessons")}
        end
      else
        # No test required, mark lesson complete
        complete_lesson(socket, classroom_id, user.id, lesson_id)
      end
    end
  end

  defp complete_lesson(socket, classroom_id, user_id, lesson_id) do
    case Classrooms.complete_custom_lesson(classroom_id, user_id, lesson_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> push_navigate(
           to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}/complete"
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to complete lesson."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-6">
          <.link
            navigate={~p"/classrooms/#{@classroom.id}?tab=lessons"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Lessons")}
          </.link>
          <div class="flex items-center justify-between">
            <h1 class="text-2xl font-bold text-base-content">
              {Content.get_localized_lesson_title(@lesson, @locale)}
            </h1>
            <span class="text-secondary">
              {@current_index + 1} / {@total_words}
            </span>
          </div>
          <%= if @lesson.description do %>
            <p class="text-secondary mt-2">{@lesson.description}</p>
          <% end %>
        </div>

        <%!-- Progress Bar --%>
        <div class="w-full bg-base-200 rounded-full h-2 mb-8">
          <div
            class="bg-primary h-2 rounded-full transition-all"
            style={"width: #{((@current_index + 1) / @total_words) * 100}%"}
          />
        </div>

        <%!-- Word Card --%>
        <%= if @current_word do %>
          <div class="card bg-base-100 border border-base-300 shadow-lg">
            <div class="card-body text-center py-12">
              <%!-- Japanese Text --%>
              <.link
                navigate={~p"/words/#{@current_word.word.id}"}
                class="text-6xl font-jp mb-4 hover:text-primary transition-colors inline-block"
                title="View word details"
              >
                {@current_word.word.text}
              </.link>

              <%!-- Reading --%>
              <div class="text-xl text-secondary mb-6">{@current_word.word.reading}</div>

              <%!-- Meaning --%>
              <div class="text-2xl text-base-content mb-8">
                {@current_word.custom_meaning ||
                  Content.get_localized_meaning(@current_word.word, @locale)}
              </div>

              <%!-- {gettext("Examples")} --%>
              <%= if @current_word.examples != [] do %>
                <div class="border-t border-base-200 pt-6 mt-6">
                  <h3 class="text-sm font-medium text-secondary mb-4">Examples</h3>
                  <div class="space-y-2">
                    <%= for example <- @current_word.examples do %>
                      <p class="text-lg font-jp">{example}</p>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Navigation --%>
          <div class="flex justify-between items-center mt-8">
            <button
              phx-click="prev"
              class={["btn btn-ghost", @current_index == 0 && "invisible"]}
            >
              <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> Previous
            </button>

            <%= if @current_index < @total_words - 1 do %>
              <button phx-click="next" class="btn btn-primary">
                Next <.icon name="hero-arrow-right" class="w-5 h-5 ml-2" />
              </button>
            <% else %>
              <%= cond do %>
                <% @practice -> %>
                  <%!-- Practice mode: show review complete button --%>
                  <button
                    phx-click="complete"
                    class="btn btn-primary"
                  >
                    <.icon name="hero-check" class="w-5 h-5 mr-2" /> {gettext("Finish Review")}
                  </button>
                <% @is_completed -> %>
                  <%!-- Already completed: show practice mode button --%>
                  <%= if @lesson.requires_test and @lesson.test_id do %>
                    <.link
                      navigate={~p"/classrooms/#{@classroom.id}/custom-lessons/#{@lesson.id}/test?practice=true"}
                      class="btn btn-secondary"
                    >
                      <.icon name="hero-arrow-path" class="w-5 h-5 mr-2" /> {gettext("Practice Test")}
                    </.link>
                  <% end %>
                  <.link
                    navigate={~p"/classrooms/#{@classroom.id}"}
                    class="btn btn-ghost ml-2"
                  >
                    {gettext("Back to Classroom")}
                  </.link>
                <% @lesson.requires_test and @lesson.test_id -> %>
                  <%!-- First time: take test --%>
                  <button
                    phx-click="complete"
                    class="btn btn-success"
                  >
                    <.icon name="hero-pencil" class="w-5 h-5 mr-2" /> {gettext("Take Test")}
                  </button>
                <% true -> %>
                  <%!-- First time: mark complete --%>
                  <button
                    phx-click="complete"
                    data-confirm={gettext("Mark this lesson as complete?")}
                    class="btn btn-success"
                  >
                    <.icon name="hero-check" class="w-5 h-5 mr-2" /> {gettext("Mark Complete")}
                  </button>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
