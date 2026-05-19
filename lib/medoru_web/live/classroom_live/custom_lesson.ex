defmodule MedoruWeb.ClassroomLive.CustomLesson do
  @moduledoc """
  LiveView for students to study a custom lesson.
  Supports both vocabulary lessons (with words) and grammar lessons (with steps).
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.Content
  alias MedoruWeb.PublicAccess

  @color_palette [
    "bg-red-200",
    "bg-red-300",
    "bg-orange-200",
    "bg-orange-300",
    "bg-amber-200",
    "bg-amber-300",
    "bg-yellow-200",
    "bg-yellow-300",
    "bg-lime-200",
    "bg-lime-300",
    "bg-green-200",
    "bg-green-300",
    "bg-emerald-200",
    "bg-emerald-300",
    "bg-teal-200",
    "bg-teal-300",
    "bg-cyan-200",
    "bg-cyan-300",
    "bg-sky-200",
    "bg-sky-300",
    "bg-blue-200",
    "bg-blue-300",
    "bg-indigo-200",
    "bg-indigo-300",
    "bg-violet-200",
    "bg-violet-300",
    "bg-purple-200",
    "bg-purple-300",
    "bg-fuchsia-200",
    "bg-fuchsia-300",
    "bg-pink-200",
    "bg-pink-300",
    "bg-rose-200",
    "bg-rose-300"
  ]

  # Text color for word highlights (ensure Tailwind scans it)
  @word_highlight_text_color "text-gray-900"

  @impl true
  def mount(%{"lesson_id" => lesson_id}, session, socket)
      when socket.assigns.live_action == :preview do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user
    step = session["step"] || 0

    lesson = Content.get_custom_lesson!(lesson_id)

    # Only allow creator or teacher/admin to preview
    if user && (lesson.creator_id == user.id || user.type in ["teacher", "admin"]) do
      # Find a classroom this lesson is published to for context
      published = Content.list_classroom_custom_lessons_for_lesson(lesson.id)

      classroom =
        case published do
          [first | _] -> Classrooms.get_classroom!(first.classroom_id)
          [] -> nil
        end

      preview_lesson(socket, lesson, classroom, user, locale, step)
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("You don't have permission to preview this lesson."))
       |> push_navigate(to: ~p"/teacher/custom-lessons")}
    end
  end

  @impl true
  def mount(%{"id" => classroom_id, "lesson_id" => lesson_id}, session, socket) do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user
    practice = session["practice"] == true

    # Store step from query param (will be processed in handle_params)
    step = session["step"] || 0

    cond do
      not is_nil(user) ->
        # Authenticated user - verify membership
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
              load_lesson(socket, classroom_id, lesson_id, user, locale, practice, step)
            end
        end

      PublicAccess.featured_classroom?(classroom_id) ->
        # Anonymous user accessing featured classroom
        load_lesson(socket, classroom_id, lesson_id, nil, locale, false, step)

      true ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You must sign in to access this lesson."))
         |> push_navigate(to: ~p"/auth/google")}
    end
  end

  defp load_lesson(socket, classroom_id, lesson_id, user, locale, practice, step) do
    classroom = Classrooms.get_classroom!(classroom_id)
    lesson = Content.get_custom_lesson!(lesson_id)

    # Verify lesson is published to this classroom
    result = Content.list_classroom_custom_lessons(classroom_id)
    lesson_ids = Enum.map(result.lessons, fn pc -> pc.custom_lesson_id end)

    if lesson_id not in lesson_ids do
      {:ok,
       socket
       |> put_flash(:error, gettext("This lesson is not available in this classroom."))
       |> push_navigate(to: ~p"/classrooms/#{classroom_id}")}
    else
      is_anonymous = is_nil(user)

      # Get existing progress (skip for anonymous users)
      progress =
        if is_anonymous do
          nil
        else
          Classrooms.get_custom_lesson_progress(classroom_id, user.id, lesson_id)
        end

      is_completed = progress && progress.status == "completed"

      # For new lessons, create progress (skip for anonymous users)
      progress =
        if is_nil(progress) and not practice and not is_anonymous do
          {:ok, prog} = Classrooms.start_custom_lesson(classroom_id, user.id, lesson_id)
          prog
        else
          progress
        end

      # Load content based on lesson subtype
      if lesson.lesson_subtype == "grammar" do
        load_grammar_lesson(socket, classroom, lesson, progress, is_completed, practice, locale)
      else
        load_vocabulary_lesson(
          socket,
          classroom,
          lesson,
          progress,
          is_completed,
          practice,
          locale,
          step
        )
      end
    end
  end

  defp preview_lesson(socket, lesson, classroom, _user, locale, step) do
    # Preview mode: show lesson as student would see it, without progress tracking
    classroom = classroom || %{id: nil, name: gettext("Preview")}

    if lesson.lesson_subtype == "grammar" do
      load_grammar_lesson(socket, classroom, lesson, nil, false, false, locale, step)
      |> elem(1)
      |> assign(:is_preview, true)
      |> then(&{:ok, &1})
    else
      load_vocabulary_lesson(socket, classroom, lesson, nil, false, false, locale, step)
      |> elem(1)
      |> assign(:is_preview, true)
      |> then(&{:ok, &1})
    end
  end

  defp load_vocabulary_lesson(
         socket,
         classroom,
         lesson,
         progress,
         is_completed,
         practice,
         locale,
         step
       ) do
    lesson_words = Content.list_lesson_words(lesson.id)
    total_items = length(lesson_words)
    # Ensure step is within valid range
    current_index = min(max(step, 0), max(total_items - 1, 0))
    current_word = Enum.at(lesson_words, current_index)

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:classroom, classroom)
     |> assign(:lesson, lesson)
     |> assign(:lesson_type, :vocabulary)
     |> assign(:lesson_words, lesson_words)
     |> assign(:grammar_steps, [])
     |> assign(:word_classes, %{})
     |> assign(:progress, progress)
     |> assign(:is_completed, is_completed)
     |> assign(:practice, practice)
     |> assign(:current_index, current_index)
     |> assign(:current_word, current_word)
     |> assign(:is_preview, false)
     |> assign(:presentation_mode, false)
     |> assign(:total_items, length(lesson_words))}
  end

  defp load_grammar_lesson(
         socket,
         classroom,
         lesson,
         progress,
         is_completed,
         practice,
         locale,
         step \\ 0
       ) do
    grammar_steps = Content.list_grammar_lesson_steps(lesson.id)
    total_items = length(grammar_steps)
    # Ensure step is within valid range
    current_index = min(max(step, 0), max(total_items - 1, 0))
    current_step = Enum.at(grammar_steps, current_index)
    current_step = %{current_step | explanation: String.trim(current_step.explanation || "")}

    # Load word classes for pattern display
    word_classes =
      Content.list_word_classes()
      |> Enum.map(fn wc -> {wc.id, wc.display_name} end)
      |> Enum.into(%{})

    step_word_colors = build_step_word_colors(lesson, current_step)

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:classroom, classroom)
     |> assign(:lesson, lesson)
     |> assign(:lesson_type, :grammar)
     |> assign(:lesson_words, [])
     |> assign(:grammar_steps, grammar_steps)
     |> assign(:word_classes, word_classes)
     |> assign(:progress, progress)
     |> assign(:is_completed, is_completed)
     |> assign(:practice, practice)
     |> assign(:current_index, current_index)
     |> assign(:current_step, current_step)
     |> assign(:step_word_colors, step_word_colors)
     |> assign(:student_sentence, "")
     |> assign(:is_preview, false)
     |> assign(:presentation_mode, false)
     |> assign(:total_items, length(grammar_steps))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Handle step from URL query param
    step = parse_step(params["step"])

    socket =
      if step != socket.assigns[:current_index] && step >= 0 && step < socket.assigns.total_items do
        # Update current index and item based on step
        case socket.assigns.lesson_type do
          :vocabulary ->
            assign(socket,
              current_index: step,
              current_word: Enum.at(socket.assigns.lesson_words, step)
            )

          :grammar ->
            current_step = Enum.at(socket.assigns.grammar_steps, step)

            current_step = %{
              current_step
              | explanation: String.trim(current_step.explanation || "")
            }

            step_word_colors = build_step_word_colors(socket.assigns.lesson, current_step)

            assign(socket,
              current_index: step,
              current_step: current_step,
              step_word_colors: step_word_colors,
              student_sentence: ""
            )

          _ ->
            socket
        end
      else
        socket
      end

    {:noreply,
     assign(
       socket,
       :page_title,
       Content.get_localized_lesson_title(socket.assigns.lesson, socket.assigns.locale)
     )}
  end

  defp parse_step(nil), do: nil

  defp parse_step(step) when is_binary(step) do
    case Integer.parse(step) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_step(step) when is_integer(step), do: step

  @impl true
  def handle_event("next", _params, socket) do
    current_index = socket.assigns.current_index
    total = socket.assigns.total_items

    if current_index < total - 1 do
      next_index = current_index + 1

      socket =
        case socket.assigns.lesson_type do
          :vocabulary ->
            assign(socket,
              current_index: next_index,
              current_word: Enum.at(socket.assigns.lesson_words, next_index)
            )

          :grammar ->
            next_step = Enum.at(socket.assigns.grammar_steps, next_index)
            next_step = %{next_step | explanation: String.trim(next_step.explanation || "")}
            step_word_colors = build_step_word_colors(socket.assigns.lesson, next_step)

            assign(socket,
              current_index: next_index,
              current_step: next_step,
              step_word_colors: step_word_colors,
              student_sentence: ""
            )
        end

      # Update URL with new step
      socket = push_step_to_url(socket, next_index)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev", _params, socket) do
    current_index = socket.assigns.current_index

    if current_index > 0 do
      prev_index = current_index - 1

      socket =
        case socket.assigns.lesson_type do
          :vocabulary ->
            assign(socket,
              current_index: prev_index,
              current_word: Enum.at(socket.assigns.lesson_words, prev_index)
            )

          :grammar ->
            prev_step = Enum.at(socket.assigns.grammar_steps, prev_index)
            prev_step = %{prev_step | explanation: String.trim(prev_step.explanation || "")}
            step_word_colors = build_step_word_colors(socket.assigns.lesson, prev_step)

            assign(socket,
              current_index: prev_index,
              current_step: prev_step,
              step_word_colors: step_word_colors,
              student_sentence: ""
            )
        end

      # Update URL with new step
      socket = push_step_to_url(socket, prev_index)
      {:noreply, socket}
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
    is_anonymous = is_nil(user)

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
        if is_anonymous do
          # Anonymous user - skip test, go to completion with prompt to sign in
          {:noreply,
           socket
           |> push_navigate(
             to:
               ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}/complete?anonymous=true"
           )}
        else
          # Check if test is already completed
          case Medoru.Tests.get_completed_test_session(user.id, lesson.test_id) do
            nil ->
              # Redirect to test
              {:noreply,
               socket
               |> push_navigate(
                 to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}/test"
               )}

            _session ->
              # Test already completed, show already completed message
              {:noreply,
               socket
               |> put_flash(
                 :info,
                 gettext("You've already completed this lesson. Use Practice Mode to review.")
               )
               |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=lessons")}
          end
        end
      else
        # No test required, mark lesson complete (skip DB for anonymous)
        if is_anonymous do
          {:noreply,
           socket
           |> push_navigate(
             to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}/complete"
           )}
        else
          complete_lesson(socket, classroom_id, user.id, lesson_id)
        end
      end
    end
  end

  @impl true
  def handle_event("toggle_presentation", _params, socket) do
    socket =
      if socket.assigns.presentation_mode do
        socket
        |> assign(:presentation_mode, false)
        |> push_event("exit_presentation", %{})
      else
        socket
        |> assign(:presentation_mode, true)
        |> push_event("enter_presentation", %{})
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("presentation_exited", _params, socket) do
    {:noreply, assign(socket, :presentation_mode, false)}
  end

  @impl true
  def handle_event("validate_student_sentence", %{"sentence" => sentence}, socket) do
    step = socket.assigns.current_step
    sentence = String.trim(sentence)

    if sentence == "" do
      {:noreply, put_flash(socket, :error, gettext("Please enter a sentence."))}
    else
      socket = assign(socket, :student_sentence, sentence)
      alias Medoru.Grammar.Validator

      case Validator.validate_sentence(sentence, step.pattern_elements) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, gettext("Your sentence matches the pattern!"))}

        {:error, %{expected: expected, got: got}} when got == "" or is_nil(got) ->
          {:noreply,
           put_flash(
             socket,
             :error,
             gettext("Expected: %{expected}. Make sure you've entered the correct form.",
               expected: expected
             )
           )}

        {:error, %{expected: expected, got: got}} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             gettext(
               "Expected: %{expected}, but got: %{got}. Make sure you've entered the correct conjugated form.",
               expected: expected,
               got: got
             )
           )}

        {:error, reason} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             gettext("Doesn't match pattern. Expected: %{expected}.",
               expected: reason[:expected] || "pattern"
             )
           )}
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

  # Helper to update URL with current step
  defp push_step_to_url(socket, step) do
    is_preview = socket.assigns.is_preview
    lesson_id = socket.assigns.lesson.id
    practice = socket.assigns.practice

    path =
      cond do
        is_preview ->
          ~p"/teacher/custom-lessons/#{lesson_id}/preview?step=#{step}"

        practice ->
          classroom_id = socket.assigns.classroom.id
          ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}?step=#{step}&practice=true"

        true ->
          classroom_id = socket.assigns.classroom.id
          ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}?step=#{step}"
      end

    push_patch(socket, to: path)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div
        id="lesson-container"
        phx-hook="LessonPlayer"
        class="max-w-3xl mx-auto px-4 py-8"
      >
        <%!-- Preview Banner --%>
        <%= if @is_preview do %>
          <div class="bg-info/10 border border-info rounded-lg p-3 mb-6 flex items-center justify-between">
            <div class="flex items-center gap-2 text-info">
              <.icon name="hero-eye" class="w-5 h-5" />
              <span class="font-medium">{gettext("Preview Mode")}</span>
            </div>
            <% edit_path =
              if @lesson.lesson_subtype == "grammar",
                do: ~p"/teacher/grammar-lessons/#{@lesson.id}/edit",
                else: ~p"/teacher/custom-lessons/#{@lesson.id}/edit" %>
            <.link
              navigate={edit_path}
              class="btn btn-ghost btn-xs"
            >
              <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> {gettext("Edit Lesson")}
            </.link>
          </div>
        <% end %>

        <%!-- Header --%>
        <div class="mb-6 lesson-header">
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
            <div class="flex items-center gap-3">
              <button
                phx-click="toggle_presentation"
                class="btn btn-ghost btn-sm"
                title={gettext("Presentation Mode")}
              >
                <.icon name="hero-presentation-chart-line" class="w-5 h-5" />
              </button>
              <span class="text-secondary">
                {@current_index + 1} / {@total_items}
              </span>
            </div>
          </div>
          <%= if @lesson.description do %>
            <p class="text-secondary mt-2">{@lesson.description}</p>
          <% end %>
        </div>

        <%!-- Progress Bar --%>
        <div class="w-full bg-base-200 rounded-full h-2 mb-8">
          <div
            class="bg-primary h-2 rounded-full transition-all"
            style={"width: #{((@current_index + 1) / max(@total_items, 1)) * 100}%"}
          />
        </div>

        <div class="lesson-content">
          <%= case @lesson_type do %>
            <% :vocabulary -> %>
              <.vocabulary_content {assigns} />
            <% :grammar -> %>
              <.grammar_content {assigns} />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Vocabulary lesson content (original word-based display)
  defp vocabulary_content(assigns) do
    ~H"""
    <%= if @current_word do %>
      <div class="card bg-base-100 border border-base-300 shadow-lg" phx-no-format>
        <div class="card-body text-center py-12">
          <%!-- Japanese Text --%>
          <.link
            navigate={
              word_detail_path(
                @classroom.id,
                @lesson.id,
                @current_word.word.id,
                @current_index,
                @practice
              )
            }
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

          <%!-- Examples --%>
          <%= if @current_word.examples && @current_word.examples != [] do %>
            <div class="border-t border-base-200 pt-6 mt-6">
              <h3 class="text-sm font-medium text-secondary mb-4">{gettext("Examples")}</h3>
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

        <%= if @current_index < @total_items - 1 do %>
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
                  navigate={
                    ~p"/classrooms/#{@classroom.id}/custom-lessons/#{@lesson.id}/test?practice=true"
                  }
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
    """
  end

  # Grammar lesson content (step-based display)
  defp grammar_content(assigns) do
    ~H"""
    <%= if @current_step do %>
      <div class="card bg-base-100 border border-base-300 shadow-lg" phx-no-format>
        <div class="card-body">
          <%!-- Step Title --%>
          <div class="mb-4">
            <h2 class="text-xl font-semibold">{@current_step.title}</h2>
          </div>

          <%= if @current_step.step_type == "text" do %>
            <%!-- Text Step Content --%>
            <div class="space-y-6">
              <%= for section <- @current_step.explanation_sections || [] do %>
                <div class="markdown-content text-base-content leading-relaxed">
                  {raw(markdown_with_colors(section, @step_word_colors, :explanation))}
                </div>
              <% end %>
            </div>
          <% else %>
            <%!-- Grammar Pattern --%>
            <div class="bg-base-200 rounded-lg p-4 mb-6">
              <p class="text-sm text-secondary mb-2">{gettext("Pattern:")}</p>
              <div class="flex flex-wrap gap-2 items-center">
                <%= for element <- @current_step.pattern_elements || [] do %>
                  <%= case element["type"] do %>
                    <% "word_slot" -> %>
                      <% word_type_colors = %{
                        "verb" => "bg-emerald-500 text-white",
                        "noun" => "bg-blue-500 text-white",
                        "adjective" => "bg-rose-500 text-white",
                        "expression" => "bg-amber-400 text-amber-950",
                        "particle" => "bg-orange-500 text-white"
                      }

                      color = word_type_colors[element["word_type"]] || "bg-gray-500 text-white" %>
                      <span class={["px-3 py-1.5 rounded-lg text-sm font-medium", color]}>
                        {String.capitalize(element["word_type"] || "word")}
                        <%= if element["form"] do %>
                          <span class="font-jp ml-1">[{element["form"]}]</span>
                        <% end %>
                      </span>
                    <% "word_class" -> %>
                      <% class = @word_classes[element["word_class_id"]] %>
                      <span class="px-3 py-1.5 rounded-lg text-sm font-medium bg-secondary text-secondary-content">
                        <%= if class do %>
                          {class}
                        <% else %>
                          {gettext("Class")}
                        <% end %>
                      </span>
                    <% "literal" -> %>
                      <span class="px-3 py-1.5 rounded-lg text-lg font-bold bg-white text-gray-900 border border-base-300 font-jp">
                        {element["value"] || element["text"] || "..."}
                      </span>
                    <% _ -> %>
                  <% end %>
                <% end %>
              </div>
            </div>

            <%!-- Explanation --%>
            <div class="mb-6">
              <h3 class="text-sm font-medium text-secondary mb-2">{gettext("Explanation:")}</h3>
              <div class="markdown-content text-base-content leading-relaxed">
                {raw(markdown_with_colors(@current_step.explanation, @step_word_colors, :explanation))}
              </div>
            </div>

            <%!-- Examples --%>
            <%= if @current_step.examples && @current_step.examples != [] do %>
              <div class="border-t border-base-200 pt-6">
                <h3 class="text-sm font-medium text-secondary mb-4">{gettext("Examples:")}</h3>
                <div class="space-y-4">
                  <%= for example <- @current_step.examples do %>
                    <div class="bg-base-100 border border-base-300 rounded-lg p-4">
                      <p class="text-xl font-jp mb-1">
                        <.colored_segments segments={apply_word_colors(example["sentence"], @step_word_colors, :examples)} />
                      </p>
                      <p class="text-sm text-secondary font-jp mb-1">
                        <.colored_segments segments={apply_word_colors(example["reading"], @step_word_colors, :examples)} />
                      </p>
                      <p class="text-secondary">{example["meaning"]}</p>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%!-- Student Sentence Validation --%>
            <%= if @current_step.allows_student_validation do %>
              <div class="border-t border-base-200 pt-6">
                <h3 class="text-sm font-medium text-secondary mb-4">{gettext("Try it yourself:")}</h3>
                <div class="bg-base-100 border border-base-300 rounded-lg p-4">
                  <p class="text-sm text-secondary mb-3">
                    {gettext("Enter a sentence using this grammar pattern:")}
                  </p>
                  <form phx-submit="validate_student_sentence" class="space-y-3">
                    <input
                      type="text"
                      name="sentence"
                      value={@student_sentence}
                      class="input input-bordered w-full font-jp"
                      placeholder={gettext("Type your sentence here...")}
                      autocomplete="off"
                    />
                    <button type="submit" class="btn btn-outline btn-sm">
                      <.icon name="hero-check-circle" class="w-4 h-4 mr-1" /> {gettext("Validate")}
                    </button>
                  </form>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <%!-- Navigation --%>
      <div class="flex justify-between items-center mt-8">
        <button
          phx-click="prev"
          class={["btn btn-ghost", @current_index == 0 && "invisible"]}
        >
          <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> {gettext("Previous")}
        </button>

        <%= if @current_index < @total_items - 1 do %>
          <button phx-click="next" class="btn btn-primary">
            {gettext("Next")} <.icon name="hero-arrow-right" class="w-5 h-5 ml-2" />
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
                  navigate={
                    ~p"/classrooms/#{@classroom.id}/custom-lessons/#{@lesson.id}/test?practice=true"
                  }
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
    """
  end

  # Build merged word colors for a step (step overrides lesson-level)
  defp build_step_word_colors(lesson, current_step) do
    lesson_colors = lesson.word_colors || []
    step_colors = current_step.word_colors || []

    # Step colors override lesson colors for same word
    merged =
      lesson_colors
      |> Enum.map(fn c -> {c["word"], c} end)
      |> Enum.into(%{})

    merged =
      step_colors
      |> Enum.reduce(merged, fn c, acc -> Map.put(acc, c["word"], c) end)

    Map.values(merged)
  end

  # Apply word colors to text, returning segments
  defp apply_word_colors(text, word_colors, scope) when is_binary(text) do
    # Filter by scope
    applicable =
      Enum.filter(word_colors, fn c ->
        apply_to = c["apply_to"] || "both"
        apply_to == "both" or apply_to == to_string(scope)
      end)

    # Build color lookup map (bg + text color for contrast)
    color_map =
      Enum.into(applicable, %{}, fn c ->
        bg_class = Enum.at(@color_palette, c["color_index"] || 0)
        {c["word"], "#{bg_class} #{@word_highlight_text_color}"}
      end)

    words =
      Map.keys(color_map)
      |> Enum.reject(&(&1 == ""))
      |> Enum.sort_by(&String.length/1, :desc)

    do_color_split(text, words, color_map, [])
  end

  defp apply_word_colors(nil, _word_colors, _scope), do: [{:text, ""}]

  defp do_color_split("", _words, _color_map, acc), do: Enum.reverse(acc)

  defp do_color_split(text, words, color_map, acc) do
    case find_leftmost_match(text, words, color_map) do
      nil ->
        Enum.reverse([{:text, text} | acc])

      {word, color_class, before, after_text} ->
        acc = if before != "", do: [{:text, before} | acc], else: acc
        do_color_split(after_text, words, color_map, [{:colored, word, color_class} | acc])
    end
  end

  defp find_leftmost_match(text, words, color_map) do
    matches =
      Enum.flat_map(words, fn word ->
        case :binary.match(text, word) do
          {pos, len} -> [{pos, len, word, color_map[word]}]
          :nomatch -> []
        end
      end)

    case Enum.sort_by(matches, fn {pos, _, _, _} -> pos end) |> List.first() do
      nil ->
        nil

      {pos, len, word, color_class} ->
        before = binary_part(text, 0, pos)
        after_text = binary_part(text, pos + len, byte_size(text) - pos - len)
        {word, color_class, before, after_text}
    end
  end

  # Render colored segments without inter-element whitespace
  attr :segments, :list, required: true

  defp colored_segments(assigns) do
    ~H"""
    <%= for segment <- @segments do %>
      <%= case segment do %>
        <% {:text, text} -> %>
          <span>{text}</span>
        <% {:colored, text, classes} -> %>
          <span class={["rounded", classes]}>{text}</span>
      <% end %>
    <% end %>
    """
  end

  # Render markdown with word colors applied
  # Word coloring is applied first (inserting inline HTML spans),
  # then markdown is parsed to HTML with inline HTML preserved.
  defp markdown_with_colors(text, word_colors, scope) when is_binary(text) do
    segments = apply_word_colors(text, word_colors, scope)

    # Build a single string with inline spans for colored words
    markdown_text =
      Enum.map_join(segments, "", fn
        {:text, text} -> text
        {:colored, word, classes} -> ~s(<span class="#{classes}">#{word}</span>)
      end)

    # Parse markdown to HTML, preserving inline HTML
    # smartypants: false prevents curly quotes from breaking HTML attributes
    {:ok, html, _} = Earmark.as_html(markdown_text, escape: false, smartypants: false)
    html
  end

  defp markdown_with_colors(nil, _word_colors, _scope), do: ""

  # Helper to generate word detail path with return step
  defp word_detail_path(classroom_id, lesson_id, word_id, step, practice) do
    return_to = "/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}"

    params = [{"return_to", return_to}, {"step", step}]
    params = if practice, do: [{"practice", "true"} | params], else: params

    query = URI.encode_query(params)

    ~p"/words/#{word_id}?#{query}"
  end
end
