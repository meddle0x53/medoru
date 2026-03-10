defmodule MedoruWeb.LessonTestLive.ReadingTextComponent do
  @moduledoc """
  Component for reading text input questions.

  Displays a Japanese word and asks the user to input:
  1. The English meaning
  2. The hiragana reading

  Provides visual feedback for correct/incorrect answers.
  """

  use Phoenix.Component

  import MedoruWeb.CoreComponents

  @doc """
  Renders a reading text question with two input fields.

  ## Assigns
    * `step` - The TestStep struct
    * `meaning_answer` - Current meaning input value
    * `reading_answer` - Current reading input value
    * `feedback` - nil | :correct | :incorrect
    * `show_hint` - Boolean
    * `meaning_error` - Boolean, if meaning was incorrect
    * `reading_error` - Boolean, if reading was incorrect
    * `correct_meaning` - The correct meaning (shown after wrong answer)
    * `correct_reading` - The correct reading (shown after wrong answer)
  """
  attr :step, :map, required: true
  attr :meaning_answer, :string, default: ""
  attr :reading_answer, :string, default: ""
  attr :feedback, :any, default: nil
  attr :show_hint, :boolean, default: false
  attr :meaning_error, :boolean, default: false
  attr :reading_error, :boolean, default: false
  attr :correct_meaning, :string, default: nil
  attr :correct_reading, :string, default: nil
  attr :target, :string, default: nil

  def reading_text_question(assigns) do
    ~H"""
    <div class="space-y-6" id="reading-text-question">
      <%!-- Word Display --%>
      <div class="text-center py-6 bg-base-200/50 rounded-xl">
        <div class="text-4xl font-bold text-base-content mb-2">
          {@step.question_data["word_text"]}
        </div>
        <%= if @show_hint do %>
          <div class="text-sm text-secondary mt-2">
            Hint: Starts with "{hint_text(@step)}"
          </div>
        <% end %>
      </div>

      <%!-- Feedback after wrong answer --%>
      <%= if @feedback == :incorrect && @correct_meaning do %>
        <div class="bg-error/10 border border-error/20 rounded-xl p-4">
          <div class="flex items-center gap-2 text-error mb-2">
            <.icon name="hero-x-circle" class="w-5 h-5" />
            <span class="font-medium">Not quite. The correct answers are:</span>
          </div>
          <div class="pl-7 space-y-1">
            <div class="text-base-content">
              <span class="text-secondary">Meaning:</span>
              <span class="font-medium">{@correct_meaning}</span>
            </div>
            <div class="text-base-content">
              <span class="text-secondary">Reading:</span>
              <span class="font-medium">{@correct_reading}</span>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Input Fields --%>
      <div class="space-y-4">
        <%!-- Meaning Input --%>
        <div>
          <label class="block text-sm font-medium text-secondary mb-2">
            Meaning (English):
          </label>
          <input
            type="text"
            id="meaning_answer_input"
            name="meaning_answer"
            value={@meaning_answer}
            phx-keyup="update_meaning"
            phx-target={@target}
            placeholder="Type the English meaning..."
            disabled={@feedback == :incorrect}
            class={[
              "w-full px-4 py-3 rounded-xl border-2 bg-base-100 text-base-content placeholder:text-base-content/40",
              "focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all",
              @meaning_error && "border-error bg-error/5",
              @feedback == :correct && "border-success bg-success/5",
              is_nil(@feedback) && !@meaning_error && "border-base-200 focus:border-primary"
            ]}
          />
        </div>

        <%!-- Reading Input --%>
        <div>
          <label class="block text-sm font-medium text-secondary mb-2">
            Reading (Hiragana):
          </label>
          <input
            type="text"
            id="reading_answer_input"
            name="reading_answer"
            value={@reading_answer}
            phx-keyup="update_reading"
            phx-target={@target}
            placeholder="Type the hiragana reading..."
            disabled={@feedback == :incorrect}
            class={[
              "w-full px-4 py-3 rounded-xl border-2 bg-base-100 text-base-content placeholder:text-base-content/40",
              "focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all",
              @reading_error && "border-error bg-error/5",
              @feedback == :correct && "border-success bg-success/5",
              is_nil(@feedback) && !@reading_error && "border-base-200 focus:border-primary"
            ]}
          />
          <div class="text-xs text-secondary mt-1">
            Tip: Use hiragana. Long vowels can be written as おう or おお, えい or ええ
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Generate hint text showing first letter/kana of both answers
  defp hint_text(step) do
    meaning = step.question_data["word_meaning"] || ""
    reading = step.question_data["word_reading"] || ""

    meaning_hint = String.first(meaning) || "?"
    reading_hint = String.first(reading) || "?"

    "Meaning: #{meaning_hint}... / Reading: #{reading_hint}..."
  end
end
