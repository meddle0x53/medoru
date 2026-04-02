defmodule MedoruWeb.ClassroomLive.CustomLesson do
  @moduledoc """
  LiveView for students to study a custom lesson.
  Supports both vocabulary lessons (with words) and grammar lessons (with steps).
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.Content

  @impl true
  def mount(%{"id" => classroom_id, "lesson_id" => lesson_id}, session, socket) do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user
    practice = session["practice"] == true

    # Store step from query param (will be processed in handle_params)
    step = session["step"] || 0

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
          load_lesson(socket, classroom_id, lesson_id, user, locale, practice, step)
        end
    end
  end

  defp load_lesson(socket, classroom_id, lesson_id, user, locale, practice, step \\ 0) do
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

  defp load_vocabulary_lesson(socket, classroom, lesson, progress, is_completed, practice, locale, step \\ 0) do
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
     |> assign(:total_items, length(lesson_words))}
  end

  defp load_grammar_lesson(socket, classroom, lesson, progress, is_completed, practice, locale, step \\ 0) do
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
            current_step = %{current_step | explanation: String.trim(current_step.explanation || "")}
            
            assign(socket,
              current_index: step,
              current_step: current_step
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
            
            assign(socket,
              current_index: next_index,
              current_step: next_step
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
            
            assign(socket,
              current_index: prev_index,
              current_step: prev_step
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
  
  # Helper to update URL with current step
  defp push_step_to_url(socket, step) do
    classroom_id = socket.assigns.classroom.id
    lesson_id = socket.assigns.lesson.id
    practice = socket.assigns.practice
    
    path = 
      if practice do
        ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}?step=#{step}&practice=true"
      else
        ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}?step=#{step}"
      end
    
    push_patch(socket, to: path)
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
              {@current_index + 1} / {@total_items}
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
            style={"width: #{((@current_index + 1) / max(@total_items, 1)) * 100}%"}
          />
        </div>

        <%= case @lesson_type do %>
          <% :vocabulary -> %>
            <.vocabulary_content {assigns} />
          <% :grammar -> %>
            <.grammar_content {assigns} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # Vocabulary lesson content (original word-based display)
  defp vocabulary_content(assigns) do
    ~H"""
    <%= if @current_word do %>
      <div class="card bg-base-100 border border-base-300 shadow-lg">
        <div class="card-body text-center py-12">
          <%!-- Japanese Text --%>
          <.link
            navigate={word_detail_path(@classroom.id, @lesson.id, @current_word.word.id, @current_index, @practice)}
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
      <div class="card bg-base-100 border border-base-300 shadow-lg">
        <div class="card-body">
          <%!-- Step Title --%>
          <div class="flex items-center gap-2 mb-4">
            <span class="badge badge-ghost">
              {gettext("Step")} #{@current_index + 1}
            </span>
            <h2 class="text-xl font-semibold">{@current_step.title}</h2>
          </div>

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
            <div class="text-base-content whitespace-pre-wrap leading-relaxed">
              {@current_step.explanation}
            </div>
          </div>

          <%!-- Examples --%>
          <%= if @current_step.examples && @current_step.examples != [] do %>
            <div class="border-t border-base-200 pt-6">
              <h3 class="text-sm font-medium text-secondary mb-4">{gettext("Examples:")}</h3>
              <div class="space-y-4">
                <%= for example <- @current_step.examples do %>
                  <div class="bg-base-100 border border-base-300 rounded-lg p-4">
                    <p class="text-xl font-jp mb-1">{example["sentence"]}</p>
                    <p class="text-sm text-secondary font-jp mb-1">{example["reading"]}</p>
                    <p class="text-secondary">{example["meaning"]}</p>
                  </div>
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
  
  # Helper to generate word detail path with return step
  defp word_detail_path(classroom_id, lesson_id, word_id, step, practice) do
    return_to = "/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}"
    
    params = [{"return_to", return_to}, {"step", step}]
    params = if practice, do: [{"practice", "true"} | params], else: params
    
    query = URI.encode_query(params)
    
    ~p"/words/#{word_id}?#{query}"
  end
end
