defmodule MedoruWeb.LessonTestLive.Show do
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Tests
  alias Medoru.Tests.LessonTestSession

  @impl true
  def mount(%{"lesson_id" => lesson_id}, session, socket) do
    # Store locale from session for validation
    locale = session["locale"] || "en"
    lesson = Content.get_lesson_with_words!(lesson_id)
    user = socket.assigns.current_scope.current_user

    # Always regenerate test to ensure fresh distractors
    # Archive old test if exists
    if lesson.test_id do
      old_test = Tests.get_test!(lesson.test_id)
      Tests.archive_test(old_test)
    end

    # Generate new test
    {:ok, test} = Tests.generate_lesson_test(lesson_id)

    # Check if user has started this lesson
    lesson_progress = Medoru.Learning.get_lesson_progress(user.id, lesson_id)

    socket =
      socket
      |> assign(:lesson, lesson)
      |> assign(:test, test)
      |> assign(:lesson_progress, lesson_progress)
      |> assign(:page_title, gettext("%{title} - Test", title: lesson.title))
      |> assign(:locale, locale)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    # Start or resume test session
    user = socket.assigns.current_scope.current_user
    test = socket.assigns.test

    case LessonTestSession.start_lesson_test(user.id, test.id) do
      {:ok, %{session: session, current_step: step}} ->
        state = LessonTestSession.get_session_state(session.id)

        socket =
          socket
          |> assign(:session, session)
          |> assign(:current_step, step)
          |> assign(:session_state, state)
          |> assign(:selected_answer, nil)
          |> assign(:meaning_answer, "")
          |> assign(:reading_answer, "")
          |> assign(:feedback, nil)
          |> assign(:show_hint, false)
          |> assign(:show_stroke_preview, false)
          |> assign(:preview_kanji, nil)
          |> assign(:meaning_error, false)
          |> assign(:reading_error, false)
          |> assign(:correct_meaning, nil)
          |> assign(:correct_reading, nil)
          |> assign(:next_step_after_correction, nil)

        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Could not start test: %{reason}", reason: inspect(reason)))
         |> push_navigate(to: ~p"/lessons/#{socket.assigns.lesson.id}")}
    end
  end

  @impl true
  def handle_event("select_answer", %{"answer" => answer}, socket) do
    {:noreply, assign(socket, :selected_answer, answer)}
  end

  @impl true
  def handle_event("update_meaning", params, socket) do
    value = Map.get(params, "meaning_answer", params["value"] || "")
    {:noreply, assign(socket, :meaning_answer, value)}
  end

  @impl true
  def handle_event("update_reading", params, socket) do
    value = Map.get(params, "reading_answer", params["value"] || "")
    {:noreply, assign(socket, :reading_answer, value)}
  end

  @impl true
  def handle_event("submit_answer", _params, socket) do
    answer = socket.assigns.selected_answer

    if is_nil(answer) do
      {:noreply, put_flash(socket, :error, gettext("Please select an answer"))}
    else
      session = socket.assigns.session
      step = socket.assigns.current_step

      # Submit answer
      case LessonTestSession.submit_answer(session.id, step.id, answer, time_spent_seconds: 10) do
        {:correct, result} ->
          socket =
            socket
            |> assign(:feedback, :correct)
            |> assign(:session, result.session)
            |> assign(:current_step, result.next_step)
            |> assign(:session_state, LessonTestSession.get_session_state(result.session.id))
            |> assign(:selected_answer, nil)
            |> assign(:show_hint, false)

          {:noreply, socket}

        {:incorrect, result} ->
          socket =
            socket
            |> assign(:feedback, :incorrect)
            |> assign(:session, result.session)
            |> assign(:current_step, result.next_step)
            |> assign(:session_state, LessonTestSession.get_session_state(result.session.id))
            |> assign(:selected_answer, nil)
            |> assign(:show_hint, false)

          {:noreply, socket}

        {:completed, result} ->
          # Mark lesson as completed
          Medoru.Learning.complete_lesson(
            socket.assigns.current_scope.current_user.id,
            socket.assigns.lesson.id
          )

          {:noreply,
           socket
           |> assign(:completed, true)
           |> assign(:result, result)
           |> push_navigate(to: ~p"/lessons/#{socket.assigns.lesson.id}/test/complete")}
      end
    end
  end

  @impl true
  def handle_event("submit_reading_text", _params, socket) do
    meaning = String.trim(socket.assigns.meaning_answer)
    reading = String.trim(socket.assigns.reading_answer)

    # Validate inputs are not empty
    if meaning == "" or reading == "" do
      {:noreply, put_flash(socket, :error, gettext("Please enter both meaning and reading"))}
    else
      session = socket.assigns.session
      step = socket.assigns.current_step

      # Submit reading text answer with locale
      locale = socket.assigns.locale

      case LessonTestSession.submit_reading_text_answer(
             session.id,
             step.id,
             meaning,
             reading,
             time_spent_seconds: 15,
             locale: locale
           ) do
        {:correct, result} ->
          socket =
            socket
            |> assign(:feedback, :correct)
            |> assign(:session, result.session)
            |> assign(:current_step, result.next_step)
            |> assign(:session_state, LessonTestSession.get_session_state(result.session.id))
            |> assign(:meaning_answer, "")
            |> assign(:reading_answer, "")
            |> assign(:show_hint, false)
            |> assign(:meaning_error, false)
            |> assign(:reading_error, false)
            |> assign(:correct_meaning, nil)
            |> assign(:correct_reading, nil)
            |> assign(:next_step_after_correction, nil)

          {:noreply, socket}

        {:incorrect, result} ->
          # Don't advance to next_step yet - show the correction first
          # Keep current_step as the one they got wrong so they can see the correct answer
          # next_step will be assigned when they click Continue
          socket =
            socket
            |> assign(:feedback, :incorrect)
            |> assign(:session, result.session)
            |> assign(:session_state, LessonTestSession.get_session_state(result.session.id))
            |> assign(:meaning_answer, "")
            |> assign(:reading_answer, "")
            |> assign(:show_hint, false)
            |> assign(:meaning_error, !result.wrong_answer.meaning_correct)
            |> assign(:reading_error, !result.wrong_answer.reading_correct)
            |> assign(:correct_meaning, result.correct_meaning)
            |> assign(:correct_reading, result.correct_reading)
            |> assign(:next_step_after_correction, result.next_step)

          {:noreply, socket}

        {:completed, result} ->
          Medoru.Learning.complete_lesson(
            socket.assigns.current_scope.current_user.id,
            socket.assigns.lesson.id
          )

          {:noreply,
           socket
           |> assign(:completed, true)
           |> assign(:result, result)
           |> push_navigate(to: ~p"/lessons/#{socket.assigns.lesson.id}/test/complete")}
      end
    end
  end

  @impl true
  def handle_event("show_hint", _params, socket) do
    {:noreply, assign(socket, :show_hint, true)}
  end

  @impl true
  def handle_event("skip_question", _params, socket) do
    session = socket.assigns.session
    step = socket.assigns.current_step

    {:ok, result} = LessonTestSession.skip_step(session.id, step.id)

    socket =
      socket
      |> assign(:current_step, result.next_step)
      |> assign(:session_state, LessonTestSession.get_session_state(session.id))
      |> assign(:selected_answer, nil)
      |> assign(:meaning_answer, "")
      |> assign(:reading_answer, "")
      |> assign(:show_hint, false)
      |> assign(:feedback, nil)
      |> assign(:meaning_error, false)
      |> assign(:reading_error, false)
      |> assign(:correct_meaning, nil)
      |> assign(:correct_reading, nil)
      |> assign(:next_step_after_correction, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_feedback", _params, socket) do
    {:noreply, clear_feedback(socket)}
  end

  @impl true
  def handle_event("continue_after_correction", _params, socket) do
    # After showing the correction, advance to the next step
    next_step = socket.assigns.next_step_after_correction

    socket =
      socket
      |> assign(:current_step, next_step)
      |> assign(:session_state, LessonTestSession.get_session_state(socket.assigns.session.id))
      |> assign(:feedback, nil)
      |> assign(:show_hint, false)
      |> assign(:meaning_error, false)
      |> assign(:reading_error, false)
      |> assign(:correct_meaning, nil)
      |> assign(:correct_reading, nil)
      |> assign(:next_step_after_correction, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("stroke_correct", _params, socket) do
    # KanjiWriter library validated stroke as correct
    {:noreply, socket}
  end

  @impl true
  def handle_event("stroke_incorrect", _params, socket) do
    # KanjiWriter library cleared the stroke automatically
    # Just show a brief hint
    {:noreply, put_flash(socket, :error, gettext("Try again - follow the red guide"))}
  end

  @impl true
  def handle_event("kanji_complete", _params, socket) do
    # All strokes completed correctly on client side - submit as correct answer
    session = socket.assigns.session
    step = socket.assigns.current_step

    # Submit as correct answer (explicitly mark as correct for writing questions)
    submit_result =
      LessonTestSession.submit_writing_answer(
        session.id,
        step.id,
        %{"completed" => true},
        time_spent_seconds: 15,
        is_correct: true
      )

    handle_submit_result(submit_result, step, socket)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => true}, socket) do
    # Submit button clicked when kanji is complete - treat same as kanji_complete
    handle_event("kanji_complete", %{}, socket)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => false}, socket) do
    # User gave up or skipped - mark as incorrect and show correct answer
    session = socket.assigns.session
    step = socket.assigns.current_step

    # Submit as incorrect answer
    submit_result =
      LessonTestSession.submit_writing_answer(
        session.id,
        step.id,
        %{"completed" => false},
        time_spent_seconds: 30,
        is_correct: false
      )

    handle_submit_result(submit_result, step, socket)
  end

  @impl true
  def handle_event("submit_writing", %{"strokes" => _strokes} = params, socket) do
    # Manual submit with strokes data
    session = socket.assigns.session
    step = socket.assigns.current_step

    # Validate writing
    submit_result =
      if step.question_type == :writing do
        LessonTestSession.submit_writing_answer(
          session.id,
          step.id,
          params,
          time_spent_seconds: 30
        )
      else
        # Fallback for non-writing steps
        LessonTestSession.submit_answer(session.id, step.id, "written", time_spent_seconds: 30)
      end

    handle_submit_result(submit_result, step, socket)
  end

  # Handle submit result (shared between manual submit and auto-submit on complete)
  @impl true
  def handle_event("hide_stroke_preview", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_stroke_preview, false)
     |> assign(:preview_kanji, nil)}
  end

  defp clear_feedback(socket) do
    socket
    |> assign(:feedback, nil)
    |> assign(:meaning_error, false)
    |> assign(:reading_error, false)
    |> assign(:correct_meaning, nil)
    |> assign(:correct_reading, nil)
  end

  defp handle_submit_result(submit_result, step, socket) do
    case submit_result do
      {:correct, result} ->
        socket =
          socket
          |> assign(:feedback, :correct)
          |> assign(:session, result.session)
          |> assign(:current_step, result.next_step)
          |> assign(:session_state, LessonTestSession.get_session_state(result.session.id))
          |> assign(:show_stroke_preview, false)
          |> assign(:preview_kanji, nil)

        {:noreply, socket}

      {:incorrect, result} ->
        # Load kanji for stroke preview
        kanji =
          if step.kanji_id do
            Medoru.Content.get_kanji!(step.kanji_id)
          else
            nil
          end

        socket =
          socket
          |> assign(:feedback, :incorrect)
          |> assign(:session, result.session)
          |> assign(:current_step, result.next_step)
          |> assign(:session_state, LessonTestSession.get_session_state(result.session.id))
          |> assign(:show_stroke_preview, true)
          |> assign(:preview_kanji, kanji)

        {:noreply, socket}

      {:completed, result} ->
        Medoru.Learning.complete_lesson(
          socket.assigns.current_scope.current_user.id,
          socket.assigns.lesson.id
        )

        {:noreply,
         socket
         |> assign(:completed, true)
         |> assign(:result, result)
         |> push_navigate(to: ~p"/lessons/#{socket.assigns.lesson.id}/test/complete")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <div class="mb-4">
            <.link
              navigate={~p"/lessons/#{@lesson.id}"}
              class="inline-flex items-center justify-center gap-2 w-full sm:w-auto px-4 py-3 border-2 border-base-300 bg-base-100 hover:bg-base-200 text-base-content rounded-xl font-medium transition-colors"
            >
              <.icon name="hero-arrow-left" class="w-5 h-5" />
              {gettext("Back to Lesson")}
            </.link>
          </div>
          <h1 class="text-2xl font-bold text-base-content">{@lesson.title} - Test</h1>
          <p class="text-secondary mt-1">
            {gettext("Test your knowledge of the words in this lesson")}
          </p>
        </div>

        <%!-- Progress Bar --%>
        <div class="mb-8">
          <div class="flex justify-between text-sm mb-2">
            <span class="text-secondary">
              {gettext("Question %{current} of %{total}",
                current: @session_state.completed_steps + 1,
                total: @session_state.total_steps
              )}
            </span>
            <span class="text-secondary">{@session_state.progress}{gettext("% complete")}</span>
          </div>
          <div class="h-2 bg-base-200 rounded-full overflow-hidden">
            <div
              class="h-full bg-primary transition-all duration-300"
              style={"width: #{@session_state.progress}%"}
            >
            </div>
          </div>
          <%= if @session_state.wrong_answer_count > 0 do %>
            <div class="text-sm text-warning mt-1">
              {gettext("Retries:")} {@session_state.wrong_answer_count}
            </div>
          <% end %>
        </div>

        <%!-- Question Card --%>
        <%= if @current_step do %>
          <div class="bg-base-100 rounded-2xl shadow-sm border border-base-200 p-6 mb-6">
            <%!-- Show stroke preview after wrong answer --%>
            <%= if @show_stroke_preview && @preview_kanji do %>
              <MedoruWeb.LessonTestLive.WritingComponent.stroke_preview kanji={@preview_kanji} />
            <% else %>
              <%!-- Question --%>
              <div class="mb-6">
                <h2 class="text-xl font-semibold text-base-content leading-relaxed">
                  <%= if @current_step.question_type == :writing do %>
                    <div class="flex items-center gap-2 text-primary">
                      <.icon name="hero-pencil" class="w-6 h-6" />
                      <span>{gettext("Writing Challenge (5 points)")}</span>
                    </div>
                  <% end %>
                  {translate_question(@current_step.question)}
                </h2>
              </div>

              <%!-- Hint --%>
              <%= if @show_hint && List.first(@current_step.hints) do %>
                <div class="bg-info/10 text-info rounded-lg p-3 mb-4">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-light-bulb" class="w-5 h-5" />
                    <span>{List.first(@current_step.hints)}</span>
                  </div>
                </div>
              <% end %>

              <%!-- Writing Step --%>
              <%= if @current_step.question_type == :writing do %>
                <MedoruWeb.LessonTestLive.WritingComponent.writing_question
                  step={@current_step}
                  target="writing-component"
                />
              <% end %>

              <%!-- Reading Text Step --%>
              <%= if @current_step.question_type == :reading_text do %>
                <MedoruWeb.LessonTestLive.ReadingTextComponent.reading_text_question
                  step={@current_step}
                  meaning_answer={@meaning_answer}
                  reading_answer={@reading_answer}
                  feedback={@feedback}
                  show_hint={@show_hint}
                  meaning_error={@meaning_error}
                  reading_error={@reading_error}
                  correct_meaning={@correct_meaning}
                  correct_reading={@correct_reading}
                />
              <% end %>

              <%!-- Multichoice Step --%>
              <%= if @current_step.question_type == :multichoice do %>
                <%!-- Answer Options for Multichoice --%>
                <div class="space-y-3 mb-6">
                  <%= for option <- @current_step.options do %>
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
                          "w-6 h-6 rounded-full border-2 flex items-center justify-center",
                          if @selected_answer == option do
                            "border-primary bg-primary"
                          else
                            "border-base-300"
                          end
                        ]}>
                          <%= if @selected_answer == option do %>
                            <div class="w-2.5 h-2.5 rounded-full bg-white"></div>
                          <% end %>
                        </div>
                        <span class="text-base-content font-medium">{option}</span>
                      </div>
                    </button>
                  <% end %>
                </div>
              <% end %>
            <% end %>

            <%!-- Actions --%>
            <div class="flex flex-col sm:flex-row gap-3">
              <%= if @current_step.question_type == :multichoice do %>
                <button
                  type="button"
                  phx-click="submit_answer"
                  disabled={is_nil(@selected_answer)}
                  class="w-full sm:w-auto px-6 py-3 bg-primary text-primary-content rounded-xl font-medium hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors min-h-[48px]"
                >
                  {gettext("Submit Answer")}
                </button>

                <%= if @current_step.question_type == :writing and !@show_hint do %>
                  <button
                    type="button"
                    phx-click="show_hint"
                    class="w-full sm:w-auto px-4 py-3 bg-info/10 hover:bg-info/20 text-info rounded-xl transition-colors flex items-center justify-center gap-2 min-h-[48px]"
                  >
                    <.icon name="hero-light-bulb" class="w-5 h-5" />
                    <span>{gettext("Hint")}</span>
                  </button>
                <% end %>

                <button
                  type="button"
                  phx-click="skip_question"
                  class="w-full sm:w-auto sm:ml-auto px-4 py-3 bg-base-200 hover:bg-base-300 text-base-content rounded-xl transition-colors min-h-[48px]"
                >
                  {gettext("Skip →")}
                </button>
              <% end %>

              <%= if @current_step.question_type == :reading_text && @feedback != :incorrect do %>
                <button
                  type="button"
                  phx-click="submit_reading_text"
                  disabled={@meaning_answer == "" or @reading_answer == ""}
                  class="w-full sm:w-auto px-6 py-3 bg-primary text-primary-content rounded-xl font-medium hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors min-h-[48px]"
                >
                  {gettext("Submit Answer")}
                </button>

                <%= if @current_step.question_type == :writing and !@show_hint do %>
                  <button
                    type="button"
                    phx-click="show_hint"
                    class="w-full sm:w-auto px-4 py-3 bg-info/10 hover:bg-info/20 text-info rounded-xl transition-colors flex items-center justify-center gap-2 min-h-[48px]"
                  >
                    <.icon name="hero-light-bulb" class="w-5 h-5" />
                    <span>{gettext("Hint")}</span>
                  </button>
                <% end %>

                <button
                  type="button"
                  phx-click="skip_question"
                  class="w-full sm:w-auto sm:ml-auto px-4 py-3 bg-base-200 hover:bg-base-300 text-base-content rounded-xl transition-colors min-h-[48px]"
                >
                  {gettext("Skip →")}
                </button>
              <% end %>

              <%= if @current_step.question_type == :reading_text && @feedback == :incorrect do %>
                <button
                  type="button"
                  phx-click="continue_after_correction"
                  class="px-6 py-3 bg-primary text-primary-content rounded-xl font-medium hover:bg-primary/90 transition-colors"
                >
                  {gettext("Continue →")}
                </button>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="bg-base-100 rounded-2xl shadow-sm border border-base-200 p-8 text-center">
            <.icon name="hero-check-circle" class="w-16 h-16 text-success mx-auto mb-4" />
            <h2 class="text-2xl font-bold text-base-content mb-2">{gettext("Test Complete!")}</h2>
            <p class="text-secondary mb-6">
              {gettext("You've completed all questions in this lesson test.")}
            </p>
            <.link
              navigate={~p"/lessons/#{@lesson.id}"}
              class="inline-flex items-center gap-2 px-6 py-3 bg-primary text-primary-content rounded-xl font-medium hover:bg-primary/90 transition-colors"
            >
              {gettext("Back to Lesson")}
            </.link>
          </div>
        <% end %>

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
              <span class="font-medium">{gettext("Not quite. Try again later!")}</span>
            </div>
          <% _ -> %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # Convert stroke points from JSON format to tuples

  # Translate question text, handling message key format
  defp translate_question(nil), do: ""

  defp translate_question("__MSG_WRITE_KANJI_FOR__|" <> meanings) do
    gettext("Write the kanji for '%{meanings}'", meanings: meanings)
  end

  defp translate_question("__MSG_WHICH_WORD_MEANS__|" <> meaning) do
    gettext("Which word means '%{meaning}'?", meaning: meaning)
  end

  defp translate_question("__MSG_WHICH_WORD_IS_READ__|" <> reading) do
    gettext("Which word is read as '%{reading}'?", reading: reading)
  end

  defp translate_question("__MSG_WHAT_DOES_WORD_MEAN__|" <> word) do
    gettext("What does '%{word}' mean?", word: word)
  end

  defp translate_question("__MSG_HOW_DO_YOU_READ__|" <> word) do
    gettext("How do you read '%{word}'?", word: word)
  end

  defp translate_question("__MSG_TYPE_MEANING_AND_READING__|" <> word) do
    gettext("Type the meaning and reading for '%{word}'", word: word)
  end

  defp translate_question(question), do: question
end
