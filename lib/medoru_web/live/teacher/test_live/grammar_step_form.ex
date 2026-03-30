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
          <%= for form <- @grammar_forms do %>
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

  # Type 3: Conjugation Multiple Choice Form
  defp conjugation_multichoice_form(assigns) do
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
          <%= for form <- @grammar_forms do %>
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
