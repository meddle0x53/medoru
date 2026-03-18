defmodule MedoruWeb.ClassroomLive.CustomLessonTest do
  @moduledoc """
  LiveView for students to take a custom lesson test.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Tests

  @impl true
  def mount(%{"id" => classroom_id, "lesson_id" => lesson_id} = params, session, socket) do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user
    practice = params["practice"] == "true"

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
          load_test(socket, classroom_id, lesson_id, user, locale, practice)
        end
    end
  end

  defp load_test(socket, classroom_id, lesson_id, user, locale, practice) do
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
      # Check if test is required and exists
      if not lesson.requires_test or is_nil(lesson.test_id) do
        {:ok,
         socket
         |> push_navigate(
           to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}"
         )}
      else
        # In practice mode, always allow test; otherwise check if already completed
        already_completed = Tests.get_completed_test_session(user.id, lesson.test_id) != nil
        
        if already_completed and not practice do
          # Already completed and not in practice mode, go back to lesson
          {:ok,
           socket
           |> put_flash(:info, gettext("You've already completed this test. Use Practice Mode to review."))
           |> push_navigate(
             to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}"
           )}
        else
          # Start a new test session
          # In practice mode, we still create a session but won't complete the lesson
          case Tests.start_test_session(user.id, lesson.test_id) do
            {:ok, session} ->
              session = Tests.get_test_session_with_answers(session.id)
              current_step = get_current_step(session)

              {:ok,
               socket
               |> assign(:locale, locale)
               |> assign(:classroom, classroom)
               |> assign(:lesson, lesson)
               |> assign(:session, session)
               |> assign(:current_step, current_step)
               |> assign(:selected_answer, nil)
               |> assign(:feedback, nil)
               |> assign(:practice, practice)}

            {:error, _reason} ->
              {:ok,
               socket
               |> put_flash(:error, gettext("Could not start test."))
               |> push_navigate(
                 to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}"
               )}
          end
        end
      end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    title = 
      if socket.assigns[:practice] do
        gettext("Practice Test: %{title}", title: socket.assigns.lesson.title)
      else
        gettext("Test: %{title}", title: socket.assigns.lesson.title)
      end
    
    {:noreply,
     assign(
       socket,
       :page_title,
       title
     )}
  end

  @impl true
  def handle_event("select_answer", %{"answer" => answer}, socket) do
    {:noreply, assign(socket, :selected_answer, answer)}
  end

  @impl true
  def handle_event("submit_answer", _params, socket) do
    answer = socket.assigns.selected_answer

    if is_nil(answer) do
      {:noreply, put_flash(socket, :error, gettext("Please select an answer"))}
    else
      session = socket.assigns.session
      step = socket.assigns.current_step

      # Record answer
      attrs = %{
        answer: answer,
        time_spent_seconds: 10,
        step_index: session.current_step_index
      }

      case Tests.record_step_answer(session.id, step.id, attrs, locale: socket.assigns.locale) do
        {:ok, step_answer} ->
          if step_answer.is_correct do
            handle_correct_answer(socket, step)
          else
            handle_incorrect_answer(socket, step)
          end

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, gettext("Error recording answer"))}
      end
    end
  end

  @impl true
  def handle_event("clear_feedback", _params, socket) do
    {:noreply, assign(socket, :feedback, nil)}
  end

  @impl true
  def handle_event("kanji_complete", _params, socket) do
    # Kanji writing completed successfully
    session = socket.assigns.session
    step = socket.assigns.current_step

    # Submit as correct answer
    attrs = %{
      answer: "completed",
      time_spent_seconds: 15,
      step_index: session.current_step_index,
      is_correct: true
    }

    case Tests.record_step_answer(session.id, step.id, attrs, locale: socket.assigns.locale) do
      {:ok, _step_answer} ->
        handle_correct_answer(socket, step)

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Error recording answer"))}
    end
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => true}, socket) do
    # Submit button clicked when kanji is complete
    handle_event("kanji_complete", %{}, socket)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => false}, socket) do
    # User skipped or didn't complete - mark as incorrect
    session = socket.assigns.session
    step = socket.assigns.current_step

    attrs = %{
      answer: "skipped",
      time_spent_seconds: 15,
      step_index: session.current_step_index,
      is_correct: false
    }

    case Tests.record_step_answer(session.id, step.id, attrs, locale: socket.assigns.locale) do
      {:ok, _step_answer} ->
        handle_incorrect_answer(socket, step)

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Error recording answer"))}
    end
  end

  defp handle_correct_answer(socket, _step) do
    session = socket.assigns.session

    # Update session progress
    progress_index = session.current_step_index + 1

    {:ok, updated_session} =
      Tests.progress_session(
        session,
        progress_index,
        session.time_spent_seconds + 10
      )

    # Get next step
    next_step = get_next_step(updated_session)

    if next_step do
      {:noreply,
       socket
       |> assign(:session, updated_session)
       |> assign(:current_step, next_step)
       |> assign(:selected_answer, nil)
       |> assign(:feedback, :correct)}
    else
      # Complete test
      complete_test(socket)
    end
  end

  defp handle_incorrect_answer(socket, _step) do
    session = socket.assigns.session

    # Still advance to next step
    next_step = get_next_step(session)

    if next_step do
      {:ok, updated_session} =
        Tests.progress_session(
          session,
          session.current_step_index + 1,
          session.time_spent_seconds + 10
        )

      {:noreply,
       socket
       |> assign(:session, updated_session)
       |> assign(:current_step, next_step)
       |> assign(:selected_answer, nil)
       |> assign(:feedback, :incorrect)}
    else
      # Complete test even with incorrect last answer
      complete_test(socket)
    end
  end

  defp complete_test(socket) do
    session = socket.assigns.session
    user = socket.assigns.current_scope.current_user
    classroom_id = socket.assigns.classroom.id
    lesson_id = socket.assigns.lesson.id
    practice = socket.assigns.practice

    # Calculate final score
    {score, total_possible} = Tests.calculate_session_score(session.id)

    # Complete session (for tracking)
    {:ok, _completed_session} =
      Tests.complete_session(
        session,
        score,
        total_possible,
        session.time_spent_seconds + 10
      )

    if practice do
      # In practice mode, don't mark lesson complete or award points
      {:noreply,
       socket
       |> push_navigate(
         to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}/complete?practice=true"
       )}
    else
      # Normal mode: Mark lesson as complete and award points
      Classrooms.complete_custom_lesson(classroom_id, user.id, lesson_id)

      # Navigate to completion page
      {:noreply,
       socket
       |> push_navigate(
         to: ~p"/classrooms/#{classroom_id}/custom-lessons/#{lesson_id}/complete"
       )}
    end
  end

  defp get_current_step(session) do
    test = Tests.get_test!(session.test_id)

    test.test_steps
    |> Enum.find(fn step ->
      step.order_index == session.current_step_index
    end)
  end

  defp get_next_step(session) do
    test = Tests.get_test!(session.test_id)

    test.test_steps
    |> Enum.find(fn step ->
      step.order_index > session.current_step_index
    end)
  end

  # Localize options for display
  # Returns list of {original_value, display_value} tuples
  defp localize_options(step, locale) do
    options = step.options || []
    qd = step.question_data || %{}
    word_ids = qd[:option_word_ids] || qd["option_word_ids"] || []

    # Check if this is a meaning-based question
    is_meaning_question = is_meaning_question?(step)

    options
    |> Enum.with_index()
    |> Enum.map(fn {option, idx} ->
      word_id = Enum.at(word_ids, idx)

      display =
        if is_meaning_question && word_id do
          # Look up word and get localized meaning
          case Medoru.Content.get_word(word_id) do
            nil -> option
            word -> Medoru.Content.get_localized_meaning(word, locale)
          end
        else
          option
        end

      {option, display}
    end)
  end

  # Check if the step question has meaning as the answer (for display localization)
  defp is_meaning_question?(step) do
    qd = step.question_data || %{}
    
    cond do
      # word_to_meaning: "What does X mean?" -> correct_answer is meaning
      String.starts_with?(step.question || "", "__MSG_WHAT_DOES_WORD_MEAN__|") -> true
      # meaning_to_word: "Which word means Y?" -> options are words, not meanings
      String.starts_with?(step.question || "", "__MSG_WHICH_WORD_MEANS__|") -> false
      # Check question_data for step type (both atom and string keys)
      qd[:step_type] == "word_to_meaning" -> true
      qd["step_type"] == "word_to_meaning" -> true
      true -> false
    end
  end

  # Translate question messages from the database
  # Now accepts step struct to look up localized meanings
  defp translate_question(nil, _locale), do: ""

  defp translate_question(step, locale) when is_map(step) do
    question = step.question || ""
    
    cond do
      String.starts_with?(question, "__MSG_WHAT_DOES_WORD_MEAN__|") ->
        case String.split(question, "|") do
          [_, word_text] -> 
            word_text
            |> localize_word_text(step.word_id, locale)
            |> then(&gettext("What does '%{word}' mean?", word: &1))
          _ -> question
        end

      String.starts_with?(question, "__MSG_HOW_DO_YOU_READ__|") ->
        case String.split(question, "|") do
          [_, word] -> gettext("How do you read '%{word}'?", word: word)
          _ -> question
        end

      String.starts_with?(question, "__MSG_WHICH_WORD_MEANS__|") ->
        case String.split(question, "|") do
          [_, _meaning] -> 
            # Look up localized meaning for the question
            meaning = get_localized_meaning_from_step(step, locale)
            gettext("Which word means '%{meaning}'?", meaning: meaning)
          _ -> question
        end

      String.starts_with?(question, "__MSG_WHICH_WORD_IS_READ__|") ->
        case String.split(question, "|") do
          [_, reading] -> gettext("Which word is read as '%{reading}'?", reading: reading)
          _ -> question
        end

      String.starts_with?(question, "__MSG_WRITE_KANJI_FOR__|") ->
        case String.split(question, "|") do
          [_, _meanings] -> 
            # Look up localized kanji meanings
            meanings = get_localized_kanji_meanings(step, locale)
            gettext("Write the kanji for '%{meanings}'", meanings: meanings)
          _ -> question
        end

      true ->
        question
    end
  end

  # Fallback for when just a string is passed
  defp translate_question(question, _locale) when is_binary(question), do: question

  # Localize word text (for questions that show word text)
  defp localize_word_text(text, nil, _locale), do: text
  defp localize_word_text(text, word_id, _locale) do
    case Medoru.Content.get_word(word_id) do
      nil -> text
      word -> word.text
    end
  end

  # Get localized meaning for a step
  defp get_localized_meaning_from_step(step, locale) do
    cond do
      step.word_id ->
        case Medoru.Content.get_word(step.word_id) do
          nil -> step.correct_answer || ""
          word -> Medoru.Content.get_localized_meaning(word, locale)
        end
      true ->
        step.correct_answer || ""
    end
  end

  # Get localized kanji meanings
  defp get_localized_kanji_meanings(step, locale) do
    # First check if kanji is already loaded on the step
    kanji = case step.kanji do
      %Ecto.Association.NotLoaded{} -> nil
      nil -> nil
      k -> k
    end
    
    # If kanji is loaded, use it directly
    if kanji do
      localized = Medoru.Content.get_localized_kanji_meanings(kanji, locale)
      
      if localized == kanji.meanings do
        # No Bulgarian translation found, use stored meanings (not kanji.meanings)
        stored = get_stored_meanings(step)
        if stored != [] do
          Enum.join(stored, ", ")
        else
          Enum.join(kanji.meanings, ", ")
        end
      else
        Enum.join(localized, ", ")
      end
    else
      # Try stored meanings first (even before looking up kanji)
      stored = get_stored_meanings(step)
      
      if stored != [] do
        # We have stored meanings, now try to localize them
        kanji_id = step.kanji_id || 
                   get_in(step.question_data || %{}, ["kanji_id"]) ||
                   get_in(step.question_data || %{}, [:kanji_id])
        
        if kanji_id do
          case Medoru.Content.get_kanji(kanji_id) do
            nil -> 
              Enum.join(stored, ", ")
            fetched_kanji ->
              localized = Medoru.Content.get_localized_kanji_meanings(fetched_kanji, locale)
              
              if localized == fetched_kanji.meanings do
                # No Bulgarian translation, use stored (same as English)
                Enum.join(stored, ", ")
              else
                Enum.join(localized, ", ")
              end
          end
        else
          Enum.join(stored, ", ")
        end
      else
        # No stored meanings, try looking up kanji
        kanji_id = step.kanji_id || 
                   get_in(step.question_data || %{}, ["kanji_id"]) ||
                   get_in(step.question_data || %{}, [:kanji_id])
        
        if kanji_id do
          case Medoru.Content.get_kanji(kanji_id) do
            nil -> 
              step.correct_answer || ""
            fetched_kanji ->
              localized = Medoru.Content.get_localized_kanji_meanings(fetched_kanji, locale)
              Enum.join(localized, ", ")
          end
        else
          step.correct_answer || ""
        end
      end
    end
  end
  
  defp get_stored_meanings(step) do
    qd = step.question_data || %{}
    
    # Debug logging
    # IO.inspect(qd, label: "question_data")
    
    meanings = get_in(qd, [:meanings]) || get_in(qd, ["meanings"]) || []
    
    # Ensure it's a list
    List.wrap(meanings)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-6">
          <.link
            navigate={~p"/classrooms/#{@classroom.id}/custom-lessons/#{@lesson.id}"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Lesson")}
          </.link>
          <h1 class="text-2xl font-bold text-base-content">
            <%= if @practice do %>
              {gettext("Practice Test: %{title}", title: @lesson.title)}
            <% else %>
              {gettext("Test: %{title}", title: @lesson.title)}
            <% end %>
          </h1>
          <p class="text-secondary mt-1">
            <%= if @practice do %>
              {gettext("Practice mode - no points will be awarded")}
            <% else %>
              {gettext("Complete the test to finish the lesson")}
            <% end %>
          </p>
        </div>

        <%= if @current_step do %>
          <%!-- Progress Bar --%>
          <% total_steps = length(@session.test.test_steps) %>
          <% completed = @session.current_step_index %>
          <div class="w-full bg-base-200 rounded-full h-2 mb-8">
            <div
              class="bg-primary h-2 rounded-full transition-all"
              style={"width: #{(completed / total_steps) * 100}%"}
            />
          </div>

          <%!-- Question Card --%>
          <div class="card bg-base-100 border border-base-300 shadow-lg">
            <div class="card-body">
              <%!-- Question --%>
              <div class="mb-6">
                <p class="text-sm text-secondary mb-2">
                  {gettext("Question %{current} of %{total}",
                    current: completed + 1,
                    total: total_steps
                  )}
                </p>
                <h2 class="text-xl font-semibold text-base-content">
                  {translate_question(@current_step, @locale)}
                </h2>
              </div>

              <%!-- Writing Step --%>
              <%= if @current_step.question_type == :writing do %>
                <MedoruWeb.LessonTestLive.WritingComponent.writing_question
                  step={@current_step}
                  target="writing-component"
                  locale={@locale}
                />
              <% else %>
                <%!-- Multichoice Options --%>
                <% localized_options = localize_options(@current_step, @locale) %>
                <div class="space-y-3 mb-6">
                  <%= for {option, display_value} <- localized_options do %>
                    <button
                      type="button"
                      phx-click="select_answer"
                      phx-value-answer={option}
                      class={[
                        "w-full text-left p-4 rounded-xl border-2 transition-all duration-200",
                        if @selected_answer == option do
                          "border-primary bg-primary/5"
                        else
                          "border-base-200 hover:border-primary/50 hover:bg-base-50"
                        end
                      ]}
                    >
                      <div class="flex items-center gap-3">
                        <div class={[
                          "w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0",
                          if @selected_answer == option do
                            "border-primary bg-primary"
                          else
                            "border-base-300"
                          end
                        ]}>
                          <%= if @selected_answer == option do %>
                            <div class="w-2 h-2 rounded-full bg-white"></div>
                          <% end %>
                        </div>
                        <span class="text-base-content font-medium">{display_value}</span>
                      </div>
                    </button>
                  <% end %>
                </div>

                <%!-- Submit Button --%>
                <button
                  type="button"
                  phx-click="submit_answer"
                  disabled={is_nil(@selected_answer)}
                  class="w-full btn btn-primary"
                >
                  {gettext("Submit Answer")}
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Feedback Toast --%>
          <%= case @feedback do %>
            <% :correct -> %>
              <div
                class="fixed bottom-6 left-1/2 -translate-x-1/2 bg-success text-success-content px-6 py-3 rounded-xl shadow-lg flex items-center gap-3 animate-in slide-in-from-bottom-2"
                phx-click="clear_feedback"
                phx-hook="AutoDismiss"
                id="feedback-toast-correct"
              >
                <.icon name="hero-check-circle" class="w-5 h-5" />
                <span class="font-medium">{gettext("Correct! Well done.")}</span>
              </div>
            <% :incorrect -> %>
              <div
                class="fixed bottom-6 left-1/2 -translate-x-1/2 bg-error text-error-content px-6 py-3 rounded-xl shadow-lg flex items-center gap-3 animate-in slide-in-from-bottom-2"
                phx-click="clear_feedback"
                phx-hook="AutoDismiss"
                id="feedback-toast-incorrect"
              >
                <.icon name="hero-x-circle" class="w-5 h-5" />
                <span class="font-medium">{gettext("Not quite. Keep going!")}</span>
              </div>
            <% _ -> %>
          <% end %>
        <% else %>
          <%!-- Test Complete --%>
          <div class="card bg-base-100 border border-base-300 shadow-lg text-center py-12">
            <.icon name="hero-check-circle" class="w-16 h-16 text-success mx-auto mb-4" />
            <h2 class="text-2xl font-bold text-base-content mb-2">
              {gettext("Test Complete!")}
            </h2>
            <p class="text-secondary mb-6">
              {gettext("Redirecting to completion page...")}
            </p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
