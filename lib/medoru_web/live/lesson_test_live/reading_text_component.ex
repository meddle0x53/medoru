defmodule MedoruWeb.LessonTestLive.ReadingTextComponent do
  @moduledoc """
  Component for reading text input questions.

  Displays a Japanese word and asks the user to input:
  1. The English meaning
  2. The hiragana reading

  Provides visual feedback for correct/incorrect answers.
  """

  use Phoenix.Component
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.CoreComponents

  alias Phoenix.LiveView.JS

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
    question_data = assigns.step.question_data || %{}
    is_kana_only = question_data["is_kana_only"] || false
    text_mode = question_data["text_mode"] || "both"

    assigns =
      assigns
      |> assign(:is_kana_only, is_kana_only)
      |> assign(:text_mode, text_mode)

    ~H"""
    <div class="space-y-6" id="reading-text-question">
      <%!-- Word Display --%>
      <div class="mb-4 sm:mb-6">
        <div class="text-xs sm:text-sm text-secondary mb-3">
          <%= cond do %>
            <% @text_mode == "meaning" -> %>
              {gettext("Type the meaning:")}
            <% @text_mode == "reading" -> %>
              {gettext("Type the reading:")}
            <% @is_kana_only -> %>
              {gettext("Type the meaning:")}
            <% true -> %>
              {gettext("Type the meaning and reading:")}
          <% end %>
        </div>
        <h2 class="text-3xl sm:text-4xl font-bold text-primary font-japanese text-center mb-1">
          {@step.question_data["word_text"]}
        </h2>
        <%= if @text_mode == "meaning" and @step.question_data["word_reading"] do %>
          <div class="text-lg text-secondary mt-1 text-center font-japanese">
            {@step.question_data["word_reading"]}
          </div>
        <% end %>
        <%= if @text_mode == "reading" and @step.question_data["word_meaning"] do %>
          <div class="text-base text-secondary mt-1 text-center">
            {@step.question_data["word_meaning"]}
          </div>
        <% end %>
        <%= if @show_hint do %>
          <div class="text-sm text-secondary mt-2 text-center">
            {gettext("Hint: Starts with \"%{hint}\"", hint: hint_text(@step, @is_kana_only))}
          </div>
        <% end %>
      </div>

      <%!-- Feedback after wrong answer --%>
      <%= if @feedback == :incorrect && @correct_meaning do %>
        <div class="bg-error/10 border border-error/20 rounded-xl p-4">
          <div class="flex items-center gap-2 text-error mb-2">
            <.icon name="hero-x-circle" class="w-5 h-5" />
            <span class="font-medium">{gettext("Not quite. The correct answers are:")}</span>
          </div>
          <div class="pl-7 space-y-1">
            <div class="text-base-content">
              <span class="text-secondary">{gettext("Meaning:")}</span>
              <span class="font-medium">{@correct_meaning}</span>
            </div>
            <%= if not @is_kana_only do %>
              <div class="text-base-content">
                <span class="text-secondary">{gettext("Reading:")}</span>
                <span class="font-medium">{@correct_reading}</span>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%!-- Input Fields --%>
      <div class="space-y-4">
        <%= if @text_mode == "meaning" do %>
          <%!-- Single meaning input (meaning_only steps) --%>
          <div>
            <label class="block text-sm font-medium text-secondary mb-2">
              {gettext("Meaning (English):")}
            </label>
            <input
              type="text"
              id="meaning_answer_input"
              name="meaning_answer"
              value={@meaning_answer}
              phx-keyup="update_meaning"
              phx-target={@target}
              phx-mounted={JS.focus()}
              placeholder={gettext("Type the English meaning...")}
              disabled={@feedback == :incorrect}
              class={[
                "w-full px-4 py-3 rounded-xl border-2 bg-base-100 text-base-content placeholder:text-base-content/40",
                "focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all",
                @feedback == :correct && "border-success bg-success/5",
                is_nil(@feedback) && "border-base-200 focus:border-primary"
              ]}
            />
          </div>
        <% else %>
          <%= if @text_mode == "reading" do %>
            <%!-- Single reading input (reading_only steps) --%>
            <div>
              <label class="block text-sm font-medium text-secondary mb-2">
                {gettext("Reading (Hiragana):")}
              </label>
              <input
                type="text"
                id="reading_answer_input"
                name="reading_answer"
                value={@reading_answer}
                phx-keyup="update_reading"
                phx-target={@target}
                phx-mounted={JS.focus()}
                placeholder={gettext("Enter the hiragana reading")}
                disabled={@feedback == :incorrect}
                class={[
                  "w-full px-4 py-3 rounded-xl border-2 bg-base-100 text-base-content placeholder:text-base-content/40",
                  "focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all",
                  @feedback == :correct && "border-success bg-success/5",
                  is_nil(@feedback) && "border-base-200 focus:border-primary"
                ]}
              />
              <div class="text-xs text-secondary mt-1">
                {gettext("Tip: Use hiragana. Long vowels can be written as おう or おお, えい or ええ")}
              </div>
            </div>
          <% else %>
            <%!-- Meaning Input --%>
            <div>
              <label class="block text-sm font-medium text-secondary mb-2">
                {gettext("Meaning (English):")}
              </label>
              <input
                type="text"
                id="meaning_answer_input"
                name="meaning_answer"
                value={@meaning_answer}
                phx-keyup="update_meaning"
                phx-target={@target}
                phx-mounted={JS.focus()}
                placeholder={gettext("Type the English meaning...")}
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

            <%!-- Reading Input (hidden for kana-only words) --%>
            <%= if not @is_kana_only do %>
              <div>
                <label class="block text-sm font-medium text-secondary mb-2">
                  {gettext("Reading (Hiragana):")}
                </label>
                <input
                  type="text"
                  id="reading_answer_input"
                  name="reading_answer"
                  value={@reading_answer}
                  phx-keyup="update_reading"
                  phx-target={@target}
                  placeholder={gettext("Type the hiragana reading...")}
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
                  {gettext("Tip: Use hiragana. Long vowels can be written as おう or おお, えい or ええ")}
                </div>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # Hint shows only the FIRST LETTERS of the fields being asked — for
  # single-field modes the asked field's hint is omitted so it can't leak
  # the answer.
  defp hint_text(step, is_kana_only) do
    text_mode = (step.question_data || %{})["text_mode"] || "both"
    meaning = step.question_data["word_meaning"] || ""
    meaning_hint = String.first(meaning) || "?"
    reading = step.question_data["word_reading"] || ""
    reading_hint = String.first(reading) || "?"

    cond do
      text_mode == "meaning" ->
        gettext("Reading: %{reading_hint}...", reading_hint: reading_hint)

      text_mode == "reading" ->
        gettext("Meaning: %{meaning_hint}...", meaning_hint: meaning_hint)

      is_kana_only ->
        gettext("Meaning: %{meaning_hint}...", meaning_hint: meaning_hint)

      true ->
        gettext("Meaning: %{meaning_hint}... / Reading: %{reading_hint}...",
          meaning_hint: meaning_hint,
          reading_hint: reading_hint
        )
    end
  end
end
