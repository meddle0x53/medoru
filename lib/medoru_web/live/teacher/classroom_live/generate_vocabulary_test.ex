defmodule MedoruWeb.Teacher.ClassroomLive.GenerateVocabularyTest do
  @moduledoc """
  LiveView for generating a classroom vocabulary test from published lesson words.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Tests.ClassroomVocabularyTestGenerator

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
           gettext("This classroom has no vocabulary lessons to generate a test from.")
         )
         |> push_navigate(to: ~p"/teacher/classrooms/#{classroom.id}?tab=tests")}
      else
        word_entries = build_word_entries(lessons)
        selected_word_ids = MapSet.new(Enum.map(word_entries, & &1.word_id))

        {:ok,
         socket
         |> assign(:page_title, gettext("Generate Vocabulary Test"))
         |> assign(:classroom, classroom)
         |> assign(:lessons, lessons)
         |> assign(:word_entries, word_entries)
         |> assign(:selected_word_ids, selected_word_ids)
         |> assign(:selected_types, ["word_to_meaning", "word_to_reading"])
         |> assign(:max_times_per_word, 1)
         |> assign(:total_questions, length(word_entries))
         |> assign(:title, default_title(classroom))
         |> assign(:due_date, nil)
         |> assign(:max_attempts, nil)
         |> assign(:distractor_pool, :selected)
         |> assign(:error_message, nil)
         |> assign(:generating, false)}
      end
    end
  end

  defp build_word_entries(lessons) do
    lessons
    |> Enum.flat_map(fn lesson ->
      lesson.custom_lesson_words
      |> Enum.sort_by(& &1.position)
      |> Enum.map(fn clw ->
        %{
          word_id: clw.word.id,
          word: clw.word,
          lesson_id: lesson.id,
          lesson_title: lesson.title
        }
      end)
    end)
    |> Enum.uniq_by(& &1.word_id)
  end

  defp default_title(classroom) do
    "#{classroom.name} - Vocabulary Test"
  end

  defp max_possible_questions(selected_word_ids, max_times_per_word) do
    MapSet.size(selected_word_ids) * max_times_per_word
  end

  @impl true
  def handle_event("toggle_type", %{"type" => type}, socket) do
    current_types = socket.assigns.selected_types

    new_types =
      if type in current_types do
        if length(current_types) > 1 do
          List.delete(current_types, type)
        else
          current_types
        end
      else
        [type | current_types]
      end

    {:noreply, assign(socket, :selected_types, new_types)}
  end

  @impl true
  def handle_event("toggle_select_all", _params, socket) do
    all_selected =
      all_words_selected?(socket.assigns.selected_word_ids, socket.assigns.word_entries)

    selected_word_ids =
      if all_selected do
        MapSet.new()
      else
        MapSet.new(Enum.map(socket.assigns.word_entries, & &1.word_id))
      end

    max = max_possible_questions(selected_word_ids, socket.assigns.max_times_per_word)

    {:noreply,
     socket
     |> assign(:selected_word_ids, selected_word_ids)
     |> assign(:total_questions, min(socket.assigns.total_questions, max))
     |> clear_error()}
  end

  @impl true
  def handle_event("toggle_lesson", %{"lesson_id" => lesson_id}, socket) do
    lesson_id = parse_uuid(lesson_id)

    lesson_word_ids =
      socket.assigns.word_entries
      |> Enum.filter(&(&1.lesson_id == lesson_id))
      |> Enum.map(& &1.word_id)
      |> MapSet.new()

    # Toggle: if all words of the lesson are selected, deselect; otherwise select all.
    currently_selected = MapSet.intersection(socket.assigns.selected_word_ids, lesson_word_ids)

    selected_word_ids =
      if MapSet.size(currently_selected) == MapSet.size(lesson_word_ids) do
        MapSet.difference(socket.assigns.selected_word_ids, lesson_word_ids)
      else
        MapSet.union(socket.assigns.selected_word_ids, lesson_word_ids)
      end

    max = max_possible_questions(selected_word_ids, socket.assigns.max_times_per_word)

    {:noreply,
     socket
     |> assign(:selected_word_ids, selected_word_ids)
     |> assign(:total_questions, min(socket.assigns.total_questions, max))
     |> clear_error()}
  end

  @impl true
  def handle_event("toggle_word", %{"word_id" => word_id}, socket) do
    word_id = parse_uuid(word_id)

    selected_word_ids =
      if MapSet.member?(socket.assigns.selected_word_ids, word_id) do
        MapSet.delete(socket.assigns.selected_word_ids, word_id)
      else
        MapSet.put(socket.assigns.selected_word_ids, word_id)
      end

    max = max_possible_questions(selected_word_ids, socket.assigns.max_times_per_word)

    {:noreply,
     socket
     |> assign(:selected_word_ids, selected_word_ids)
     |> assign(:total_questions, min(socket.assigns.total_questions, max))
     |> clear_error()}
  end

  @impl true
  def handle_event("set_max_times", %{"max_times_per_word" => value}, socket) do
    case Integer.parse(value) do
      {n, _} when n in 1..3 ->
        selected_word_ids = socket.assigns.selected_word_ids
        max = max_possible_questions(selected_word_ids, n)

        {:noreply,
         socket
         |> assign(:max_times_per_word, n)
         |> assign(:total_questions, min(socket.assigns.total_questions, max))
         |> clear_error()}

      _ ->
        {:noreply,
         socket
         |> assign_error(gettext("Max times per word must be between 1 and 3."))}
    end
  end

  @impl true
  def handle_event("set_total_questions", %{"total_questions" => value}, socket) do
    case Integer.parse(value) do
      {n, _} when n > 0 ->
        max =
          max_possible_questions(
            socket.assigns.selected_word_ids,
            socket.assigns.max_times_per_word
          )

        if n > max do
          {:noreply,
           socket
           |> assign(:total_questions, max)
           |> assign_error(gettext("Number of questions cannot exceed %{max}.", max: max))}
        else
          {:noreply,
           socket
           |> assign(:total_questions, n)
           |> clear_error()}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_title", %{"title" => value}, socket) do
    {:noreply, assign(socket, :title, value)}
  end

  @impl true
  def handle_event("update_due_date", %{"value" => value}, socket) do
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
  def handle_event("update_max_attempts", %{"value" => value}, socket) do
    max_attempts =
      case Integer.parse(value) do
        {n, _} when n >= 1 and n <= 10 -> n
        _ -> nil
      end

    {:noreply, assign(socket, :max_attempts, max_attempts)}
  end

  @impl true
  def handle_event("update_distractor_pool", %{"distractor_pool" => value}, socket) do
    pool =
      case value do
        "classroom" -> :classroom
        _ -> :selected
      end

    {:noreply, assign(socket, :distractor_pool, pool)}
  end

  @impl true
  def handle_event("generate_test", params, socket) do
    classroom = socket.assigns.classroom
    word_entries = socket.assigns.word_entries

    # Read the actual checked word IDs from the form submission so excluded
    # words are never used even if a toggle event was dropped.
    selected_word_ids =
      params
      |> Map.get("word_ids", [])
      |> List.wrap()
      |> Enum.map(&parse_uuid/1)
      |> MapSet.new()

    selected_words =
      word_entries
      |> Enum.filter(&MapSet.member?(selected_word_ids, &1.word_id))
      |> Enum.map(& &1.word)

    step_types =
      params
      |> Map.get("step_types", socket.assigns.selected_types)
      |> List.wrap()
      |> Enum.map(&String.to_atom/1)

    max_times_per_word =
      case parse_bounded_integer(params["max_times_per_word"], 1, 3) do
        {:ok, n} -> n
        :error -> socket.assigns.max_times_per_word
      end

    total_questions =
      case parse_positive_integer(params["total_questions"]) do
        {:ok, n} -> n
        :error -> socket.assigns.total_questions
      end

    max_possible = max_possible_questions(selected_word_ids, max_times_per_word)
    total_questions = min(total_questions, max_possible)

    title = params["title"] || socket.assigns.title

    distractor_pool =
      case params["distractor_pool"] do
        "classroom" -> :classroom
        _ -> :selected
      end

    all_classroom_words = Enum.map(word_entries, & &1.word)

    socket = assign(socket, :generating, true)

    case ClassroomVocabularyTestGenerator.generate_test(
           classroom,
           selected_words,
           socket.assigns.current_scope.current_user.id,
           step_types: step_types,
           max_times_per_word: max_times_per_word,
           total_questions: total_questions,
           title: title,
           distractor_pool: distractor_pool,
           all_classroom_words: all_classroom_words,
           due_date: socket.assigns.due_date,
           max_attempts: socket.assigns.max_attempts
         ) do
      {:ok, _test} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Vocabulary test generated and published successfully!"))
         |> push_navigate(to: ~p"/teacher/classrooms/#{classroom.id}?tab=tests")}

      {:error, :no_words_selected} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Please select at least one word."))
         |> assign(:generating, false)}

      {:error, :no_questions_possible} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("No questions could be generated with the selected options.")
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

  defp parse_bounded_integer(value, min, max) do
    case Integer.parse(to_string(value)) do
      {n, _} when n >= min and n <= max -> {:ok, n}
      _ -> :error
    end
  end

  defp parse_positive_integer(value) do
    case Integer.parse(to_string(value)) do
      {n, _} when n > 0 -> {:ok, n}
      _ -> :error
    end
  end

  defp assign_error(socket, message) do
    assign(socket, :error_message, message)
  end

  defp clear_error(socket) do
    assign(socket, :error_message, nil)
  end

  defp step_type_card_class(selected) do
    if selected do
      "border-primary bg-primary/5 ring-1 ring-primary"
    else
      "border-base-300 hover:border-primary/30 hover:bg-base-100"
    end
  end

  defp lesson_selected?(lesson, selected_word_ids) do
    lesson_word_ids = Enum.map(lesson.custom_lesson_words, & &1.word_id)
    selected_in_lesson = Enum.filter(lesson_word_ids, &MapSet.member?(selected_word_ids, &1))
    length(selected_in_lesson) == length(lesson_word_ids) and lesson_word_ids != []
  end

  defp all_words_selected?(selected_word_ids, word_entries) do
    MapSet.size(selected_word_ids) == length(word_entries) and word_entries != []
  end

  defp available_step_types do
    [
      %{
        id: "word_to_meaning",
        label: gettext("Word to Meaning"),
        icon: "hero-book-open",
        description: gettext("Show a Japanese word and select the English meaning")
      },
      %{
        id: "word_to_reading",
        label: gettext("Word to Reading"),
        icon: "hero-language",
        description: gettext("Show a Japanese word and select the hiragana reading")
      },
      %{
        id: "reading_text",
        label: gettext("Type Meaning & Reading"),
        icon: "hero-pencil",
        description: gettext("Type both the English meaning and hiragana reading")
      },
      %{
        id: "image_to_meaning",
        label: gettext("Image to Meaning"),
        icon: "hero-photo",
        description: gettext("Show a Japanese word and select from image options")
      },
      %{
        id: "kanji_writing",
        label: gettext("Kanji Writing"),
        icon: "hero-paint-brush",
        description: gettext("Draw kanji with correct stroke order (5 points)")
      }
    ]
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
            {gettext("Generate Vocabulary Test")}
          </h1>
          <p class="text-secondary mt-2">
            {gettext("Create a test from the words in this classroom's vocabulary lessons.")}
          </p>
        </div>

        <.form
          for={%{}}
          phx-submit="generate_test"
          class="space-y-6"
          id="generate-vocab-test-form"
        >
          <%!-- Hidden selected step types for form submission --%>
          <%= for step_type <- @selected_types do %>
            <input type="hidden" name="step_types[]" value={step_type} />
          <% end %>

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

          <%!-- Question Types --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-base-content mb-4">
                <.icon name="hero-question-mark-circle" class="w-5 h-5" /> {gettext("Question Types")}
              </h2>
              <div class="space-y-3">
                <%= for step_type <- available_step_types() do %>
                  <% is_selected = step_type.id in @selected_types %>
                  <button
                    type="button"
                    phx-click="toggle_type"
                    phx-value-type={step_type.id}
                    class={[
                      "w-full flex items-start gap-4 p-4 rounded-xl border-2 transition-all text-left",
                      step_type_card_class(is_selected)
                    ]}
                  >
                    <div class={[
                      "w-10 h-10 rounded-lg flex items-center justify-center shrink-0",
                      if(is_selected,
                        do: "bg-primary text-primary-content",
                        else: "bg-base-200 text-secondary"
                      )
                    ]}>
                      <.icon name={step_type.icon} class="w-5 h-5" />
                    </div>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2">
                        <span class="font-medium text-base-content">{step_type.label}</span>
                        <%= if is_selected do %>
                          <.icon name="hero-check-circle" class="w-5 h-5 text-primary" />
                        <% end %>
                      </div>
                      <p class="text-sm text-secondary mt-1">{step_type.description}</p>
                    </div>
                    <%= if is_selected do %>
                      <div class="w-6 h-6 rounded-full border-2 border-primary bg-primary flex items-center justify-center shrink-0">
                        <.icon name="hero-check" class="w-4 h-4 text-primary-content" />
                      </div>
                    <% else %>
                      <div class="w-6 h-6 rounded-full border-2 border-base-300 shrink-0"></div>
                    <% end %>
                  </button>
                <% end %>
              </div>

              <%= if length(@selected_types) == 1 do %>
                <div class="mt-4 p-4 bg-warning/10 rounded-lg">
                  <div class="flex items-start gap-3">
                    <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-warning mt-0.5" />
                    <div class="text-sm text-warning-content">
                      <p>{gettext("You must have at least one question type selected.")}</p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Word Pool --%>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <div class="flex items-center gap-3">
                  <input
                    type="checkbox"
                    id="select-all-words"
                    checked={all_words_selected?(@selected_word_ids, @word_entries)}
                    class="checkbox checkbox-primary"
                    phx-click="toggle_select_all"
                  />
                  <label for="select-all-words" class="font-medium cursor-pointer">
                    {gettext("Select All Words")}
                  </label>
                </div>
                <span class="text-sm text-secondary">
                  {MapSet.size(@selected_word_ids)} {gettext("of")} {length(@word_entries)} {gettext(
                    "words selected"
                  )}
                </span>
              </div>

              <div class="space-y-4">
                <%= for lesson <- @lessons do %>
                  <div class="border border-base-300 rounded-lg overflow-hidden">
                    <div class="bg-base-200/50 px-4 py-3 flex items-center justify-between">
                      <div class="flex items-center gap-3">
                        <input
                          type="checkbox"
                          id={"lesson-#{lesson.id}"}
                          checked={lesson_selected?(lesson, @selected_word_ids)}
                          class="checkbox checkbox-primary"
                          phx-click="toggle_lesson"
                          phx-value-lesson_id={lesson.id}
                        />
                        <label for={"lesson-#{lesson.id}"} class="font-medium cursor-pointer">
                          {lesson.title}
                        </label>
                      </div>
                      <span class="text-xs text-secondary">
                        {length(lesson.custom_lesson_words)} {gettext("words")}
                      </span>
                    </div>
                    <div class="divide-y divide-base-200">
                      <%= for clw <- lesson.custom_lesson_words |> Enum.sort_by(& &1.position) do %>
                        <% entry = Enum.find(@word_entries, &(&1.word_id == clw.word_id)) %>
                        <%= if entry do %>
                          <div class="px-4 py-2 flex items-center gap-3 hover:bg-base-100">
                            <input
                              type="checkbox"
                              id={"word-#{clw.word_id}"}
                              name="word_ids[]"
                              value={clw.word_id}
                              checked={MapSet.member?(@selected_word_ids, clw.word_id)}
                              class="checkbox checkbox-sm checkbox-primary"
                              phx-click="toggle_word"
                              phx-value-word_id={clw.word_id}
                            />
                            <label for={"word-#{clw.word_id}"} class="flex-1 cursor-pointer">
                              <span class="font-jp font-medium">{clw.word.text}</span>
                              <span class="text-sm text-secondary ml-2">{clw.word.reading}</span>
                              <span class="text-sm text-base-content/70 ml-2">
                                {clw.word.meaning}
                              </span>
                            </label>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
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
                <%!-- Max times per word --%>
                <div>
                  <label class="label">
                    <span class="label-text font-medium">
                      {gettext("Max Times a Word Can Appear")}
                    </span>
                  </label>
                  <input
                    type="number"
                    name="max_times_per_word"
                    min="1"
                    max="3"
                    value={@max_times_per_word}
                    phx-change="set_max_times"
                    phx-input="set_max_times"
                    class="input input-bordered w-full"
                  />
                  <p class="text-xs text-secondary mt-1">
                    {gettext("A word may be used up to this many times in the test (1–3).")}
                  </p>
                </div>

                <%!-- Total questions --%>
                <div>
                  <label class="label">
                    <span class="label-text font-medium">{gettext("Number of Questions")}</span>
                  </label>
                  <input
                    type="number"
                    name="total_questions"
                    min="1"
                    max={max_possible_questions(@selected_word_ids, @max_times_per_word)}
                    value={@total_questions}
                    phx-change="set_total_questions"
                    phx-input="set_total_questions"
                    class="input input-bordered w-full"
                  />
                  <p class="text-xs text-secondary mt-1">
                    {gettext("Maximum possible: %{max}",
                      max: max_possible_questions(@selected_word_ids, @max_times_per_word)
                    )}
                  </p>
                </div>

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

                <%!-- Distractor pool --%>
                <div>
                  <label class="label">
                    <span class="label-text font-medium">
                      {gettext("Distractor Pool")}
                    </span>
                  </label>
                  <select
                    name="distractor_pool"
                    phx-change="update_distractor_pool"
                    class="select select-bordered w-full"
                  >
                    <option value="selected" selected={@distractor_pool == :selected}>
                      {gettext("Selected words only")}
                    </option>
                    <option value="classroom" selected={@distractor_pool == :classroom}>
                      {gettext("All words in this classroom")}
                    </option>
                  </select>
                  <p class="text-xs text-secondary mt-1">
                    {gettext("Where multichoice distractors (wrong answers) are chosen from.")}
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
              disabled={
                @generating or MapSet.size(@selected_word_ids) == 0 or length(@selected_types) == 0
              }
              class="flex-1 px-6 py-3 bg-primary hover:bg-primary/90 disabled:bg-base-300 disabled:cursor-not-allowed text-primary-content rounded-lg font-medium transition-colors"
            >
              <%= if @generating do %>
                <span class="loading loading-spinner loading-sm mr-2"></span>
                {gettext("Generating...")}
              <% else %>
                <.icon name="hero-sparkles" class="w-5 h-5 mr-2" /> {gettext("Generate Test")}
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
