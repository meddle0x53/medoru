defmodule MedoruWeb.Teacher.ClassroomLive.GenerateKanjiDrawingTest do
  @moduledoc """
  LiveView for generating a classroom kanji drawing test from vocabulary-lesson kanji.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Repo
  alias Medoru.Tests.ClassroomKanjiDrawingTestGenerator

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    classroom = Classrooms.get_classroom!(id)

    if classroom.teacher_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, gettext("You don't have permission to access this classroom."))
       |> push_navigate(to: ~p"/teacher/classrooms")}
    else
      lessons = Content.list_classroom_vocabulary_lessons_with_words(classroom.id)

      if lessons == [] do
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("This classroom has no vocabulary lessons to generate a kanji test from.")
         )
         |> push_navigate(to: ~p"/teacher/classrooms/#{classroom.id}?tab=tests")}
      else
        kanji_entries = build_kanji_entries(lessons)

        if kanji_entries == [] do
          {:ok,
           socket
           |> put_flash(
             :error,
             gettext("This classroom has no kanji with stroke data to practice.")
           )
           |> push_navigate(to: ~p"/teacher/classrooms/#{classroom.id}?tab=tests")}
        else
          selected_kanji_ids = MapSet.new(Enum.map(kanji_entries, & &1.kanji_id))

          {:ok,
           socket
           |> assign(:page_title, gettext("Generate Kanji Drawing Test"))
           |> assign(:classroom, classroom)
           |> assign(:lessons, lessons)
           |> assign(:kanji_entries, kanji_entries)
           |> assign(:selected_kanji_ids, selected_kanji_ids)
           |> assign(:title, default_title(classroom))
           |> assign(:due_date, nil)
           |> assign(:max_attempts, nil)
           |> assign(:error_message, nil)
           |> assign(:generating, false)}
        end
      end
    end
  end

  defp build_kanji_entries(lessons) do
    lessons
    |> Enum.flat_map(fn lesson ->
      lesson.custom_lesson_words
      |> Enum.sort_by(& &1.position)
      |> Enum.flat_map(fn clw ->
        kanji_list =
          case clw.word.word_kanjis do
            %Ecto.Association.NotLoaded{} -> []
            wk -> Enum.map(wk, & &1.kanji) |> Enum.reject(&is_nil/1)
          end

        Enum.map(kanji_list, fn kanji ->
          %{
            kanji_id: kanji.id,
            kanji: kanji,
            lesson_id: lesson.id,
            lesson_title: lesson.title
          }
        end)
      end)
    end)
    |> Enum.uniq_by(& &1.kanji_id)
    |> Enum.map(fn entry ->
      # Preload readings for display / generator use.
      %{entry | kanji: Repo.preload(entry.kanji, :kanji_readings)}
    end)
  end

  defp default_title(classroom) do
    "#{classroom.name} - Kanji Drawing Test"
  end

  defp all_kanji_selected?(selected_kanji_ids, kanji_entries) do
    MapSet.size(selected_kanji_ids) == length(kanji_entries) and kanji_entries != []
  end

  defp lesson_selected?(lesson, selected_kanji_ids, kanji_entries) do
    lesson_kanji_ids =
      kanji_entries
      |> Enum.filter(&(&1.lesson_id == lesson.id))
      |> Enum.map(& &1.kanji_id)

    selected_in_lesson = Enum.filter(lesson_kanji_ids, &MapSet.member?(selected_kanji_ids, &1))
    length(selected_in_lesson) == length(lesson_kanji_ids) and lesson_kanji_ids != []
  end

  @impl true
  def handle_event("toggle_select_all", _params, socket) do
    all_selected =
      all_kanji_selected?(
        socket.assigns.selected_kanji_ids,
        socket.assigns.kanji_entries
      )

    selected_kanji_ids =
      if all_selected do
        MapSet.new()
      else
        MapSet.new(Enum.map(socket.assigns.kanji_entries, & &1.kanji_id))
      end

    {:noreply,
     socket
     |> assign(:selected_kanji_ids, selected_kanji_ids)
     |> clear_error()}
  end

  @impl true
  def handle_event("toggle_lesson", %{"lesson_id" => lesson_id}, socket) do
    lesson_id = parse_uuid(lesson_id)

    lesson_kanji_ids =
      socket.assigns.kanji_entries
      |> Enum.filter(&(&1.lesson_id == lesson_id))
      |> Enum.map(& &1.kanji_id)
      |> MapSet.new()

    currently_selected =
      MapSet.intersection(socket.assigns.selected_kanji_ids, lesson_kanji_ids)

    selected_kanji_ids =
      if MapSet.size(currently_selected) == MapSet.size(lesson_kanji_ids) do
        MapSet.difference(socket.assigns.selected_kanji_ids, lesson_kanji_ids)
      else
        MapSet.union(socket.assigns.selected_kanji_ids, lesson_kanji_ids)
      end

    {:noreply,
     socket
     |> assign(:selected_kanji_ids, selected_kanji_ids)
     |> clear_error()}
  end

  @impl true
  def handle_event("toggle_kanji", %{"kanji_id" => kanji_id}, socket) do
    kanji_id = parse_uuid(kanji_id)

    selected_kanji_ids =
      if MapSet.member?(socket.assigns.selected_kanji_ids, kanji_id) do
        MapSet.delete(socket.assigns.selected_kanji_ids, kanji_id)
      else
        MapSet.put(socket.assigns.selected_kanji_ids, kanji_id)
      end

    {:noreply,
     socket
     |> assign(:selected_kanji_ids, selected_kanji_ids)
     |> clear_error()}
  end

  @impl true
  def handle_event("update_title", %{"title" => value}, socket) do
    {:noreply, assign(socket, :title, value)}
  end

  @impl true
  def handle_event("update_due_date", %{"due_date" => value}, socket) do
    due_date =
      case value do
        "" ->
          nil

        date_string ->
          case DateTime.from_iso8601(date_string <> ":00Z") do
            {:ok, dt, _} -> dt
            _ -> nil
          end
      end

    {:noreply, assign(socket, :due_date, due_date)}
  end

  @impl true
  def handle_event("update_max_attempts", %{"max_attempts" => value}, socket) do
    max_attempts =
      case Integer.parse(value) do
        {n, _} when n >= 1 and n <= 10 -> n
        _ -> nil
      end

    {:noreply, assign(socket, :max_attempts, max_attempts)}
  end

  @impl true
  def handle_event("generate_test", params, socket) do
    classroom = socket.assigns.classroom
    kanji_entries = socket.assigns.kanji_entries

    selected_kanji_ids =
      params
      |> Map.get("kanji_ids", [])
      |> List.wrap()
      |> Enum.map(&parse_uuid/1)
      |> MapSet.new()

    selected_kanji =
      kanji_entries
      |> Enum.filter(&MapSet.member?(selected_kanji_ids, &1.kanji_id))
      |> Enum.map(& &1.kanji)

    title = params["title"] || socket.assigns.title

    socket = assign(socket, :generating, true)

    case ClassroomKanjiDrawingTestGenerator.generate_test(
           classroom,
           selected_kanji,
           socket.assigns.current_scope.current_user.id,
           title: title,
           due_date: socket.assigns.due_date,
           max_attempts: socket.assigns.max_attempts
         ) do
      {:ok, _test} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Kanji drawing test generated and published successfully!"))
         |> push_navigate(to: ~p"/teacher/classrooms/#{classroom.id}?tab=tests")}

      {:error, :no_kanji_selected} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Please select at least one kanji."))
         |> assign(:generating, false)}

      {:error, :no_drawable_kanji} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Selected kanji do not have stroke data and cannot be drawn.")
         )
         |> assign(:generating, false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Failed to generate test: %{reason}", reason: inspect(reason))
         )
         |> assign(:generating, false)}
    end
  end

  defp parse_uuid(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> uuid
      :error -> value
    end
  end

  defp clear_error(socket) do
    assign(socket, :error_message, nil)
  end

  defp format_meanings(kanji) do
    kanji.meanings
    |> Enum.take(2)
    |> Enum.join(" / ")
  end

  defp first_reading(kanji, type) do
    case Enum.find(kanji.kanji_readings || [], &(&1.reading_type == type)) do
      nil -> gettext("—")
      reading -> reading.reading
    end
  end

  defp has_strokes?(kanji) do
    case kanji.stroke_data do
      %{"strokes" => strokes} when is_list(strokes) and strokes != [] -> true
      _ -> false
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/classrooms/#{@classroom.id}?tab=tests"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Classroom Tests")}
          </.link>
          <h1 class="text-2xl md:text-3xl font-bold text-base-content">
            {gettext("Generate Kanji Drawing Test")}
          </h1>
          <p class="text-secondary mt-2">
            {gettext("Create a drawing test from the kanji in this classroom's vocabulary lessons.")}
          </p>
        </div>

        <.form
          for={%{}}
          phx-submit="generate_test"
          class="space-y-6"
          id="generate-kanji-test-form"
        >
          <%!-- Title --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <label class="label" for="test-title">
                <span class="label-text font-medium">{gettext("Test Title")}</span>
              </label>
              <input
                type="text"
                id="test-title"
                name="title"
                value={@title}
                phx-change="update_title"
                class="input input-bordered w-full"
                maxlength="255"
              />
            </div>
          </div>

          <%!-- Kanji Pool --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <div class="flex items-center gap-3">
                  <input
                    type="checkbox"
                    id="select-all-kanji"
                    checked={all_kanji_selected?(@selected_kanji_ids, @kanji_entries)}
                    class="checkbox checkbox-primary"
                    phx-click="toggle_select_all"
                  />
                  <label for="select-all-kanji" class="font-medium cursor-pointer">
                    {gettext("Select All Kanji")}
                  </label>
                </div>
                <span class="text-sm text-secondary">
                  {MapSet.size(@selected_kanji_ids)} {gettext("of")} {length(@kanji_entries)} {gettext(
                    "kanji selected"
                  )}
                </span>
              </div>

              <div class="space-y-4">
                <%= for lesson <- @lessons do %>
                  <% lesson_kanji = Enum.filter(@kanji_entries, &(&1.lesson_id == lesson.id)) %>
                  <%= if lesson_kanji != [] do %>
                    <div class="border border-base-300 rounded-lg overflow-hidden">
                      <div class="bg-base-200/50 px-4 py-3 flex items-center justify-between">
                        <div class="flex items-center gap-3">
                          <input
                            type="checkbox"
                            id={"lesson-#{lesson.id}"}
                            checked={lesson_selected?(lesson, @selected_kanji_ids, @kanji_entries)}
                            class="checkbox checkbox-primary"
                            phx-click="toggle_lesson"
                            phx-value-lesson_id={lesson.id}
                          />
                          <label for={"lesson-#{lesson.id}"} class="font-medium cursor-pointer">
                            {lesson.title}
                          </label>
                        </div>
                        <span class="text-xs text-secondary">
                          {length(lesson_kanji)} {gettext("kanji")}
                        </span>
                      </div>
                      <div class="divide-y divide-base-200">
                        <%= for entry <- lesson_kanji |> Enum.sort_by(& &1.kanji.character) do %>
                          <div class="px-4 py-3 flex items-center gap-4 hover:bg-base-100">
                            <input
                              type="checkbox"
                              id={"kanji-#{entry.kanji_id}"}
                              name="kanji_ids[]"
                              value={entry.kanji_id}
                              checked={MapSet.member?(@selected_kanji_ids, entry.kanji_id)}
                              class="checkbox checkbox-sm checkbox-primary"
                              phx-click="toggle_kanji"
                              phx-value-kanji_id={entry.kanji_id}
                            />
                            <label for={"kanji-#{entry.kanji_id}"} class="flex-1 cursor-pointer">
                              <div class="flex flex-wrap items-center gap-x-4 gap-y-1">
                                <span class="text-3xl font-jp font-medium min-w-[3rem] text-center">
                                  {entry.kanji.character}
                                </span>
                                <span class="text-sm text-base-content/80">
                                  {format_meanings(entry.kanji)}
                                </span>
                                <span class="text-sm text-secondary">
                                  {gettext("On")}: {first_reading(entry.kanji, :on)} • {gettext("Kun")}: {first_reading(
                                    entry.kanji,
                                    :kun
                                  )}
                                </span>
                                <span class="text-xs text-secondary bg-base-200 px-2 py-1 rounded">
                                  {entry.kanji.stroke_count} {gettext("strokes")}
                                </span>
                                <%= if not has_strokes?(entry.kanji) do %>
                                  <span class="text-xs text-error">
                                    {gettext("No stroke data")}
                                  </span>
                                <% end %>
                              </div>
                            </label>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Options --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-base-content mb-4">
                <.icon name="hero-adjustments-horizontal" class="w-5 h-5" /> {gettext("Test Options")}
              </h2>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <%!-- Due date --%>
                <div>
                  <label class="label">
                    <span class="label-text font-medium">{gettext("Due Date (optional)")}</span>
                  </label>
                  <input
                    type="datetime-local"
                    name="due_date"
                    phx-change="update_due_date"
                    class="input input-bordered w-full"
                  />
                  <p class="text-xs text-secondary mt-1">
                    {gettext("Students will see this due date on the test.")}
                  </p>
                </div>

                <%!-- Max attempts --%>
                <div>
                  <label class="label">
                    <span class="label-text font-medium">
                      {gettext("Max Attempts (optional)")}
                    </span>
                  </label>
                  <input
                    type="number"
                    name="max_attempts"
                    min="1"
                    max="10"
                    placeholder={gettext("Unlimited")}
                    phx-change="update_max_attempts"
                    class="input input-bordered w-full"
                  />
                  <p class="text-xs text-secondary mt-1">
                    {gettext("Maximum number of times a student can take this test (1–10).")}
                  </p>
                </div>
              </div>

              <%= if @error_message do %>
                <div class="mt-4 p-4 bg-error/10 rounded-lg">
                  <div class="flex items-start gap-3">
                    <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-error mt-0.5" />
                    <div class="text-sm text-error-content">
                      <p>{@error_message}</p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Actions --%>
          <div class="flex flex-col sm:flex-row gap-3 pt-4">
            <button
              type="submit"
              disabled={@generating or MapSet.size(@selected_kanji_ids) == 0}
              class="flex-1 px-6 py-3 bg-primary hover:bg-primary/90 disabled:bg-base-300 disabled:cursor-not-allowed text-primary-content rounded-lg font-medium transition-colors"
            >
              <%= if @generating do %>
                <span class="loading loading-spinner loading-sm mr-2"></span>
                {gettext("Generating...")}
              <% else %>
                <.icon name="hero-paint-brush" class="w-5 h-5 mr-2" /> {gettext("Generate Test")}
              <% end %>
            </button>
            <.link
              navigate={~p"/teacher/classrooms/#{@classroom.id}?tab=tests"}
              class="px-6 py-3 bg-base-200 hover:bg-base-300 text-base-content rounded-lg font-medium text-center transition-colors"
            >
              {gettext("Cancel")}
            </.link>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
