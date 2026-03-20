defmodule MedoruWeb.ClassroomLive.TestResults do
  @moduledoc """
  LiveView for displaying test results after completing a classroom test.
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
          load_results(socket, classroom_id, test_id, user)
        end
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

      # Get all answers for this session
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

      # Build results for each step
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
            is_correct: (answer && answer.is_correct) || false,
            points_earned: (answer && answer.points_earned) || 0,
            points_possible: step.points,
            explanation: step.explanation
          }
        end)

      {:ok,
       socket
       |> assign(:page_title, gettext("Test Results - %{title}", title: test.title))
       |> assign(:classroom, classroom)
       |> assign(:test, test)
       |> assign(:attempt, attempt)
       |> assign(:results, results)
       |> assign(:total_score, attempt.score)
       |> assign(:max_score, attempt.max_score || test.total_points)
       |> assign(
         :percentage,
         calculate_percentage(attempt.score, attempt.max_score || test.total_points)
       )}
    end
  end

  defp calculate_percentage(score, max) when max > 0, do: trunc(score / max * 100)
  defp calculate_percentage(_, _), do: 0

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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/classrooms/#{@classroom.id}?tab=tests"}
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
                <p class="text-lg text-base-content mb-4">{result.step.question}</p>

                <%!-- Answers --%>
                <div class="space-y-2">
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

        <%!-- Actions --%>
        <div class="flex justify-center gap-4 mt-8">
          <.link navigate={~p"/classrooms/#{@classroom.id}?tab=tests"} class="btn btn-primary">
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> #{gettext("Back to Tests")}
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
