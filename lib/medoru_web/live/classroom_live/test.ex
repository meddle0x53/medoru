defmodule MedoruWeb.ClassroomLive.Test do
  @moduledoc """
  LiveView for students to take a published test from a classroom.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.Tests

  @impl true
  def mount(%{"id" => classroom_id, "test_id" => test_id}, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Verify user is an approved member of the classroom
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
          load_test_session(socket, classroom_id, test_id, user)
        end
    end
  end

  defp load_test_session(socket, classroom_id, test_id, user) do
    # Verify test is published to this classroom
    classroom_test = Classrooms.get_classroom_test(classroom_id, test_id)

    cond do
      is_nil(classroom_test) || classroom_test.status != :active ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This test is not available in this classroom."))
         |> push_navigate(to: ~p"/classrooms/#{classroom_id}")}

      true ->
        # Check for existing attempt
        existing_attempt = Classrooms.get_test_attempt(classroom_id, user.id, test_id)

        cond do
          # Has an in-progress attempt - resume it
          existing_attempt && existing_attempt.status == "in_progress" ->
            resume_test_session(
              socket,
              existing_attempt,
              classroom_test,
              classroom_id,
              test_id,
              user
            )

          # Has a completed attempt and can't retake
          existing_attempt && existing_attempt.status in ["completed", "timed_out"] &&
              existing_attempt.reset_count == 0 ->
            {:ok,
             socket
             |> put_flash(:info, gettext("You have already completed this test."))
             |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}

          # Can start new attempt (no existing or was reset)
          true ->
            start_new_test_session(socket, classroom_test, classroom_id, test_id, user)
        end
    end
  end

  defp resume_test_session(socket, attempt, _classroom_test, classroom_id, test_id, user) do
    test = Tests.get_test!(test_id)
    classroom = Classrooms.get_classroom!(classroom_id)

    # Check if we have a valid session to resume
    session =
      if attempt.test_session_id do
        Tests.get_test_session(attempt.test_session_id)
      else
        nil
      end

    if is_nil(session) do
      # No session - start a new one for this reset attempt
      # First link the attempt to a new session
      case Tests.start_test_session(user.id, test_id) do
        {:ok, new_session} ->
          # Update attempt with new session
          {:ok, updated_attempt} =
            attempt
            |> Ecto.Changeset.change(test_session_id: new_session.id)
            |> Medoru.Repo.update()

          steps = Tests.list_test_steps(test_id)
          first_step = List.first(steps)

          {:ok,
           socket
           |> assign(:page_title, test.title)
           |> assign(:classroom, classroom)
           |> assign(:test, test)
           |> assign(:attempt, updated_attempt)
           |> assign(:session, new_session)
           |> assign(:steps, steps)
           |> assign(:current_step_index, 0)
           |> assign(:current_step, first_step)
           |> assign(:total_steps, length(steps))
           |> assign(:time_remaining, updated_attempt.time_remaining_seconds)
           |> assign(:answer, initial_answer_for_step(first_step))
           |> assign(:show_hint, false)}

        {:error, _} ->
          {:ok,
           socket
           |> put_flash(:error, gettext("Failed to start test session."))
           |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}
      end
    else
      steps = Tests.list_test_steps(test_id)

      # Calculate current step index from session
      current_step_index = session.current_step_index || 0
      current_step = Enum.at(steps, current_step_index)

      {:ok,
       socket
       |> assign(:page_title, test.title)
       |> assign(:classroom, classroom)
       |> assign(:test, test)
       |> assign(:attempt, attempt)
       |> assign(:session, session)
       |> assign(:steps, steps)
       |> assign(:current_step_index, current_step_index)
       |> assign(:current_step, current_step)
       |> assign(:total_steps, length(steps))
       |> assign(:time_remaining, attempt.time_remaining_seconds)
       |> assign(:answer, initial_answer_for_step(current_step))
       |> assign(:show_hint, false)}
    end
  end

  defp start_new_test_session(socket, classroom_test, classroom_id, test_id, user) do
    test = Tests.get_test!(test_id)
    classroom = Classrooms.get_classroom!(classroom_id)

    # Use classroom test settings or fall back to test defaults
    time_limit = classroom_test.max_attempts || test.time_limit_seconds

    # Start a new test attempt
    case Classrooms.start_test_attempt(
           classroom_id,
           user.id,
           test_id,
           time_limit || 3600,
           test.total_points
         ) do
      {:ok, attempt} ->
        # Create a test session for the attempt
        case Tests.start_test_session(user.id, test_id) do
          {:ok, session} ->
            # Link attempt to session and reload
            {:ok, updated_attempt} =
              attempt
              |> Ecto.Changeset.change(test_session_id: session.id)
              |> Medoru.Repo.update()

            steps = Tests.list_test_steps(test_id)
            first_step = List.first(steps)

            {:ok,
             socket
             |> assign(:page_title, test.title)
             |> assign(:classroom, classroom)
             |> assign(:test, test)
             |> assign(:attempt, updated_attempt)
             |> assign(:session, session)
             |> assign(:steps, steps)
             |> assign(:current_step_index, 0)
             |> assign(:current_step, first_step)
             |> assign(:total_steps, length(steps))
             |> assign(:time_remaining, updated_attempt.time_remaining_seconds)
             |> assign(:answer, initial_answer_for_step(first_step))
             |> assign(:show_hint, false)}

          {:error, _} ->
            {:ok,
             socket
             |> put_flash(:error, gettext("Failed to start test session."))
             |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}
        end

      {:error, :already_attempted} ->
        {:ok,
         socket
         |> put_flash(:info, gettext("You have already taken this test."))
         |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Failed to start test."))
         |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}
    end
  end

  # Helper function to initialize answer based on step type
  defp initial_answer_for_step(nil), do: ""
  defp initial_answer_for_step(%{question_type: :fill}), do: %{"meaning" => "", "reading" => ""}
  defp initial_answer_for_step(_), do: ""

  @impl true
  def handle_event("submit_answer", %{"answer" => "skipped"}, socket) do
    # User skipped a writing question - mark as incorrect
    submit_writing_answer(socket, false, 0.0)
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer_map}, socket) when is_map(answer_map) do
    # Handle fill question with meaning and optional reading
    step = socket.assigns.current_step
    session = socket.assigns.session
    attempt = socket.assigns.attempt

    # Extract values from form
    meaning = answer_map["meaning"]
    reading = answer_map["reading"]

    # Check if reading is required for this step
    include_reading = get_in(step.question_data, ["include_reading"]) || false

    # Validate answers
    correct_meaning = step.correct_answer
    correct_reading = get_in(step.question_data, ["reading_answer"]) || ""

    meaning_correct = validate_meaning(meaning, correct_meaning)
    reading_correct = if reading, do: validate_reading(reading, correct_reading), else: false

    # Calculate points based on include_reading flag
    # If reading is included: 2 points for meaning, 1 point for reading
    # If reading is NOT included: 2 points for meaning only
    points_earned =
      cond do
        include_reading and meaning_correct and reading_correct -> 3
        include_reading and meaning_correct -> 2
        include_reading and reading_correct -> 1
        not include_reading and meaning_correct -> 2
        true -> 0
      end

    # Record the answer
    answer_text = if include_reading and reading, do: "#{meaning} / #{reading}", else: meaning

    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => answer_text,
        "time_spent_seconds" => 30,
        "step_index" => step.order_index,
        "is_correct" => meaning_correct and (not include_reading or reading_correct),
        "points_earned" => points_earned,
        "metadata" => %{
          "meaning" => meaning,
          "reading" => reading,
          "meaning_correct" => meaning_correct,
          "reading_correct" => reading_correct,
          "correct_meaning" => correct_meaning,
          "correct_reading" => correct_reading,
          "include_reading" => include_reading
        }
      })

    case result do
      {:ok, _step_answer} ->
        # Update attempt progress
        Classrooms.update_test_progress(attempt.id, %{
          score: points_earned,
          time_spent_seconds: attempt.time_spent_seconds + 30
        })

        # Move to next step or complete
        next_index = socket.assigns.current_step_index + 1

        if next_index >= socket.assigns.total_steps do
          # Complete the test
          complete_test(socket, session.id, attempt.id)
        else
          # Update session progress for resume functionality
          Tests.update_session_progress(session.id, next_index)

          next_step = Enum.at(socket.assigns.steps, next_index)

          {:noreply,
           socket
           |> assign(:current_step_index, next_index)
           |> assign(:current_step, next_step)
           |> assign(:answer, initial_answer_for_step(next_step))
           |> assign(:show_hint, false)}
        end

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer: #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    step = socket.assigns.current_step
    session = socket.assigns.session
    attempt = socket.assigns.attempt

    # Record the answer
    result =
      Tests.record_step_answer(session.id, step.id, %{
        "answer" => answer,
        "time_spent_seconds" => 30,
        "step_index" => step.order_index
      })

    case result do
      {:ok, step_answer} ->
        # Update attempt progress
        Classrooms.update_test_progress(attempt.id, %{
          score: step_answer.points_earned,
          time_spent_seconds: attempt.time_spent_seconds + 30
        })

        # Move to next step or complete
        next_index = socket.assigns.current_step_index + 1

        if next_index >= socket.assigns.total_steps do
          # Complete the test
          complete_test(socket, session.id, attempt.id)
        else
          # Update session progress for resume functionality
          Tests.update_session_progress(session.id, next_index)

          next_step = Enum.at(socket.assigns.steps, next_index)

          {:noreply,
           socket
           |> assign(:current_step_index, next_index)
           |> assign(:current_step, next_step)
           |> assign(:answer, initial_answer_for_step(next_step))
           |> assign(:show_hint, false)}
        end

      {:error, changeset} ->
        require Logger
        Logger.error("Failed to submit answer (other): #{inspect(changeset.errors)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to submit answer. Please try again."))}
    end
  end

  @impl true
  def handle_event("show_hint", _, socket) do
    {:noreply, assign(socket, :show_hint, true)}
  end

  @impl true
  def handle_event("time_up", _, socket) do
    # Timer ran out - auto-submit the test
    auto_submit_test(socket)
  end

  @impl true
  def handle_event("sync_time", %{"time_remaining" => time_remaining}, socket) do
    # Periodic sync from client-side timer - update DB but don't re-render
    attempt = socket.assigns.attempt

    Task.start(fn ->
      Classrooms.update_test_progress(attempt.id, %{
        time_remaining_seconds: time_remaining
      })
    end)

    # Silently update server state without triggering re-render
    {:noreply, socket}
  end

  @impl true
  def handle_event("kanji_complete", _params, socket) do
    # All strokes drawn correctly - submit as correct answer
    submit_writing_answer(socket, true, 1.0)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => true}, socket) do
    # Submit button clicked when kanji is complete - treat same as kanji_complete
    handle_event("kanji_complete", %{}, socket)
  end

  @impl true
  def handle_event("submit_writing", %{"completed" => false}, socket) do
    # User gave up or skipped - mark as incorrect
    submit_writing_answer(socket, false, 0.0)
  end

  @impl true
  def handle_event("stroke_incorrect", _params, socket) do
    # KanjiWriter library cleared the stroke automatically
    {:noreply, put_flash(socket, :error, gettext("Try again - follow the red guide"))}
  end

  defp submit_writing_answer(socket, correct, accuracy) do
    step = socket.assigns.current_step
    session = socket.assigns.session
    attempt = socket.assigns.attempt

    # Check if answer already exists for this step (prevent double submission)
    existing_answers = Tests.list_test_step_answers(session.id, step.id)

    if length(existing_answers) > 0 do
      # Already answered - just move to next step without error
      next_index = socket.assigns.current_step_index + 1

      if next_index >= socket.assigns.total_steps do
        complete_test(socket, session.id, attempt.id)
      else
        next_step = Enum.at(socket.assigns.steps, next_index)

        {:noreply,
         socket
         |> assign(:current_step_index, next_index)
         |> assign(:current_step, next_step)
         |> assign(:answer, initial_answer_for_step(next_step))
         |> assign(:show_hint, false)}
      end
    else
      answer_text = if correct, do: "correct", else: "partial"

      result =
        Tests.record_step_answer(session.id, step.id, %{
          "answer" => answer_text,
          "time_spent_seconds" => 45,
          "step_index" => step.order_index,
          "is_correct" => correct,
          "metadata" => %{"accuracy" => accuracy, "writing" => true}
        })

      case result do
        {:ok, step_answer} ->
          Classrooms.update_test_progress(attempt.id, %{
            score: step_answer.points_earned,
            time_spent_seconds: attempt.time_spent_seconds + 45
          })

          next_index = socket.assigns.current_step_index + 1

          if next_index >= socket.assigns.total_steps do
            complete_test(socket, session.id, attempt.id)
          else
            next_step = Enum.at(socket.assigns.steps, next_index)

            {:noreply,
             socket
             |> assign(:current_step_index, next_index)
             |> assign(:current_step, next_step)
             |> assign(:answer, initial_answer_for_step(next_step))
             |> assign(:show_hint, false)}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to submit answer."))}
      end
    end
  end

  defp complete_test(socket, session_id, attempt_id) do
    # Calculate final score
    {score, max_score} = Tests.calculate_session_score(session_id)

    # Complete the attempt
    attrs = %{
      test_session_id: session_id,
      score: score,
      max_score: max_score,
      points_earned: score,
      time_spent_seconds:
        socket.assigns.attempt.time_limit_seconds - socket.assigns.time_remaining,
      time_remaining_seconds: socket.assigns.time_remaining
    }

    case Classrooms.complete_test_attempt(attempt_id, attrs) do
      {:ok, _attempt} ->
        {:noreply,
         socket
         |> push_navigate(
           to:
             ~p"/classrooms/#{socket.assigns.classroom.id}/tests/#{socket.assigns.test.id}/results"
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to complete test.")}
    end
  end

  defp auto_submit_test(socket) do
    session = socket.assigns.session
    attempt = socket.assigns.attempt

    {score, max_score} = Tests.calculate_session_score(session.id)

    attrs = %{
      test_session_id: session.id,
      score: score,
      max_score: max_score,
      points_earned: score,
      time_spent_seconds: attempt.time_limit_seconds,
      time_remaining_seconds: 0,
      auto_submitted: true
    }

    case Classrooms.complete_test_attempt(attempt.id, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:warning, gettext("Time's up! Your test was auto-submitted."))
         |> push_navigate(
           to:
             ~p"/classrooms/#{socket.assigns.classroom.id}/tests/#{socket.assigns.test.id}/results"
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to submit test.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-3 sm:px-4 py-4 sm:py-8">
        <%!-- Header - Mobile Optimized --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-4 mb-4 sm:mb-8">
          <div class="flex-1 min-w-0">
            <.link
              navigate={~p"/classrooms/#{@classroom.id}?tab=tests"}
              class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-1 sm:mb-2 transition-colors"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Tests")}
            </.link>
            <h1 class="text-xl sm:text-2xl font-bold text-base-content truncate">{@test.title}</h1>
            <p class="text-secondary text-xs sm:text-sm">{@classroom.name}</p>
          </div>

          <%!-- Timer - updated by JS hook to avoid re-rendering form --%>
          <div class="flex items-center gap-2 bg-base-200 px-3 sm:px-4 py-2 rounded-lg self-start sm:self-auto shrink-0">
            <.icon name="hero-clock" class="w-4 h-4 sm:w-5 sm:h-5 text-secondary" />
            <span
              id="timer-display"
              class="font-mono text-base sm:text-lg font-bold text-base-content"
              phx-update="ignore"
            >
              {format_time(@time_remaining)}
            </span>
          </div>
        </div>

        <%!-- Progress Bar --%>
        <div class="mb-4 sm:mb-8">
          <div class="flex justify-between text-xs sm:text-sm text-secondary mb-1 sm:mb-2">
            <span>
              {gettext("Question %{current} of %{total}",
                current: @current_step_index + 1,
                total: @total_steps
              )}
            </span>
            <span>
              {format_percentage((@current_step_index + 1) / @total_steps * 100)}%{gettext(" complete")}
            </span>
          </div>
          <div class="h-1.5 sm:h-2 bg-base-200 rounded-full overflow-hidden">
            <div
              class="h-full bg-primary transition-all duration-300"
              style={"width: #{((@current_step_index + 1) / @total_steps) * 100}%"}
            />
          </div>
        </div>

        <%!-- Question Card --%>
        <div class="card bg-base-100 border border-base-300 shadow-lg">
          <div class="card-body p-4 sm:p-6">
            <%= if @current_step do %>
              <div class="mb-4 sm:mb-6">
                <span class="badge badge-outline badge-xs sm:badge-sm mb-2 sm:mb-4">
                  {@current_step.question_type
                  |> to_string()
                  |> String.replace("_", " ")
                  |> String.capitalize()}
                </span>
                <h2 class="text-lg sm:text-xl font-medium text-base-content leading-relaxed">
                  {@current_step.question}
                </h2>
              </div>

              <%!-- Answer Input --%>
              <form phx-submit="submit_answer" class="space-y-4">
                <%= case @current_step.question_type do %>
                  <% :multichoice -> %>
                    <div class="space-y-2">
                      <%= for option <- @current_step.options do %>
                        <label class="flex items-center gap-3 p-4 bg-base-200 rounded-lg cursor-pointer hover:bg-base-300 transition-colors">
                          <input
                            type="radio"
                            name="answer"
                            value={option}
                            required
                            class="radio radio-primary"
                          />
                          <span class="text-base-content">{option}</span>
                        </label>
                      <% end %>
                    </div>
                  <% :writing -> %>
                    <MedoruWeb.LessonTestLive.WritingComponent.writing_question
                      step={@current_step}
                      target="writing-component"
                    />
                    <%!-- Hidden input for form submission when skipping --%>
                    <input type="hidden" name="answer" value="skipped" />
                  <% :fill -> %>
                    <div class="space-y-4" id={"fill-inputs-#{@current_step.id}"}>
                      <%!-- Hidden field to ensure answer is always a map --%>
                      <input type="hidden" name="answer[_dummy]" value="1" />
                      <div>
                        <label class="block text-sm font-medium text-base-content mb-2">
                          {gettext("Meaning (in English):")}
                        </label>
                        <.input
                          type="text"
                          name="answer[meaning]"
                          id={"answer-meaning-#{@current_step.id}"}
                          value={@answer["meaning"] || ""}
                          placeholder={gettext("Type the meaning...")}
                          class="w-full"
                        />
                      </div>
                      <%= if @current_step.question_data && @current_step.question_data["include_reading"] do %>
                        <div>
                          <label class="block text-sm font-medium text-base-content mb-2">
                            {gettext("Reading (in Hiragana):")}
                          </label>
                          <.input
                            type="text"
                            name="answer[reading]"
                            id={"answer-reading-#{@current_step.id}"}
                            value={@answer["reading"] || ""}
                            placeholder={gettext("Type the hiragana reading...")}
                            class="w-full"
                          />
                        </div>
                      <% end %>
                    </div>
                  <% _ -> %>
                    <.input
                      type="text"
                      name="answer"
                      value={@answer}
                      placeholder={gettext("Type your answer...")}
                      required
                      class="w-full"
                    />
                <% end %>

                <%!-- Hint --%>
                <%= if @show_hint && @current_step.hints != [] do %>
                  <div class="bg-info/10 border border-info/30 rounded-lg p-4 mt-4">
                    <p class="text-sm text-info">
                      <.icon name="hero-light-bulb" class="w-4 h-4 mr-1" />
                      Hint: {List.first(@current_step.hints)}
                    </p>
                  </div>
                <% end %>

                <%!-- Actions --%>
                <div class="flex flex-col sm:flex-row justify-between items-stretch sm:items-center gap-3 sm:gap-4 pt-4 border-t border-base-200">
                  <%= if @current_step.hints != [] and not @show_hint do %>
                    <button
                      type="button"
                      phx-click="show_hint"
                      class="btn btn-ghost btn-sm text-info order-2 sm:order-1"
                    >
                      <.icon name="hero-light-bulb" class="w-4 h-4 mr-1" /> {gettext("Show Hint")}
                    </button>
                  <% else %>
                    <div class="hidden sm:block order-2 sm:order-1" />
                  <% end %>

                  <button type="submit" class="btn btn-primary w-full sm:w-auto order-1 sm:order-2 min-h-[44px]">
                    <%= if @current_step_index == @total_steps - 1 do %>
                      <.icon name="hero-check" class="w-4 h-4 mr-2" /> {gettext("Finish Test")}
                    <% else %>
                      <.icon name="hero-arrow-right" class="w-4 h-4 mr-2" />
                      {gettext("Next Question")}
                    <% end %>
                  </button>
                </div>
              </form>
            <% else %>
              <div class="text-center py-8">
                <p class="text-secondary">{gettext("No questions available.")}</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>

    <%!-- Timer Hook - handles countdown client-side --%>
    <div
      phx-hook="Timer"
      id="test-timer"
      data-time-remaining={@time_remaining}
      data-sync-interval="10"
    />
    """
  end

  defp format_time(seconds) do
    mins = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{String.pad_leading("#{mins}", 2, "0")}:#{String.pad_leading("#{secs}", 2, "0")}"
  end

  defp format_percentage(float) when is_float(float), do: trunc(float)
  defp format_percentage(int) when is_integer(int), do: int

  # Validate meaning answer (fuzzy match)
  defp validate_meaning(answer, correct) do
    answer_normalized = String.downcase(String.trim(answer))
    correct_normalized = String.downcase(String.trim(correct))

    # Exact match
    # Contains match (e.g., "blue" matches "bluish")
    answer_normalized == correct_normalized or
      String.contains?(answer_normalized, correct_normalized) or
      String.contains?(correct_normalized, answer_normalized)
  end

  # Validate reading answer (exact match with normalization)
  defp validate_reading(answer, correct) do
    answer_normalized =
      answer
      |> String.trim()
      |> String.replace(~r/[\s\-]/, "")

    correct_normalized =
      correct
      |> String.trim()
      |> String.replace(~r/[\s\-]/, "")

    answer_normalized == correct_normalized
  end
end
