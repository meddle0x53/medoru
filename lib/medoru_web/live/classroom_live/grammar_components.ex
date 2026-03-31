defmodule MedoruWeb.ClassroomLive.GrammarComponents do
  @moduledoc """
  UI components for grammar test steps.
  """
  use Phoenix.Component

  use Gettext, backend: MedoruWeb.Gettext

  alias MedoruWeb.CoreComponents

  @doc """
  Renders a sentence validation question with text input and retry counter.
  """
  attr :step, :map, required: true
  attr :answer, :string, default: ""
  attr :wrong_attempts, :integer, default: 0
  attr :step_id, :any, required: true

  def sentence_validation_question(assigns) do
    ~H"""
    <div class="space-y-4" id={"sentence-validation-#{@step_id}"}>
      <div class="bg-base-200 p-4 rounded-lg">
        <p class="text-sm text-secondary mb-2">
          {gettext("Build a sentence that follows this pattern:")}
        </p>
        <div class="flex flex-wrap gap-2 items-center">
          <%= for element <- @step.question_data["pattern"] || [] do %>
            <%= case element["type"] do %>
              <% "literal" -> %>
                <span class="px-2 py-1 bg-base-300 rounded text-base-content font-medium">
                  {element["text"]}
                </span>
              <% "word_slot" -> %>
                <span class="px-2 py-1 bg-primary/20 rounded text-primary font-medium border border-primary/30">
                  <%= if element["word_class"] do %>
                    {element["word_class"]}
                  <% else %>
                    {element["word_type"]}
                  <% end %>
                  <%= if element["forms"] && length(element["forms"]) > 0 do %>
                    ({Enum.join(element["forms"], ", ")})
                  <% end %>
                </span>
              <% _ -> %>
                <span class="px-2 py-1 bg-base-300 rounded">{element["type"]}</span>
            <% end %>
          <% end %>
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-base-content mb-2">
          {gettext("Your sentence:")}
        </label>
        <.input
          type="text"
          name="answer"
          id={"answer-#{@step_id}"}
          value={@answer}
          placeholder={gettext("Type your sentence here...")}
          class="w-full"
          required
        />
      </div>

      <%= if @wrong_attempts > 0 do %>
        <div class="bg-warning/10 border border-warning/30 rounded-lg p-3">
          <p class="text-sm text-warning flex items-center gap-2">
            <.icon name="hero-exclamation-triangle" class="w-4 h-4" />
            {gettext("Incorrect. Attempt %{current}/4. Points: %{points}",
              current: @wrong_attempts + 1,
              points: max(1, 10 - @wrong_attempts * 3)
            )}
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a conjugation question with text input.
  """
  attr :step, :map, required: true
  attr :answer, :string, default: ""
  attr :step_id, :any, required: true

  def conjugation_question(assigns) do
    question_data = assigns.step.question_data || %{}

    assigns =
      assign(assigns,
        word: question_data["base_word"] || question_data["word"],
        form: question_data["target_form"] || question_data["form"],
        word_type: question_data["word_type"]
      )

    ~H"""
    <div class="space-y-4" id={"conjugation-#{@step_id}"}>
      <div class="bg-base-200 p-4 rounded-lg text-center">
        <p class="text-sm text-secondary mb-3">{gettext("Conjugate this word:")}</p>
        <div class="flex items-center justify-center gap-4">
          <div class="text-2xl font-bold text-base-content">{@word}</div>
          <.icon name="hero-arrow-right" class="w-5 h-5 text-secondary" />
          <span class="px-3 py-1 bg-primary/20 text-primary rounded-lg font-medium">
            {@form}
          </span>
        </div>
        <%= if @word_type do %>
          <p class="text-xs text-secondary mt-2">({@word_type})</p>
        <% end %>
      </div>

      <div>
        <label class="block text-sm font-medium text-base-content mb-2">
          {gettext("Your answer:")}
        </label>
        <.input
          type="text"
          name="answer"
          id={"answer-#{@step_id}"}
          value={@answer}
          placeholder={gettext("Type the conjugated form...")}
          class="w-full"
          required
        />
      </div>

      <p class="text-xs text-secondary">
        <.icon name="hero-information-circle" class="w-3 h-3 mr-1" />
        {gettext("Single attempt only. 3 points for correct answer.")}
      </p>
    </div>
    """
  end

  @doc """
  Renders a conjugation multichoice question with radio options.
  """
  attr :step, :map, required: true
  attr :step_id, :any, required: true

  def conjugation_multichoice_question(assigns) do
    question_data = assigns.step.question_data || %{}

    assigns =
      assign(assigns,
        word: question_data["base_word"] || question_data["word"],
        form: question_data["target_form"] || question_data["form"],
        word_type: question_data["word_type"],
        options: assigns.step.options || []
      )

    ~H"""
    <div class="space-y-4" id={"conjugation-multichoice-#{@step_id}"}>
      <div class="bg-base-200 p-4 rounded-lg text-center">
        <p class="text-sm text-secondary mb-3">{gettext("Select the correct conjugation:")}</p>
        <div class="flex items-center justify-center gap-4">
          <div class="text-2xl font-bold text-base-content">{@word}</div>
          <.icon name="hero-arrow-right" class="w-5 h-5 text-secondary" />
          <span class="px-3 py-1 bg-primary/20 text-primary rounded-lg font-medium">
            {@form}
          </span>
        </div>
        <%= if @word_type do %>
          <p class="text-xs text-secondary mt-2">({@word_type})</p>
        <% end %>
      </div>

      <div class="space-y-2">
        <%= for option <- @options do %>
          <label class="flex items-center gap-3 p-4 bg-base-200 rounded-lg cursor-pointer hover:bg-base-300 transition-colors">
            <input
              type="radio"
              name="answer"
              value={option}
              required
              class="radio radio-primary"
            />
            <span class="text-lg text-base-content">{option}</span>
          </label>
        <% end %>
      </div>

      <p class="text-xs text-secondary">
        <.icon name="hero-information-circle" class="w-3 h-3 mr-1" />
        {gettext("Single attempt only. 3 points for correct answer.")}
      </p>
    </div>
    """
  end

  @doc """
  Renders a word order question with click-to-add UI.
  """
  attr :step, :map, required: true
  attr :step_id, :any, required: true
  attr :answer, :list, default: []

  def word_order_question(assigns) do
    question_data = assigns.step.question_data || %{}

    # Parse words from newline-separated string or use existing list
    words = parse_words(question_data["words"])

    # Use pre-shuffled words if available, otherwise shuffle
    shuffled_words = question_data["shuffled_words"] || Enum.shuffle(words)

    assigns =
      assign(assigns,
        words: words,
        shuffled_words: shuffled_words,
        answer: assigns[:answer] || []
      )

    ~H"""
    <div class="space-y-4" id={"word-order-#{@step_id}"}>
      <div class="bg-base-200 p-4 rounded-lg">
        <p class="text-sm text-secondary mb-2">
          {gettext("Arrange the words to form a correct sentence:")}
        </p>
        <p class="text-xs text-info">
          <.icon name="hero-information-circle" class="w-3 h-3 mr-1" />
          {gettext("Click words to add them. Click on selected words to remove them.")}
        </p>
      </div>

      <%!-- Source words (shuffled) --%>
      <div class="space-y-2">
        <p class="text-sm font-medium text-secondary">{gettext("Available words:")}</p>
        <div class="flex flex-wrap gap-2 min-h-[48px]">
          <%= for word <- @shuffled_words do %>
            <button
              type="button"
              phx-click="word_order_click"
              phx-value-word={word}
              phx-value-action="add"
              class="px-3 py-2 bg-base-300 hover:bg-primary/20 rounded-lg text-base-content font-medium transition-colors border border-base-300 hover:border-primary"
            >
              {word}
            </button>
          <% end %>
        </div>
      </div>

      <%!-- Answer area (where words are placed) --%>
      <div class="space-y-2">
        <p class="text-sm font-medium text-secondary">{gettext("Your sentence:")}</p>
        <div class="min-h-[60px] p-4 bg-base-200 rounded-lg border-2 border-dashed border-base-300 flex flex-wrap gap-2 items-center">
          <%= if [] == [] do %>
            <span class="text-secondary text-sm italic">
              {gettext("(Click words above to build sentence)")}
            </span>
          <% end %>
          <%= for {word, index} <- Enum.with_index(@answer || []) do %>
            <button
              type="button"
              phx-click="word_order_remove"
              phx-value-index={index}
              class="px-3 py-2 bg-primary text-primary-content rounded-lg font-medium transition-colors hover:bg-primary/80"
            >
              {word}
            </button>
          <% end %>
        </div>
      </div>

      <%!-- Hidden input for form submission --%>
      <input
        type="hidden"
        name="answer"
        id={"word-order-answer-#{@step_id}"}
        value={Enum.join(@answer || [], "")}
      />

      <div class="flex gap-2">
        <button
          type="button"
          phx-click="word_order_clear"
          class="btn btn-outline btn-sm"
        >
          <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" />
          {gettext("Clear")}
        </button>
      </div>

      <p class="text-xs text-secondary">
        <.icon name="hero-information-circle" class="w-3 h-3 mr-1" />
        {gettext("Single attempt only. 3 points for correct answer.")}
      </p>
    </div>
    """
  end

  # Parse words from various formats (newline string, comma-separated, or list)
  defp parse_words(nil), do: []
  defp parse_words(words) when is_list(words), do: words

  defp parse_words(words) when is_binary(words) do
    words
    |> String.split(~r/[\n,]/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp icon(assigns) do
    apply(CoreComponents, :icon, [assigns])
  end

  defp input(assigns) do
    apply(CoreComponents, :input, [assigns])
  end
end
