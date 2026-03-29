defmodule MedoruWeb.DailyTestLive.Complete do
  @moduledoc """
  Completion screen for daily tests.
  Shows results, stats, and streak information.
  """

  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.{Learning, Tests}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Get today's completed daily test session
    case get_todays_completed_session(user.id) do
      nil ->
        {:ok,
         socket
         |> assign(:page_title, "Daily Review")
         |> assign(:has_session, false)}

      session ->
        # Get test details
        test = Tests.get_test!(session.test_id)

        # Get step answers
        answers = Tests.list_step_answers(session.id)

        # Calculate stats
        correct_count = Enum.count(answers, & &1.is_correct)
        total_count = length(answers)

        # Get streak info
        streak = Learning.get_daily_streak(user.id)

        {:ok,
         socket
         |> assign(:page_title, "Daily Review Complete")
         |> assign(:has_session, true)
         |> assign(:session, session)
         |> assign(:test, test)
         |> assign(:answers, answers)
         |> assign(:correct_count, correct_count)
         |> assign(:total_count, total_count)
         |> assign(:percentage, calculate_percentage(correct_count, total_count))
         |> assign(:streak, streak)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto px-4 py-8">
        <%= if !@has_session do %>
          <%!-- No Session State --%>
          <div class="bg-base-100 rounded-2xl shadow-sm border border-base-200 p-8 text-center">
            <div class="w-24 h-24 bg-warning/20 rounded-full flex items-center justify-center mx-auto mb-6">
              <.icon name="hero-exclamation-circle" class="w-12 h-12 text-warning" />
            </div>
            <h1 class="text-2xl font-bold text-base-content mb-2">No Review Found</h1>
            <p class="text-secondary mb-6">
              We couldn't find a completed daily review for today.
            </p>
            <.link
              navigate={~p"/dashboard"}
              class="inline-flex items-center gap-2 px-6 py-3 bg-primary text-primary-content rounded-xl font-medium hover:bg-primary/90 transition-colors"
            >
              <.icon name="hero-home" class="w-5 h-5" /> Back to Dashboard
            </.link>
          </div>
        <% else %>
          <%!-- Success Header --%>
          <div class="bg-base-100 rounded-2xl shadow-sm border border-base-200 p-8 text-center mb-6">
            <div class="w-24 h-24 bg-success/20 rounded-full flex items-center justify-center mx-auto mb-6 animate-bounce">
              <.icon name="hero-fire" class="w-12 h-12 text-warning" />
            </div>
            <h1 class="text-3xl font-bold text-base-content mb-2">Daily Review Complete! 🎉</h1>
            <p class="text-secondary mb-6">
              Great work! You've completed today's daily review.
            </p>

            <%!-- Stats Grid --%>
            <div class="grid grid-cols-3 gap-4 max-w-md mx-auto mb-8">
              <div class="bg-success/10 rounded-xl p-4">
                <div class="text-3xl font-bold text-success">{@correct_count}</div>
                <div class="text-sm text-base-content/70">Correct</div>
              </div>
              <div class="bg-error/10 rounded-xl p-4">
                <div class="text-3xl font-bold text-error">{@total_count - @correct_count}</div>
                <div class="text-sm text-base-content/70">Incorrect</div>
              </div>
              <div class="bg-primary/10 rounded-xl p-4">
                <div class="text-3xl font-bold text-primary">{@percentage}%</div>
                <div class="text-sm text-base-content/70">Score</div>
              </div>
            </div>

            <%!-- Streak Info --%>
            <%= if @streak do %>
              <div class="bg-gradient-to-r from-orange-100 to-yellow-100 dark:from-orange-900/30 dark:to-yellow-900/30 rounded-xl p-4 mb-6">
                <div class="flex items-center justify-center gap-3">
                  <.icon name="hero-fire" class="w-8 h-8 text-orange-500" />
                  <div class="text-left">
                    <div class="text-2xl font-bold text-base-content">
                      {@streak.current_streak} day streak!
                    </div>
                    <div class="text-sm text-secondary">
                      Longest: {@streak.longest_streak} days
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Actions --%>
            <div class="flex flex-wrap gap-4 justify-center">
              <.link
                navigate={~p"/dashboard"}
                class="inline-flex items-center gap-2 px-6 py-3 bg-primary text-primary-content rounded-xl font-medium hover:bg-primary/90 transition-colors"
              >
                <.icon name="hero-home" class="w-5 h-5" /> Back to Dashboard
              </.link>

              <.link
                navigate={~p"/lessons"}
                class="inline-flex items-center gap-2 px-6 py-3 bg-base-200 text-base-content rounded-xl font-medium hover:bg-base-300 transition-colors"
              >
                <.icon name="hero-academic-cap" class="w-5 h-5" /> Continue Learning
              </.link>
            </div>
          </div>

          <%!-- Review Summary --%>
          <div class="bg-base-100 rounded-2xl shadow-sm border border-base-200 p-6">
            <h2 class="text-xl font-bold text-base-content mb-4">Review Summary</h2>

            <div class="space-y-3">
              <%= for answer <- @answers do %>
                <div class={[
                  "flex items-center gap-4 p-3 rounded-lg",
                  if(answer.is_correct, do: "bg-success/10", else: "bg-error/10")
                ]}>
                  <div class={[
                    "w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0",
                    if(answer.is_correct, do: "bg-success", else: "bg-error")
                  ]}>
                    <.icon
                      name={if(answer.is_correct, do: "hero-check", else: "hero-x-mark")}
                      class="w-5 h-5 text-white"
                    />
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="font-medium text-base-content truncate">
                      {translate_question(answer.test_step.question)}
                    </div>
                    <div class="text-sm text-secondary">
                      Your answer: {answer.answer}
                      <%= if !answer.is_correct do %>
                        <span class="text-error">
                          (Correct: {answer.test_step.correct_answer})
                        </span>
                      <% end %>
                    </div>
                  </div>
                  <div class="text-sm font-medium">
                    <%= if answer.is_correct do %>
                      <span class="text-success">+{answer.points_earned} pts</span>
                    <% else %>
                      <span class="text-error">0 pts</span>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # Private functions

  defp get_todays_completed_session(user_id) do
    import Ecto.Query
    alias Medoru.Tests.TestSession

    today = Date.utc_today()
    beginning_of_day = DateTime.new!(today, ~T[00:00:00])
    end_of_day = DateTime.new!(today, ~T[23:59:59])

    TestSession
    |> join(:inner, [ts], t in assoc(ts, :test))
    |> where([ts, t], ts.user_id == ^user_id and t.test_type == :daily)
    |> where([ts], ts.status == :completed)
    |> where([ts], ts.completed_at >= ^beginning_of_day and ts.completed_at <= ^end_of_day)
    |> order_by([ts], desc: ts.completed_at)
    |> limit(1)
    |> Medoru.Repo.one()
  end

  defp calculate_percentage(correct, total) when total > 0 do
    Float.round(correct / total * 100, 1)
  end

  defp calculate_percentage(_, _), do: 0

  # Translate question messages from the database
  defp translate_question(nil), do: ""

  defp translate_question(question) when is_binary(question) do
    cond do
      String.starts_with?(question, "__MSG_WHAT_DOES_WORD_MEAN__|") ->
        case String.split(question, "|") do
          [_, word] -> gettext("What does '%{word}' mean?", word: word)
          _ -> question
        end

      String.starts_with?(question, "__MSG_HOW_DO_YOU_READ__|") ->
        case String.split(question, "|") do
          [_, word] -> gettext("How do you read '%{word}'?", word: word)
          _ -> question
        end

      String.starts_with?(question, "__MSG_TYPE_MEANING_READING__|") ->
        case String.split(question, "|") do
          [_, word] -> gettext("Type the meaning and reading for '%{word}'", word: word)
          _ -> question
        end

      String.starts_with?(question, "__MSG_WRITE_KANJI_FOR__|") ->
        case String.split(question, "|") do
          [_, meanings] -> gettext("Write the kanji for '%{meanings}'", meanings: meanings)
          _ -> question
        end

      true ->
        question
    end
  end
end
