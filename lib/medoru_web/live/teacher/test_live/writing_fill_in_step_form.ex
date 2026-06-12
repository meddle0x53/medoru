defmodule MedoruWeb.Teacher.TestLive.WritingFillInStepForm do
  @moduledoc """
  Form component for writing fill-in test steps.

  Students see an example plus a template with blank placeholders (___).
  They type the missing words and their filled-in sentence is compared
  against the correct full sentence.
  """

  use MedoruWeb, :html

  @doc """
  Renders the writing fill-in step form.
  """
  attr :step_form, :any, required: true
  attr :step_changeset, :any, required: true

  def writing_fill_in_form(assigns) do
    qd =
      if assigns.step_form do
        assigns.step_form[:question_data].value || %{}
      else
        %{}
      end

    assigns = assign(assigns, :qd, qd)

    ~H"""
    <div class="space-y-4">
      <div>
        <label class="label" for="step_question">
          <span class="label-text">{gettext("Question")}</span>
        </label>
        <input
          type="text"
          id="step_question"
          name="step[question]"
          value={(@step_form && @step_form[:question].value) || gettext("Fill in the blanks")}
          class="input input-bordered w-full"
          placeholder={gettext("e.g., Fill in the blanks")}
          required
        />
      </div>

      <div>
        <label class="label">
          <span class="label-text">{gettext("Examples")}</span>
        </label>
        <p class="text-sm text-secondary mb-2">
          {gettext("Examples shown to students. One per line.")}
        </p>
        <textarea
          name="step[question_data][examples_text]"
          class="textarea textarea-bordered w-full font-jp"
          rows="3"
          placeholder={gettext("e.g., あなたは（学生）ですか。はい、学生です。")}
        ><%= examples_text(@qd) %></textarea>
      </div>

      <div>
        <label class="label">
          <span class="label-text">{gettext("Template")}</span>
        </label>
        <p class="text-sm text-secondary mb-2">
          {gettext(
            "Use ___ (three underscores) for each blank. Students will see input boxes in those places."
          )}
        </p>
        <textarea
          name="step[question_data][template]"
          class="textarea textarea-bordered w-full font-jp"
          rows="3"
          placeholder={gettext("e.g., あなたは（___）ですか。")}
          required
        ><%= @qd["template"] || "" %></textarea>
      </div>

      <div>
        <label class="label" for="correct_answer">
          <span class="label-text">{gettext("Correct Answer")}</span>
        </label>
        <p class="text-sm text-secondary mb-2">
          {gettext("The complete sentence with all blanks filled in.")}
        </p>
        <input
          type="text"
          id="correct_answer"
          name="step[correct_answer]"
          value={@step_form[:correct_answer].value}
          class="input input-bordered w-full font-jp"
          placeholder={gettext("e.g., あなたは（学生）ですか。")}
          required
        />
      </div>

      <div>
        <label class="label">
          <span class="label-text">{gettext("Alternative Correct Answers (optional)")}</span>
        </label>
        <p class="text-sm text-secondary mb-2">
          {gettext("One per line. Used when multiple full sentences are correct.")}
        </p>
        <textarea
          name="step[question_data][alt_correct_answers_text]"
          class="textarea textarea-bordered w-full font-jp"
          rows="3"
          placeholder={gettext("e.g., あなたは学生ですか。")}
        ><%= Enum.join(@qd["alt_correct_answers"] || [], "\n") %></textarea>
      </div>
    </div>
    """
  end

  defp examples_text(%{"examples_text" => text}) when is_binary(text) and text != "", do: text

  defp examples_text(question_data) do
    examples =
      case question_data do
        %{"examples" => examples} when is_list(examples) -> examples
        %{"example" => example} when is_binary(example) and example != "" -> [example]
        _ -> []
      end

    Enum.join(examples, "\n")
  end
end
