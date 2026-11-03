defmodule MedoruWeb.ClassroomLive.TestResults do
  @moduledoc """
  LiveView for displaying test results after completing a classroom test.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.Tests
  alias MedoruWeb.PublicAccess
  alias MedoruWeb.SlugRoutes

  @impl true
  def mount(%{"id" => classroom_id, "test_id" => test_id} = params, session, socket) do
    user = socket.assigns.current_scope.current_user
    locale = session["locale"] || "en"

    socket = assign(socket, :locale, locale)

    classroom = SlugRoutes.load_classroom!(classroom_id)
    test = SlugRoutes.load_test!(test_id)

    cond do
      not is_nil(user) ->
        # Verify user is an approved member of the classroom
        case Classrooms.get_user_membership(classroom.id, user.id) do
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
               |> push_navigate(to: ~p"/classrooms/#{classroom.id}")}
            else
              load_results(socket, classroom.id, test.id, user)
            end
        end

      PublicAccess.featured_classroom?(classroom.id) ->
        load_anonymous_results(socket, classroom.id, test.id, params["session_id"])

      true ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You must sign in to view these results."))
         |> push_navigate(to: ~p"/auth/google")}
    end
  end

  defp load_results(socket, classroom_id, test_id, user) do
    classroom = Classrooms.get_classroom!(classroom_id)
    test = Tests.get_test!(test_id)

    # Get the user's attempt
    attempt = Classrooms.get_test_attempt(classroom_id, user.id, test_id)

    if is_nil(attempt) || attempt.status not in ["completed", "timed_out"] do
      {:ok,
       socket
       |> put_flash(:error, gettext("No completed test found."))
       |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}
    else
      # Get test session and answers
      session = Tests.get_test_session(attempt.test_session_id)
      steps = Tests.list_test_steps(test_id)

      {results, total_score, max_score} =
        build_results(steps, session, attempt.score, attempt.max_score || test.total_points)

      {:ok,
       socket
       |> assign(:page_title, gettext("Test Results - %{title}", title: test.title))
       |> assign(:classroom, classroom)
       |> assign(:test, test)
       |> assign(:attempt, attempt)
       |> assign(:results, results)
       |> assign(:export_groups, group_results_for_export(results))
       |> assign(:show_export, false)
       |> assign(:export_show_results, true)
       |> assign(:total_score, total_score)
       |> assign(:max_score, max_score)
       |> assign(
         :percentage,
         calculate_percentage(total_score, max_score)
       )}
    end
  end

  defp load_anonymous_results(socket, classroom_id, test_id, session_id) do
    classroom = Classrooms.get_classroom!(classroom_id)
    test = Tests.get_test!(test_id)

    session = Tests.get_test_session(session_id)

    if is_nil(session) || session.status != :completed do
      {:ok,
       socket
       |> put_flash(:error, gettext("No completed test found."))
       |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=tests")}
    else
      steps = Tests.list_test_steps(test_id)
      {results, total_score, max_score} = build_results(steps, session, 0, test.total_points)

      # Build a fake attempt-like map so the template can still read time_spent_seconds.
      attempt = %{
        time_spent_seconds: session.time_spent_seconds || 0
      }

      {:ok,
       socket
       |> assign(:page_title, gettext("Test Results - %{title}", title: test.title))
       |> assign(:classroom, classroom)
       |> assign(:test, test)
       |> assign(:attempt, attempt)
       |> assign(:results, results)
       |> assign(:export_groups, group_results_for_export(results))
       |> assign(:show_export, false)
       |> assign(:export_show_results, true)
       |> assign(:total_score, total_score)
       |> assign(:max_score, max_score)
       |> assign(
         :percentage,
         calculate_percentage(total_score, max_score)
       )}
    end
  end

  # For "make a question and answer it" steps, the recorded answer is a
  # question/answer pair joined by a newline and correct_answer is "N/A" —
  # show both parts of each side as labeled rows instead.
  defp review_lines_for(%{question_type: :grammar_make_question_answer} = step, answer) do
    qd = step.question_data || %{}

    student_lines =
      case answer && answer.answer do
        nil ->
          []

        text ->
          {question, answer_part} = Medoru.Tests.TestStepAnswer.split_make_question_answer(text)

          [
            {gettext("Your Question"), question},
            {gettext("Your Answer"), answer_part}
          ]
      end

    correct_lines = [
      {gettext("Expected Question"), qd["expected_question"] || ""},
      {gettext("Expected Answer"), qd["expected_answer"] || ""}
    ]

    %{student: student_lines, correct: correct_lines}
  end

  defp review_lines_for(_step, _answer), do: nil

  @doc """
  Groups review results for the export panel.

  Consecutive `:grammar_make_question_answer` results with identical
  `step.question` AND identical `question_data["examples"]` are merged into a
  single group so the worked examples render once. All other results pass
  through as singleton rows. Non-consecutive identical groups stay separate.
  """
  def group_results_for_export(results) do
    results
    |> Enum.chunk_by(fn result ->
      step = result.step

      if step.question_type == :grammar_make_question_answer do
        question_data = step.question_data || %{}
        {:make_question_answer, step.question, question_data["examples"] || []}
      else
        {:single, result.index}
      end
    end)
    |> Enum.map(fn
      [first | _] = chunk ->
        if first.step.question_type == :grammar_make_question_answer do
          question_data = first.step.question_data || %{}

          %{
            type: :make_question_answer,
            question: first.step.question,
            examples: question_data["examples"] || [],
            items: chunk
          }
        else
          %{type: :single, result: first}
        end
    end)
  end

  defp build_results(steps, session, default_score, default_max) do
    answers =
      if session do
        Tests.list_step_answers(session.id)
        |> Enum.map(fn answer ->
          {answer.step_index, answer}
        end)
        |> Enum.into(%{})
      else
        %{}
      end

    results =
      steps
      |> Enum.with_index()
      |> Enum.map(fn {step, index} ->
        answer = Map.get(answers, index)

        %{
          index: index,
          step: step,
          user_answer: answer && answer.answer,
          correct_answer: step.correct_answer,
          review_lines: review_lines_for(step, answer),
          is_correct: (answer && answer.is_correct) || false,
          points_earned: (answer && answer.points_earned) || 0,
          points_possible: step.points,
          explanation: step.explanation
        }
      end)

    total_score =
      if session && not is_nil(session.score), do: session.score, else: default_score

    max_score =
      cond do
        session && not is_nil(session.total_possible) && session.total_possible > 0 ->
          session.total_possible

        default_max && default_max > 0 ->
          default_max

        true ->
          Enum.reduce(steps, 0, &(&1.points + &2))
      end

    {results, total_score, max_score}
  end

  defp calculate_percentage(score, max) when max > 0, do: trunc(score / max * 100)
  defp calculate_percentage(_, _), do: 0

  @impl true
  def handle_event("toggle_export_preview", _params, socket) do
    {:noreply, assign(socket, :show_export, not socket.assigns.show_export)}
  end

  def handle_event("toggle_export_results", _params, socket) do
    {:noreply, assign(socket, :export_show_results, not socket.assigns.export_show_results)}
  end

  # Format seconds into MM:SS or HH:MM:SS
  defp format_duration(seconds) when is_integer(seconds) and seconds >= 0 do
    hours = div(seconds, 3600)
    mins = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    if hours > 0 do
      "#{hours}:#{String.pad_leading("#{mins}", 2, "0")}:#{String.pad_leading("#{secs}", 2, "0")}"
    else
      "#{mins}:#{String.pad_leading("#{secs}", 2, "0")}"
    end
  end

  defp format_duration(_), do: "0:00"

  defp format_question_for_results(step, locale) do
    question = step.question || ""

    case question do
      "__MSG_WRITE_KANJI_FOR__|" <> _ ->
        meanings = get_kanji_meanings_for_step(step, locale)
        gettext("Write the kanji for '%{meanings}'", meanings: meanings)

      "__MSG_WRITE_KANJI_IN_WORD__|" <> rest ->
        case String.split(rest, "|", parts: 2) do
          [word_reading, word_meaning] ->
            gettext(
              "Write the kanji in the word %{word_reading} (%{word_meaning})",
              word_reading: word_reading,
              word_meaning: word_meaning
            )

          _ ->
            question
        end

      _ ->
        question
    end
  end

  defp get_kanji_meanings_for_step(step, locale) when locale in ["bg", "ja"] do
    case step.kanji do
      nil ->
        extract_meanings_from_question(step.question)

      %Ecto.Association.NotLoaded{} ->
        extract_meanings_from_question(step.question)

      kanji ->
        localized = Medoru.Content.get_localized_kanji_meanings(kanji, locale)

        if localized != [] do
          localized |> Enum.take(2) |> Enum.join(", ")
        else
          extract_meanings_from_question(step.question)
        end
    end
  end

  defp get_kanji_meanings_for_step(step, _locale) do
    extract_meanings_from_question(step.question)
  end

  defp extract_meanings_from_question("__MSG_WRITE_KANJI_FOR__|" <> meanings), do: meanings
  defp extract_meanings_from_question(question), do: question

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8 test-results-container" data-theme={@classroom.theme}>
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/classrooms/#{@classroom.slug}?tab=tests"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> #{gettext("Back to Tests")}
          </.link>
          <h1 class="text-2xl font-bold text-base-content">{@test.title}</h1>
          <p class="text-secondary">{gettext("Test Results")}</p>
        </div>

        <%!-- Score Summary Card --%>
        <div class="card bg-base-100 border border-base-300 shadow-lg mb-8">
          <div class="card-body text-center">
            <h2 class="text-lg font-medium text-base-content mb-4">{gettext("Your Score")}</h2>

            <div class="flex items-center justify-center gap-4 mb-4">
              <div class={[
                "text-5xl font-bold",
                @percentage >= 80 && "text-success",
                @percentage >= 60 && @percentage < 80 && "text-warning",
                @percentage < 60 && "text-error"
              ]}>
                {@percentage}%
              </div>
            </div>

            <p class="text-xl text-base-content">
              {@total_score} <span class="text-secondary">/ {@max_score}</span> points
            </p>

            <p class="text-sm text-secondary mt-2">
              <.icon name="hero-clock" class="w-4 h-4 inline mr-1" />
              {gettext("Time spent:")} {format_duration(@attempt.time_spent_seconds)}
            </p>

            <div class="mt-4">
              <%= cond do %>
                <% @percentage >= 80 -> %>
                  <span class="badge badge-success badge-lg">{gettext("Excellent!")}</span>
                <% @percentage >= 60 -> %>
                  <span class="badge badge-warning badge-lg">{gettext("Good Job!")}</span>
                <% true -> %>
                  <span class="badge badge-error badge-lg">{gettext("Keep Practicing!")}</span>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Results List --%>
        <h2 class="text-xl font-semibold text-base-content mb-4">{gettext("Question Review")}</h2>

        <div class="space-y-4">
          <%= for result <- @results do %>
            <div class={[
              "card border shadow-sm",
              result.is_correct && "border-success/30 bg-success/5",
              not result.is_correct && "border-error/30 bg-error/5"
            ]}>
              <div class="card-body p-6">
                <%!-- Question Header --%>
                <div class="flex items-start justify-between mb-4">
                  <div class="flex items-center gap-3">
                    <span class="text-sm text-secondary">
                      {gettext("Question %{number}", number: result.index + 1)}
                    </span>
                    <%= if result.is_correct do %>
                      <span class="badge badge-success gap-1">
                        <.icon name="hero-check" class="w-3 h-3" /> #{gettext("Correct")}
                      </span>
                    <% else %>
                      <span class="badge badge-error gap-1">
                        <.icon name="hero-x-mark" class="w-3 h-3" /> #{gettext("Incorrect")}
                      </span>
                    <% end %>
                  </div>
                  <span class={[
                    "text-sm font-medium",
                    result.is_correct && "text-success",
                    not result.is_correct && "text-error"
                  ]}>
                    {result.points_earned}/{result.points_possible} pts
                  </span>
                </div>

                <%!-- Question --%>
                <p class="text-lg text-base-content mb-4">
                  {format_question_for_results(result.step, @locale)}
                </p>

                <%!-- Answers --%>
                <div class="space-y-2">
                  <%= if result.review_lines do %>
                    <%= if result.review_lines.student != [] do %>
                      <div class={[
                        "p-3 rounded-lg space-y-1",
                        result.is_correct && "bg-success/10 text-success",
                        not result.is_correct && "bg-error/10 text-error"
                      ]}>
                        <%= for {label, value} <- result.review_lines.student do %>
                          <div>
                            <span class="text-sm font-medium">{label}:</span>
                            <span class="ml-2 font-jp">{value}</span>
                          </div>
                        <% end %>
                      </div>
                    <% else %>
                      <div class="p-3 rounded-lg bg-base-200 text-secondary">
                        <span class="text-sm font-medium">{gettext("Your Answer:")}</span>
                        <span class="ml-2 italic">{gettext("Not answered")}</span>
                      </div>
                    <% end %>

                    <%= if not result.is_correct do %>
                      <div class="p-3 rounded-lg bg-success/10 text-success space-y-1">
                        <%= for {label, value} <- result.review_lines.correct do %>
                          <div>
                            <span class="text-sm font-medium">{label}:</span>
                            <span class="ml-2 font-jp">{value}</span>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  <% else %>
                    <%= if result.user_answer do %>
                      <div class={[
                        "p-3 rounded-lg",
                        result.is_correct && "bg-success/10 text-success",
                        not result.is_correct && "bg-error/10 text-error"
                      ]}>
                        <span class="text-sm font-medium">{gettext("Your Answer:")}</span>
                        <span class="ml-2">{result.user_answer}</span>
                      </div>
                    <% else %>
                      <div class="p-3 rounded-lg bg-base-200 text-secondary">
                        <span class="text-sm font-medium">{gettext("Your Answer:")}</span>
                        <span class="ml-2 italic">{gettext("Not answered")}</span>
                      </div>
                    <% end %>

                    <%= if not result.is_correct do %>
                      <div class="p-3 rounded-lg bg-success/10 text-success">
                        <span class="text-sm font-medium">{gettext("Correct Answer:")}</span>
                        <span class="ml-2">{result.correct_answer}</span>
                      </div>
                    <% end %>
                  <% end %>
                </div>

                <%!-- Explanation --%>
                <%= if result.explanation && result.explanation != "" do %>
                  <div class="mt-4 pt-4 border-t border-base-200">
                    <p class="text-sm text-secondary">
                      <span class="font-medium">{gettext("Explanation:")}</span> {result.explanation}
                    </p>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Export: preview toggle + PNG download + print --%>
        <div class="flex flex-wrap justify-center items-center gap-3 mt-8 no-print">
          <button
            type="button"
            phx-click="toggle_export_results"
            class={["btn btn-outline gap-2", not @export_show_results && "btn-active"]}
            aria-pressed={@export_show_results}
          >
            <.icon
              name={if(@export_show_results, do: "hero-check-circle", else: "hero-x-circle")}
              class="w-4 h-4"
            />
            {gettext("Show correct/incorrect marks")}
          </button>
          <button type="button" phx-click="toggle_export_preview" class="btn btn-outline">
            <.icon name="hero-eye" class="w-4 h-4 mr-1" />
            {gettext("Preview export")}
          </button>
          <button
            type="button"
            id="export-download-image"
            phx-hook="ShareAsPicture"
            data-share-target="test-results-export"
            data-filename={"#{@test.title}-results.png"}
            class="btn btn-outline"
          >
            <.icon name="hero-photo" class="w-4 h-4 mr-1" />
            {gettext("Download image")}
          </button>
          <button type="button" id="export-print" phx-hook="PrintPage" class="btn btn-outline">
            <.icon name="hero-printer" class="w-4 h-4 mr-1" />
            {gettext("Print / Save as PDF")}
          </button>
        </div>

        <%!-- Export panel: off-screen until preview is enabled, but always
        rendered so PNG capture and print work regardless of preview state. --%>
        <div class={[
          "test-results-export-wrapper mt-8",
          not @show_export && "export-panel-hidden"
        ]}>
          <div
            id="test-results-export"
            class="bg-base-100 text-base-content rounded-2xl border border-base-300 p-6 space-y-6"
          >
            <div class="text-center border-b border-base-300 pb-4">
              <h2 class="text-xl font-bold">{@test.title}</h2>
              <%= if @export_show_results do %>
                <p class="text-secondary">
                  {gettext("Test Results")} — {@total_score}/{@max_score} ({@percentage}%)
                </p>
              <% end %>
            </div>

            <%= for group <- @export_groups do %>
              <%= if group.type == :make_question_answer do %>
                <div class="space-y-3">
                  <div class="text-base font-medium text-base-content">{group.question}</div>

                  <%= if group.examples != [] do %>
                    <div class="bg-base-200 rounded-xl p-4 space-y-2">
                      <p class="text-sm text-secondary mb-1">{gettext("例")}</p>
                      <%= for example <- group.examples do %>
                        <div class="font-jp text-base-content">
                          <%= for line <- String.split(example, "\n") do %>
                            <div>{line}</div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <div class="space-y-2">
                    <%= for item <- group.items do %>
                      <% qd = item.step.question_data || %{}

                      {student_q, student_a} =
                        case item.user_answer do
                          nil -> {nil, nil}
                          text -> Medoru.Tests.TestStepAnswer.split_make_question_answer(text)
                        end %>
                      <div class="rounded-lg border border-base-300 p-3">
                        <div class="flex items-center justify-between gap-2 mb-2">
                          <span class="font-jp text-base-content font-medium">
                            {qd["requirement"]}
                          </span>
                          <%= if @export_show_results do %>
                            <span class={[
                              "text-sm font-medium shrink-0",
                              item.is_correct && "text-success",
                              not item.is_correct && "text-error"
                            ]}>
                              {if(item.is_correct, do: "✓", else: "✗")}
                              {item.points_earned}/{item.points_possible}
                            </span>
                          <% end %>
                        </div>
                        <div class="text-sm space-y-1">
                          <div>
                            <span class="text-secondary">{gettext("Question")}:</span>
                            <span class="ml-1 font-jp">{student_q || "—"}</span>
                          </div>
                          <div>
                            <span class="text-secondary">{gettext("Answer")}:</span>
                            <span class="ml-1 font-jp">{student_a || "—"}</span>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% else %>
                <% result = group.result %>
                <div class="rounded-lg border border-base-300 p-3">
                  <div class="flex items-start justify-between gap-2">
                    <div>
                      <div class="text-sm text-secondary mb-1">
                        {gettext("Question %{number}", number: result.index + 1)}
                      </div>
                      <div class="text-base-content">
                        {format_question_for_results(result.step, @locale)}
                      </div>
                      <div class="text-sm mt-1">
                        <span class="text-secondary">{gettext("Your Answer:")}</span>
                        <span class="ml-1 font-jp">{result.user_answer || "—"}</span>
                      </div>
                    </div>
                    <%= if @export_show_results do %>
                      <span class={[
                        "text-sm font-medium shrink-0",
                        result.is_correct && "text-success",
                        not result.is_correct && "text-error"
                      ]}>
                        {if(result.is_correct, do: "✓", else: "✗")}
                        {result.points_earned}/{result.points_possible}
                      </span>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- Actions --%>
        <div class="flex justify-center gap-4 mt-8 no-print">
          <.link navigate={~p"/classrooms/#{@classroom.slug}?tab=tests"} class="btn btn-primary">
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> #{gettext("Back to Tests")}
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
