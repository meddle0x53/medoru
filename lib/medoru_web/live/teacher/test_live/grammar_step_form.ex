defmodule MedoruWeb.Teacher.TestLive.GrammarStepForm do
  @moduledoc """
  Form components for grammar test steps.

  Supports:
  - Type 1: Sentence validation (write sentence matching grammar pattern)
  - Type 2: Conjugation (base form → target form)
  - Type 3: Conjugation multiple choice
  - Type 4: Word order (arrange bubbles)
  """

  use MedoruWeb, :html

  @doc """
  Renders the grammar step form based on question type.
  """
  attr :step_form, :any, required: true
  attr :step_type, :atom, required: true
  attr :step_changeset, :any, required: true
  attr :grammar_forms, :list, default: []
  attr :word_classes, :list, default: []

  def grammar_step_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= case @step_type do %>
        <% :sentence_validation -> %>
          <.sentence_validation_form
            step_form={@step_form}
            step_changeset={@step_changeset}
            word_classes={@word_classes}
            grammar_forms={@grammar_forms}
          />
        <% :conjugation -> %>
          <.conjugation_form
            step_form={@step_form}
            step_changeset={@step_changeset}
            grammar_forms={@grammar_forms}
          />
        <% :conjugation_multichoice -> %>
          <.conjugation_multichoice_form
            step_form={@step_form}
            step_changeset={@step_changeset}
            grammar_forms={@grammar_forms}
          />
        <% :word_order -> %>
          <.word_order_form
            step_form={@step_form}
            step_changeset={@step_changeset}
          />
        <% _ -> %>
          <p class="text-secondary">{gettext("Select a grammar step type")}</p>
      <% end %>
    </div>
    """
  end

  # Type 1: Sentence Validation Form
  defp sentence_validation_form(assigns) do
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
          value={@step_form[:question].value}
          class="input input-bordered w-full"
          placeholder={gettext("e.g., Write a sentence about your weekend plans")}
          required
        />
      </div>

      <div class="bg-base-200 rounded-lg p-4">
        <h4 class="font-medium mb-3">{gettext("Grammar Pattern")}</h4>
        <div class="space-y-3">
          <p class="text-sm text-secondary">
            {gettext("Build the grammar pattern students should follow.")}
          </p>

          <%!-- Pattern Preview --%>
          <div class="bg-base-100 rounded p-3 min-h-[50px] flex items-center gap-2 flex-wrap">
            <span class="text-sm text-secondary">{gettext("Pattern:")}</span>
            <% pattern = normalize_pattern(@step_form[:question_data].value["pattern"]) %>
            <%= if pattern == [] do %>
              <span class="text-secondary italic">{gettext("Add elements below")}</span>
            <% else %>
              <%= for element <- pattern do %>
                <.pattern_element_bubble element={element} grammar_forms={@grammar_forms} />
              <% end %>
            <% end %>
          </div>

          <%!-- Add Element Buttons --%>
          <div class="flex flex-wrap gap-2">
            <button
              type="button"
              phx-click="add_pattern_element"
              phx-value-type="word_slot"
              class="btn btn-xs btn-outline"
            >
              {gettext("+ Word Slot")}
            </button>
            <button
              type="button"
              phx-click="add_pattern_element"
              phx-value-type="word_class"
              class="btn btn-xs btn-outline"
            >
              {gettext("+ Word Class")}
            </button>
            <button
              type="button"
              phx-click="add_pattern_element"
              phx-value-type="literal"
              class="btn btn-xs btn-outline"
            >
              {gettext("+ Text")}
            </button>
          </div>

          <%!-- Pattern Element Configuration --%>
          <%= if pattern != [] do %>
            <div class="mt-4 space-y-3">
              <h5 class="text-sm font-medium">{gettext("Configure Elements")}</h5>
              <%= for {element, idx} <- Enum.with_index(pattern) do %>
                <.pattern_element_config
                  element={element}
                  index={idx}
                  word_classes={@word_classes}
                  grammar_forms={@grammar_forms}
                />
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-3">
          <input
            type="checkbox"
            name="step[question_data][show_pattern]"
            class="checkbox checkbox-sm"
            checked={@step_form[:question_data].value["show_pattern"] != false}
          />
          <span class="label-text">{gettext("Show grammar pattern to students")}</span>
        </label>
      </div>
    </div>
    """
  end

  # Type 2: Conjugation Form
  defp conjugation_form(assigns) do
    question_data = assigns.step_form[:question_data].value || %{}

    auto_generate =
      question_data["auto_generate"] == true || question_data["auto_generate"] == "true"

    assigns =
      assigns
      |> assign(:auto_generate, auto_generate)
      |> assign(:question_data, question_data)

    ~H"""
    <div class="space-y-4">
      <%!-- Auto-generate toggle --%>
      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-3">
          <input
            type="checkbox"
            id="auto_generate_checkbox"
            name="step[question_data][auto_generate]"
            class="checkbox checkbox-sm"
            checked={@auto_generate}
            value="true"
            phx-click="toggle_auto_generate"
          />
          <span class="label-text">{gettext("Auto-generate question and answer")}</span>
        </label>
        <p class="text-xs text-secondary ml-8">
          {gettext(
            "When enabled, select a word from the database and the system will generate the question and correct answer automatically."
          )}
        </p>
      </div>

      <%= if @auto_generate do %>
        <%!-- Auto-generate mode --%>
        <.conjugation_auto_generate_form
          step_form={@step_form}
          question_data={@question_data}
          grammar_forms={@grammar_forms}
        />
      <% else %>
        <%!-- Manual mode (existing behavior) --%>
        <.conjugation_manual_form step_form={@step_form} grammar_forms={@grammar_forms} />
      <% end %>
    </div>
    """
  end

  # Auto-generate mode form
  defp conjugation_auto_generate_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <%!-- Word Type Selection --%>
      <div>
        <label class="label" for="word_type">
          <span class="label-text">{gettext("Word Type")}</span>
        </label>
        <select
          id="word_type"
          name="step[question_data][word_type]"
          class="select select-bordered w-full"
          phx-change="update_conjugation_word_type"
        >
          <option value="" selected={is_nil(@question_data["word_type"])}>
            {gettext("Select type...")}
          </option>
          <option value="verb" selected={@question_data["word_type"] == "verb"}>
            {gettext("Verb (動詞)")}
          </option>
          <option value="adjective" selected={@question_data["word_type"] == "adjective"}>
            {gettext("Adjective (形容詞)")}
          </option>
        </select>
      </div>

      <%!-- Base Word Selection --%>
      <%= if @question_data["word_type"] do %>
        <div>
          <label class="label" for="base_word_search">
            <span class="label-text">{gettext("Select Base Word")}</span>
          </label>
          <div class="relative">
            <input
              type="text"
              id="base_word_search"
              name="step[question_data][base_word_search]"
              value={@question_data["base_word_search"]}
              class="input input-bordered w-full font-jp"
              placeholder={gettext("Type to search for words...")}
              phx-change="search_conjugation_word"
              phx-debounce="300"
            />
            <%= if @question_data["selected_word"] do %>
              <div class="mt-2 p-2 bg-emerald-100 rounded text-emerald-800 text-sm">
                {gettext("Selected:")} <strong>{@question_data["selected_word_text"]}</strong>
                <button
                  type="button"
                  phx-click="clear_selected_conjugation_word"
                  class="ml-2 text-emerald-600 hover:text-emerald-900"
                >
                  {gettext("Change")}
                </button>
              </div>
            <% end %>
          </div>

          <%!-- Search Results --%>
          <%= if @question_data["word_search_results"] && @question_data["word_search_results"] != [] do %>
            <div class="mt-2 border border-base-300 rounded-lg max-h-40 overflow-y-auto">
              <%= for word <- @question_data["word_search_results"] do %>
                <button
                  type="button"
                  phx-click="select_conjugation_word"
                  phx-value-word-id={word.id}
                  phx-value-word-text={word.text}
                  phx-value-word-reading={word.reading}
                  class="w-full text-left p-2 hover:bg-base-200 border-b border-base-200 last:border-b-0"
                >
                  <span class="font-jp font-medium">{word.text}</span>
                  <span class="text-sm text-secondary ml-2">{word.reading}</span>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- Target Form Selection --%>
      <%= if @question_data["selected_word"] do %>
        <div>
          <label class="label" for="target_form">
            <span class="label-text">{gettext("Target Form")}</span>
          </label>
          <select
            id="target_form"
            name="step[question_data][target_form]"
            class="select select-bordered w-full"
            phx-change="update_target_form"
          >
            <option value="" selected={is_nil(@question_data["target_form"])}>
              {gettext("Select target form...")}
            </option>
            <%= for form <- filter_forms_by_word_type(@grammar_forms, @question_data["word_type"]) do %>
              <option
                value={form.name}
                selected={@question_data["target_form"] == form.name}
              >
                {form.display_name}
              </option>
            <% end %>
          </select>
        </div>
      <% end %>

      <%!-- Generated Question Preview --%>
      <%= if @question_data["generated_question"] do %>
        <div class="bg-base-200 rounded-lg p-4">
          <label class="label-text text-xs text-secondary">{gettext("Generated Question")}</label>
          <p class="font-medium mt-1">{@question_data["generated_question"]}</p>
          <input type="hidden" name="step[question]" value={@question_data["generated_question"]} />
        </div>
      <% end %>

      <%!-- Generated Answer Preview --%>
      <%= if @question_data["generated_answer"] do %>
        <div class="bg-emerald-50 rounded-lg p-4 border border-emerald-200">
          <label class="label-text text-xs text-emerald-600">
            {gettext("Correct Answer (Auto-generated)")}
          </label>
          <p class="font-jp font-medium mt-1 text-emerald-800">
            {@question_data["generated_answer"]}
          </p>
          <input type="hidden" name="step[correct_answer]" value={@question_data["generated_answer"]} />
          <input
            type="hidden"
            name="step[question_data][base_word]"
            value={@question_data["selected_word_text"]}
          />
        </div>
      <% end %>
    </div>
    """
  end

  # Manual mode form (existing behavior)
  defp conjugation_manual_form(assigns) do
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
          value={@step_form[:question].value}
          class="input input-bordered w-full"
          placeholder={gettext("e.g., Conjugate this verb to te-form")}
          required
        />
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="label" for="base_word">
            <span class="label-text">{gettext("Base Word")}</span>
          </label>
          <input
            type="text"
            id="base_word"
            name="step[question_data][base_word]"
            value={@step_form[:question_data].value["base_word"]}
            class="input input-bordered w-full font-jp"
            placeholder={gettext("e.g., 食べる")}
            required
          />
        </div>

        <div>
          <label class="label" for="word_type">
            <span class="label-text">{gettext("Word Type")}</span>
          </label>
          <select
            id="word_type"
            name="step[question_data][word_type]"
            class="select select-bordered w-full"
          >
            <option value="verb" selected={@step_form[:question_data].value["word_type"] == "verb"}>
              {gettext("Verb")}
            </option>
            <option
              value="adjective"
              selected={@step_form[:question_data].value["word_type"] == "adjective"}
            >
              {gettext("Adjective")}
            </option>
          </select>
        </div>
      </div>

      <div>
        <label class="label" for="target_form">
          <span class="label-text">{gettext("Target Form")}</span>
        </label>
        <select
          id="target_form"
          name="step[question_data][target_form]"
          class="select select-bordered w-full"
        >
          <option value="">{gettext("Select target form...")}</option>
          <%= for form <- filter_forms_by_word_type(@grammar_forms, @step_form[:question_data].value["word_type"]) do %>
            <option
              value={form.name}
              selected={@step_form[:question_data].value["target_form"] == form.name}
            >
              {form.display_name} ({form.name})
            </option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="label" for="correct_answer">
          <span class="label-text">{gettext("Correct Answer")}</span>
        </label>
        <input
          type="text"
          id="correct_answer"
          name="step[correct_answer]"
          value={@step_form[:correct_answer].value}
          class="input input-bordered w-full font-jp"
          placeholder={gettext("e.g., 食べて")}
          required
        />
      </div>
    </div>
    """
  end

  # Filter grammar forms by word type
  defp filter_forms_by_word_type(forms, word_type) when is_list(forms) and is_binary(word_type) do
    Enum.filter(forms, fn form -> form.word_type == word_type end)
  end

  defp filter_forms_by_word_type(forms, _) when is_list(forms), do: forms
  defp filter_forms_by_word_type(_, _), do: []

  # Type 3: Conjugation Multiple Choice Form
  # Always uses auto-generate mode - teacher selects word, system generates correct answer,
  # teacher adds wrong answer options manually
  defp conjugation_multichoice_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <p class="text-sm text-secondary">
        {gettext("Select a word and target form. The system will generate the question and correct answer. You add the wrong answers.")}
      </p>

      <%!-- Word selection and form generation --%>
      <.conjugation_auto_generate_form
        step_form={@step_form}
        question_data={@step_form[:question_data].value || %{}}
        grammar_forms={@grammar_forms}
      />

      <%!-- Wrong answers section (only shown when we have a generated answer) --%>
      <% question_data = @step_form[:question_data].value || %{} %>
      <% generated_answer = question_data["generated_answer"] || question_data[:generated_answer] %>
      <%= if generated_answer do %>
        <div class="border-t border-base-200 pt-4 mt-4">
          <label class="label">
            <span class="label-text">{gettext("Wrong Answer Options (3-7 options)")}</span>
          </label>
          <p class="text-xs text-secondary mb-2">
            {gettext("Add incorrect conjugations as distractors. The correct answer is already set.")}
          </p>
          
          <%!-- Show correct answer (read-only) --%>
          <div class="flex items-center gap-2 mb-3 p-2 bg-emerald-50 rounded border border-emerald-200">
            <span class="text-emerald-600 text-sm font-medium">{gettext("Correct:")}</span>
            <span class="font-jp font-medium text-emerald-800"><%= generated_answer %></span>
            <input type="hidden" name="step[correct_answer]" value={generated_answer} />
          </div>

          <%!-- Wrong answers list --%>
          <% options = @step_form[:options].value || [] %>
          <% option_count = length(options) %>
          
          <div class="space-y-2 mb-3">
            <%= for {option, idx} <- Enum.with_index(options) do %>
              <div class="flex items-center gap-2">
                <input
                  type="text"
                  name="step[options][]"
                  value={option}
                  class="input input-bordered w-full input-sm font-jp"
                  placeholder={gettext("Wrong option %{num}", num: idx + 1)}
                  readonly
                />
                <button
                  type="button"
                  phx-click="remove_option"
                  phx-value-index={idx}
                  class="btn btn-ghost btn-sm text-error"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              </div>
            <% end %>
          </div>
          
          <%!-- Add new wrong option input --%>
          <div class="flex gap-2">
            <input
              type="text"
              id="new-wrong-option"
              name="new_option_text"
              value=""
              phx-keyup="update_new_option"
              class="input input-bordered flex-1 input-sm font-jp"
              placeholder={gettext("Type a wrong answer...")}
            />
            <button
              type="button"
              phx-click="add_option"
              class="btn btn-outline btn-sm"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Add")}
            </button>
          </div>
          
          <%!-- Option count hint --%>
          <p class={"text-xs mt-2 " <> if option_count < 3, do: "text-warning", else: "text-secondary"}>
            {gettext("%{count} wrong options added (need 3-7)", count: option_count)}
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  # Manual mode for conjugation multichoice (existing behavior)
  defp conjugation_multichoice_manual_form(assigns) do
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
          value={@step_form[:question].value}
          class="input input-bordered w-full"
          placeholder={gettext("e.g., Select the correct te-form of this verb")}
          required
        />
      </div>

      <div>
        <label class="label" for="base_word">
          <span class="label-text">{gettext("Base Word")}</span>
        </label>
        <input
          type="text"
          id="base_word"
          name="step[question_data][base_word]"
          value={@step_form[:question_data].value["base_word"]}
          class="input input-bordered w-full font-jp"
          placeholder={gettext("e.g., 食べる")}
          required
        />
      </div>

      <div>
        <label class="label" for="target_form">
          <span class="label-text">{gettext("Target Form")}</span>
        </label>
        <select
          id="target_form"
          name="step[question_data][target_form]"
          class="select select-bordered w-full"
        >
          <option value="">{gettext("Select target form...")}</option>
          <%= for form <- filter_forms_by_word_type(@grammar_forms, @step_form[:question_data].value["word_type"]) do %>
            <option
              value={form.name}
              selected={@step_form[:question_data].value["target_form"] == form.name}
            >
              {form.display_name}
            </option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="label">
          <span class="label-text">{gettext("Answer Options (4-8 options)")}</span>
        </label>
        <div class="space-y-2">
          <%= for {option, idx} <- Enum.with_index(@step_form[:options].value || []) do %>
            <div class="flex items-center gap-2">
              <input
                type="text"
                name="step[options][]"
                value={option}
                class="input input-bordered w-full input-sm font-jp"
                placeholder={gettext("Option %{num}", num: idx + 1)}
              />
              <button
                type="button"
                phx-click="remove_option"
                phx-value-index={idx}
                class="btn btn-ghost btn-sm text-error"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
          <% end %>
        </div>
        <button
          type="button"
          phx-click="add_option"
          class="btn btn-outline btn-sm mt-2"
        >
          <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Add Option")}
        </button>
      </div>

      <div>
        <label class="label" for="correct_answer">
          <span class="label-text">{gettext("Correct Answer")}</span>
        </label>
        <input
          type="text"
          id="correct_answer"
          name="step[correct_answer]"
          value={@step_form[:correct_answer].value}
          class="input input-bordered w-full font-jp"
          placeholder={gettext("e.g., 食べて")}
          required
        />
      </div>
    </div>
    """
  end

  # Type 4: Word Order Form
  defp word_order_form(assigns) do
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
          value={@step_form[:question].value}
          class="input input-bordered w-full"
          placeholder={gettext("e.g., Arrange the words to form a correct sentence")}
          required
        />
      </div>

      <div>
        <label class="label">
          <span class="label-text">{gettext("Words (enter in correct order)")}</span>
        </label>
        <p class="text-sm text-secondary mb-2">
          {gettext("Words will be shuffled for students. Enter one word per line.")}
        </p>
        <textarea
          name="step[question_data][words]"
          class="textarea textarea-bordered w-full font-jp"
          rows="4"
          placeholder={gettext("今日\nは\nいい\n天気\nです")}
          required
        ><%= @step_form[:question_data].value["words"] %></textarea>
      </div>

      <div>
        <label class="label" for="correct_answer">
          <span class="label-text">{gettext("Correct Sentence")}</span>
        </label>
        <input
          type="text"
          id="correct_answer"
          name="step[correct_answer]"
          value={@step_form[:correct_answer].value}
          class="input input-bordered w-full font-jp"
          placeholder={gettext("e.g., 今日はいい天気です")}
          required
        />
      </div>
    </div>
    """
  end

  attr :element, :map, required: true
  attr :grammar_forms, :list, default: []

  defp pattern_element_bubble(%{element: nil} = assigns) do
    ~H"""
    <span class="px-2 py-1 rounded text-xs font-medium bg-gray-300 text-gray-700">
      ...
    </span>
    """
  end

  defp pattern_element_bubble(assigns) do
    label =
      case assigns.element["type"] do
        "word_slot" ->
          word_type = String.capitalize(assigns.element["word_type"] || "word")

          # Add grammar form if selected
          grammar_form_id = assigns.element["grammar_form"]

          grammar_form_name =
            if grammar_form_id && grammar_form_id != "" do
              form = Enum.find(assigns.grammar_forms, fn f -> f.id == grammar_form_id end)
              if form, do: form.display_name, else: nil
            else
              nil
            end

          if grammar_form_name do
            word_type <> " (" <> grammar_form_name <> ")"
          else
            word_type
          end

        "word_class" ->
          gettext("Class: %{name}", name: assigns.element["word_class_name"] || "...")

        "literal" ->
          text = assigns.element["text"]
          if text not in [nil, ""], do: text, else: "..."

        _ ->
          "..."
      end

    assigns = assign(assigns, :label, label)

    ~H"""
    <span class={[
      "px-2 py-1 rounded text-xs font-medium",
      @element["type"] == "word_slot" && "bg-emerald-500 text-white",
      @element["type"] == "word_class" && "bg-purple-400 text-white",
      @element["type"] == "literal" && "bg-white text-gray-900 border border-base-300"
    ]}>
      {@label}
    </span>
    """
  end

  # Pattern Element Configuration Component
  defp pattern_element_config(assigns) do
    ~H"""
    <div class="bg-base-100 rounded p-3 border border-base-300">
      <div class="flex items-center justify-between mb-2">
        <span class="text-sm font-medium">
          {gettext("Element %{idx}:", idx: @index + 1)}
          <span class={[
            "ml-1 px-1.5 py-0.5 rounded text-xs",
            @element["type"] == "word_slot" && "bg-emerald-100 text-emerald-700",
            @element["type"] == "word_class" && "bg-purple-100 text-purple-700",
            @element["type"] == "literal" && "bg-gray-100 text-gray-700"
          ]}>
            {format_element_type(@element["type"])}
          </span>
        </span>
        <button
          type="button"
          phx-click="remove_pattern_element"
          phx-value-index={@index}
          class="text-error hover:opacity-70"
          title={gettext("Remove")}
        >
          <.icon name="hero-trash" class="w-4 h-4" />
        </button>
      </div>

      <%!-- Word Slot Configuration --%>
      <%= if @element["type"] == "word_slot" do %>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <%!-- Word Type Selection --%>
          <div>
            <label class="label-text text-xs">{gettext("Word Type")}</label>
            <select
              name={"step[question_data][pattern][#{@index}][word_type]"}
              class="select select-bordered select-sm w-full mt-1"
              phx-change="update_pattern_element"
              phx-value-index={@index}
              phx-value-field="word_type"
            >
              <option value="verb" selected={@element["word_type"] == "verb"}>
                {gettext("Verb (動詞)")}
              </option>
              <option value="adjective" selected={@element["word_type"] == "adjective"}>
                {gettext("Adjective (形容詞)")}
              </option>
              <option value="noun" selected={@element["word_type"] == "noun"}>
                {gettext("Noun (名詞)")}
              </option>
              <option value="particle" selected={@element["word_type"] == "particle"}>
                {gettext("Particle (助詞)")}
              </option>
              <option value="expression" selected={@element["word_type"] == "expression"}>
                {gettext("Expression (表現)")}
              </option>
            </select>
          </div>

          <%!-- Grammar Form (for verbs/adjectives) --%>
          <%= if @element["word_type"] in ["verb", "adjective"] do %>
            <div>
              <label class="label-text text-xs">{gettext("Required Form")}</label>
              <select
                name={"step[question_data][pattern][#{@index}][grammar_form]"}
                class="select select-bordered select-sm w-full mt-1"
                phx-change="update_pattern_element"
                phx-value-index={@index}
                phx-value-field="grammar_form"
              >
                <option value="" selected={is_nil(@element["grammar_form"])}>
                  {gettext("Any form")}
                </option>
                <%= for form <- Enum.filter(@grammar_forms || [], fn f -> f.word_type == @element["word_type"] end) do %>
                  <option value={form.id} selected={@element["grammar_form"] == form.id}>
                    {form.display_name}
                  </option>
                <% end %>
              </select>
            </div>
          <% end %>

          <%!-- Optional Checkbox --%>
          <div class="flex items-end pb-2">
            <label class="label cursor-pointer justify-start gap-2">
              <input
                type="checkbox"
                name={"step[question_data][pattern][#{@index}][optional]"}
                class="checkbox checkbox-sm"
                checked={@element["optional"] == true}
                phx-change="update_pattern_element"
                phx-value-index={@index}
                phx-value-field="optional"
              />
              <span class="label-text text-sm">{gettext("Optional")}</span>
            </label>
          </div>
        </div>
      <% end %>

      <%!-- Word Class Configuration --%>
      <%= if @element["type"] == "word_class" do %>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <%!-- Word Class Selection --%>
          <div>
            <label class="label-text text-xs">{gettext("Word Class")}</label>
            <select
              name={"step[question_data][pattern][#{@index}][word_class_id]"}
              class="select select-bordered select-sm w-full mt-1"
              phx-change="update_pattern_element"
              phx-value-index={@index}
              phx-value-field="word_class_id"
            >
              <option value="">{gettext("Select a class...")}</option>
              <%= for class <- @word_classes do %>
                <option value={class.id} selected={@element["word_class_id"] == class.id}>
                  {class.display_name}
                </option>
              <% end %>
            </select>
          </div>

          <%!-- Optional Checkbox --%>
          <div class="flex items-end pb-2">
            <label class="label cursor-pointer justify-start gap-2">
              <input
                type="checkbox"
                name={"step[question_data][pattern][#{@index}][optional]"}
                class="checkbox checkbox-sm"
                checked={@element["optional"] == true}
                phx-change="update_pattern_element"
                phx-value-index={@index}
                phx-value-field="optional"
              />
              <span class="label-text text-sm">{gettext("Optional")}</span>
            </label>
          </div>
        </div>
      <% end %>

      <%!-- Literal Text Configuration --%>
      <%= if @element["type"] == "literal" do %>
        <div>
          <label class="label-text text-xs">{gettext("Text")}</label>
          <input
            type="text"
            name={"step[question_data][pattern][#{@index}][text]"}
            value={@element["text"] || ""}
            class="input input-bordered input-sm w-full mt-1 font-jp"
            placeholder={gettext("e.g., ください")}
            phx-change="update_pattern_element"
            phx-value-index={@index}
            phx-value-field="text"
          />
        </div>
      <% end %>
    </div>
    """
  end

  # Normalize pattern to always be a list
  # Form data may send it as a map like %{"0" => elem0, "1" => elem1}
  defp normalize_pattern(nil), do: []
  defp normalize_pattern(pattern) when is_list(pattern), do: pattern

  defp normalize_pattern(pattern) when is_map(pattern) do
    pattern
    |> Enum.sort_by(fn {k, _v} ->
      case Integer.parse(k) do
        {n, _} -> n
        :error -> 0
      end
    end)
    |> Enum.map(fn {_k, v} -> ensure_element_type(v) end)
  end

  defp normalize_pattern(_), do: []

  # Ensure element has a type field
  defp ensure_element_type(%{"type" => _} = element), do: element

  defp ensure_element_type(%{"word_type" => _} = element),
    do: Map.put(element, "type", "word_slot")

  defp ensure_element_type(%{"word_class_id" => _} = element),
    do: Map.put(element, "type", "word_class")

  defp ensure_element_type(%{"text" => _} = element), do: Map.put(element, "type", "literal")
  defp ensure_element_type(element), do: Map.put(element, "type", "literal")

  defp format_element_type("word_slot"), do: gettext("Word")
  defp format_element_type("word_class"), do: gettext("Word Class")
  defp format_element_type("literal"), do: gettext("Text")
  defp format_element_type(_), do: gettext("Unknown")
end
