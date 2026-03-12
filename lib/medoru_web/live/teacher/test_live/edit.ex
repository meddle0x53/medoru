defmodule MedoruWeb.Teacher.TestLive.Edit do
  @moduledoc """
  LiveView for editing a teacher test and managing its steps.

  Features:
  - View all test steps in order
  - Drag-drop reordering of steps
  - Add new steps (multichoice, reading_text, writing)
  - Delete steps with confirmation
  - Preview step content
  - Mark test as ready when done
  """
  use MedoruWeb, :live_view

  alias Medoru.Tests
  alias Medoru.Tests.TestStep
  alias Medoru.Content
  alias MedoruWeb.StepBuilderComponents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    test = Tests.get_test!(id)

    # Verify ownership
    if not Tests.is_test_owner?(test, user.id) do
      {:ok,
       socket
       |> put_flash(:error, "You can only edit your own tests.")
       |> push_navigate(to: ~p"/teacher/tests")}
    else
      # Only allow editing in_progress tests
      if test.setup_state != "in_progress" do
        {:ok,
         socket
         |> put_flash(:info, "This test can no longer be edited.")
         |> push_navigate(to: ~p"/teacher/tests/#{test.id}")}
      else
        steps = Tests.list_test_steps(test.id)

        socket =
          socket
          |> assign(:page_title, "Edit #{test.title}")
          |> assign(:test, test)
          |> assign(:steps, steps)
          |> assign(:step_count, length(steps))
          |> assign(:show_step_selector, false)
          |> assign(:show_step_form, false)
          |> assign(:editing_step, nil)
          |> assign(:step_form, nil)
          |> assign(:step_changeset, nil)
          |> assign(:available_words, [])
          |> assign(:word_search_query, "")
          |> assign(:available_kanji, [])
          |> assign(:kanji_search_query, "")
          |> assign(:search_type, nil)

        {:ok, socket}
      end
    end
  end

  @impl true
  def handle_event("open_step_selector", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_step_selector, true)
     |> assign(:show_step_form, false)}
  end

  @impl true
  def handle_event("close_step_selector", _params, socket) do
    {:noreply, assign(socket, :show_step_selector, false)}
  end

  @impl true
  def handle_event("select_step_type", %{"type" => type_str}, socket) do
    type = String.to_existing_atom(type_str)
    _test = socket.assigns.test

    # Calculate next order index
    next_index = socket.assigns.step_count

    # Create initial changeset based on type
    attrs = %{
      "order_index" => next_index,
      "step_type" => "vocabulary",
      "question_type" => type_str,
      "points" => TestStep.default_points(type)
    }

    changeset = TestStep.changeset(%TestStep{}, attrs)

    socket =
      socket
      |> assign(:show_step_selector, false)
      |> assign(:show_step_form, true)
      |> assign(:editing_step, nil)
      |> assign(:step_changeset, changeset)
      |> assign(:step_form, to_form(changeset, as: :step))
      |> assign(:step_type, type)
      |> assign(:word_search_query, "")
      |> assign(:available_words, [])
      |> assign(:kanji_search_query, "")
      |> assign(:available_kanji, [])
      |> assign(:search_type, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_step_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_step_form, false)
     |> assign(:step_changeset, nil)
     |> assign(:step_form, nil)}
  end

  @impl true
  def handle_event("validate_step", %{"step" => step_params}, socket) do
    attrs = parse_options_from_params(step_params)

    changeset =
      %TestStep{}
      |> TestStep.changeset(attrs)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:step_changeset, changeset)
     |> assign(:step_form, to_form(changeset, as: :step))}
  end

  @impl true
  def handle_event("save_step", %{"step" => step_params}, socket) do
    test = socket.assigns.test

    # Parse options from textarea (newline-separated)
    attrs =
      step_params
      |> parse_options_from_params()
      |> Map.put("order_index", socket.assigns.step_count)

    case Tests.create_test_step(test, attrs) do
      {:ok, _step} ->
        steps = Tests.list_test_steps(test.id)
        test = Tests.get_test!(test.id)

        {:noreply,
         socket
         |> assign(:steps, steps)
         |> assign(:step_count, length(steps))
         |> assign(:test, test)
         |> assign(:show_step_form, false)
         |> assign(:step_changeset, nil)
         |> assign(:step_form, nil)
         |> put_flash(:info, "Step added successfully.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:step_changeset, changeset)
         |> assign(:step_form, to_form(changeset, as: :step))
         |> put_flash(:error, "Failed to save step. Please check the form.")}
    end
  end

  @impl true
  def handle_event("edit_step", %{"step-id" => step_id}, socket) do
    step = Tests.get_test_step(step_id)

    if step do
      changeset = TestStep.changeset(step, %{})

      {:noreply,
       socket
       |> assign(:show_step_form, true)
       |> assign(:editing_step, step)
       |> assign(:step_changeset, changeset)
       |> assign(:step_form, to_form(changeset))
       |> assign(:step_type, step.question_type)}
    else
      {:noreply, put_flash(socket, :error, "Step not found.")}
    end
  end

  @impl true
  def handle_event("update_step", %{"step" => step_params}, socket) do
    step = socket.assigns.editing_step
    attrs = parse_options_from_params(step_params)

    case Tests.update_test_step(step, attrs) do
      {:ok, _updated_step} ->
        test = socket.assigns.test
        steps = Tests.list_test_steps(test.id)
        test = Tests.get_test!(test.id)

        {:noreply,
         socket
         |> assign(:steps, steps)
         |> assign(:test, test)
         |> assign(:show_step_form, false)
         |> assign(:editing_step, nil)
         |> assign(:step_changeset, nil)
         |> assign(:step_form, nil)
         |> put_flash(:info, "Step updated successfully.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:step_changeset, changeset)
         |> assign(:step_form, to_form(changeset, as: :step))}
    end
  end

  @impl true
  def handle_event("delete_step", %{"step-id" => step_id}, socket) do
    step = Tests.get_test_step(step_id)

    if step do
      case Tests.delete_test_step(step) do
        {:ok, _} ->
          test = socket.assigns.test
          steps = Tests.list_test_steps(test.id)
          test = Tests.get_test!(test.id)

          {:noreply,
           socket
           |> assign(:steps, steps)
           |> assign(:step_count, length(steps))
           |> assign(:test, test)
           |> put_flash(:info, "Step deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete step.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Step not found.")}
    end
  end

  @impl true
  def handle_event("reorder_steps", %{"step_ids" => step_ids}, socket) do
    test_id = socket.assigns.test.id

    # Update order in database
    Tests.reorder_steps(test_id, step_ids)

    # Reload steps
    steps = Tests.list_test_steps(test_id)

    {:noreply,
     socket
     |> assign(:steps, steps)
     |> put_flash(:info, "Steps reordered.")}
  end

  @impl true
  def handle_event("mark_ready", _params, socket) do
    test = socket.assigns.test

    if socket.assigns.step_count == 0 do
      {:noreply, put_flash(socket, :error, "Add at least one step before marking ready.")}
    else
      case Tests.mark_test_ready(test) do
        {:ok, _updated_test} ->
          {:noreply,
           socket
           |> put_flash(:info, "Test marked as ready for publishing.")
           |> push_navigate(to: ~p"/teacher/tests/#{test.id}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update test status.")}
      end
    end
  end

  @impl true
  def handle_event("search_words", %{"value" => query}, socket) do
    words =
      if String.length(query) >= 1 do
        Content.search_words(query, limit: 10)
      else
        []
      end

    # Detect search type based on input
    search_type = detect_search_type(query)

    {:noreply,
     socket
     |> assign(:word_search_query, query)
     |> assign(:available_words, words)
     |> assign(:search_type, search_type)}
  end

  @impl true
  def handle_event("select_word", %{"word-id" => word_id}, socket) do
    word = Content.get_word!(word_id)
    search_type = socket.assigns.search_type

    # Update the form with word info - merge with existing form data
    current_form = socket.assigns.step_form
    step_type = socket.assigns.step_type

    # Generate question based on search type and step type
    {question, correct_answer} =
      case {step_type, search_type} do
        {:multichoice, :reading} ->
          # User searched by reading (hiragana/katakana)
          {"How do you read \"#{word.meaning}\"?", word.text}

        {:multichoice, _} ->
          # User searched by meaning (English) or other
          {"What is the meaning of \"#{word.text}\"?", word.meaning}

        {_, _} ->
          # For reading_text and other types, use default
          {"What is the meaning of \"#{word.text}\"?", word.meaning}
      end

    # For multichoice, ensure correct_answer is in options
    existing_options = current_form[:options].value || []
    options =
      if step_type == :multichoice and correct_answer not in existing_options do
        [correct_answer | existing_options]
      else
        existing_options
      end

    updated_params = %{
      "question" => question,
      "correct_answer" => correct_answer,
      "word_id" => word_id,
      "options" => options,
      "hints" => current_form[:hints].value,
      "explanation" => current_form[:explanation].value
    }

    changeset =
      %TestStep{}
      |> TestStep.changeset(updated_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:step_changeset, changeset)
     |> assign(:step_form, to_form(changeset, as: :step))
     |> assign(:word_search_query, "")
     |> assign(:available_words, [])
     |> assign(:search_type, nil)}
  end

  @impl true
  def handle_event("search_kanji", %{"value" => query}, socket) do
    kanji =
      if String.length(query) >= 1 do
        Content.search_kanji(query, limit: 10)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:kanji_search_query, query)
     |> assign(:available_kanji, kanji)}
  end

  @impl true
  def handle_event("select_kanji", %{"kanji-id" => kanji_id}, socket) do
    kanji = Content.get_kanji_with_readings!(kanji_id)

    # Get readings for the kanji
    on_readings =
      kanji.kanji_readings
      |> Enum.filter(&(&1.reading_type == :on))
      |> Enum.map(& &1.reading)

    kun_readings =
      kanji.kanji_readings
      |> Enum.filter(&(&1.reading_type == :kun))
      |> Enum.map(& &1.reading)

    # Build readings display for explanation
    readings_text =
      case {on_readings, kun_readings} do
        {[], []} -> ""
        {on, []} -> "On: #{Enum.join(on, ", ")}"
        {[], kun} -> "Kun: #{Enum.join(kun, ", ")}"
        {on, kun} -> "On: #{Enum.join(on, ", ")}, Kun: #{Enum.join(kun, ", ")}"
      end

    # For the question, use the first meaning as the target word
    target_meaning = List.first(kanji.meanings) || ""

    updated_params = %{
      "question" => "Draw the kanji for \"#{target_meaning}\"",
      "correct_answer" => kanji.character,
      "kanji_id" => kanji_id,
      "hints" => [],
      "explanation" => readings_text
    }

    changeset =
      %TestStep{}
      |> TestStep.changeset(updated_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:step_changeset, changeset)
     |> assign(:step_form, to_form(changeset, as: :step))
     |> assign(:kanji_search_query, "")
     |> assign(:available_kanji, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8 pb-24">
        <%!-- Toolbar --%>
        <StepBuilderComponents.step_builder_toolbar
          test={@test}
          step_count={@step_count}
        />

        <%!-- Test Summary --%>
        <StepBuilderComponents.test_summary_card
          test={@test}
          step_count={@step_count}
        />

        <%!-- Step Builder --%>
        <div class="bg-base-100 rounded-2xl border border-base-200 p-6">
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-lg font-semibold text-base-content">Test Steps</h2>
            <%= if @step_count > 0 do %>
              <button
                type="button"
                phx-click="open_step_selector"
                class="btn btn-primary btn-sm gap-2"
              >
                <.icon name="hero-plus" class="w-4 h-4" /> Add Step
              </button>
            <% end %>
          </div>

          <%!-- Steps List --%>
          <StepBuilderComponents.step_builder_container
            steps={@steps}
            test={@test}
          />
        </div>

        <%!-- Floating Action Button (visible when steps exist) --%>
        <%= if @step_count > 0 do %>
          <StepBuilderComponents.add_step_fab />
        <% end %>
      </div>

      <%!-- Step Selector Modal --%>
      <%= if @show_step_selector do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div class="bg-base-100 rounded-2xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div class="p-6 border-b border-base-200">
              <div class="flex items-center justify-between">
                <h3 class="text-xl font-bold text-base-content">Add Step</h3>
                <button
                  type="button"
                  phx-click="close_step_selector"
                  class="p-2 text-secondary hover:text-base-content hover:bg-base-200 rounded-lg transition-colors"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>
              <p class="text-secondary mt-1">Choose the type of question you want to add.</p>
            </div>

            <div class="p-6">
              <StepBuilderComponents.step_type_selector on_select="select_step_type" />
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Step Form Modal --%>
      <%= if @show_step_form do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div class="bg-base-100 rounded-2xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div class="p-6 border-b border-base-200">
              <div class="flex items-center justify-between">
                <h3 class="text-xl font-bold text-base-content">
                  <%= if @editing_step do %>
                    Edit Step
                  <% else %>
                    New {format_question_type(@step_type)} Step
                  <% end %>
                </h3>
                <button
                  type="button"
                  phx-click="close_step_form"
                  class="p-2 text-secondary hover:text-base-content hover:bg-base-200 rounded-lg transition-colors"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>
            </div>

            <div class="p-6">
              <.form
                for={@step_form}
                as={:step}
                phx-change="validate_step"
                phx-submit={if @editing_step, do: "update_step", else: "save_step"}
                class="space-y-6"
              >
                <%!-- Hidden fields --%>
                <input type="hidden" name="step[question_type]" value={@step_type} />
                <input type="hidden" name="step[step_type]" value="vocabulary" />
                <input type="hidden" name="step[points]" value={TestStep.default_points(@step_type)} />
                <input type="hidden" name="step[kanji_id]" value={@step_form[:kanji_id].value} />
                <input type="hidden" name="step[word_id]" value={@step_form[:word_id].value} />

                <%!-- Question --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    Question
                  </label>
                  <.input
                    field={@step_form[:question]}
                    type="textarea"
                    rows="3"
                    placeholder="Enter your question..."
                  />
                </div>

                <%!-- Kanji Search (for writing type) --%>
                <%= if @step_type == :writing do %>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-2">
                      Select Kanji
                    </label>
                    <input
                      type="text"
                      phx-keyup="search_kanji"
                      phx-debounce="300"
                      class="input input-bordered w-full"
                      placeholder="Type kanji character, meaning, or reading..."
                      value={@kanji_search_query}
                    />
                    <%= if length(@available_kanji) > 0 do %>
                      <div class="mt-2 bg-base-200 rounded-lg p-2 max-h-40 overflow-y-auto">
                        <%= for kanji <- @available_kanji do %>
                          <% readings =
                            if is_list(kanji.kanji_readings) and length(kanji.kanji_readings) > 0,
                              do: Enum.map_join(kanji.kanji_readings, ", ", & &1.reading),
                              else: "" %>
                          <button
                            type="button"
                            phx-click="select_kanji"
                            phx-value-kanji-id={kanji.id}
                            class="w-full text-left p-2 hover:bg-base-300 rounded-lg transition-colors"
                          >
                            <div class="flex items-center justify-between">
                              <span class="text-2xl font-medium">{kanji.character}</span>
                              <div class="text-right">
                                <div class="text-sm font-medium">
                                  {Enum.join(kanji.meanings, ", ")}
                                </div>
                                <div class="text-xs text-secondary">{readings}</div>
                              </div>
                            </div>
                          </button>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%!-- Word Search (for multichoice and reading types) --%>
                <%= if @step_type in [:multichoice, :reading_text] do %>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-2">
                      Link to Word (optional)
                      <%= case @search_type do %>
                        <% :reading -> %>
                          <span class="text-xs text-info ml-2">Reading search detected</span>
                        <% :meaning -> %>
                          <span class="text-xs text-success ml-2">Meaning search detected</span>
                        <% _ -> %>
                      <% end %>
                    </label>
                    <input
                      type="text"
                      phx-keyup="search_words"
                      phx-debounce="300"
                      class="input input-bordered w-full"
                      placeholder="Type to search words..."
                      value={@word_search_query}
                    />
                    <%= if length(@available_words) > 0 do %>
                      <div class="mt-2 bg-base-200 rounded-lg p-2 max-h-40 overflow-y-auto">
                        <%= for word <- @available_words do %>
                          <button
                            type="button"
                            phx-click="select_word"
                            phx-value-word-id={word.id}
                            class="w-full text-left p-2 hover:bg-base-300 rounded-lg transition-colors"
                          >
                            <div class="flex items-center justify-between">
                              <span class="font-medium">{word.text}</span>
                              <span class="text-sm text-secondary">{word.meaning}</span>
                            </div>
                          </button>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%!-- Correct Answer --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    Correct Answer
                  </label>
                  <.input
                    field={@step_form[:correct_answer]}
                    type="text"
                    placeholder="Enter the correct answer..."
                  />
                </div>

                <%!-- Options for multichoice --%>
                <%= if @step_type == :multichoice do %>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-2">
                      Answer Options (one per line, include correct answer)
                    </label>
                    <textarea
                      name="step[options]"
                      rows="4"
                      class="textarea textarea-bordered w-full"
                      placeholder="Option 1&#10;Option 2&#10;Option 3&#10;Option 4"
                    >
                    <%= format_options(@step_form[:options].value) %></textarea>
                  </div>
                <% end %>

                <%!-- Hints --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    Hint (optional)
                  </label>
                  <.input
                    field={@step_form[:hints]}
                    type="text"
                    placeholder="Give students a hint..."
                  />
                </div>

                <%!-- Explanation --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    Explanation (shown after answering)
                  </label>
                  <.input
                    field={@step_form[:explanation]}
                    type="textarea"
                    rows="2"
                    placeholder="Explain the correct answer..."
                  />
                </div>

                <%!-- Form Actions --%>
                <div class="flex items-center justify-end gap-3 pt-4 border-t border-base-200">
                  <button
                    type="button"
                    phx-click="close_step_form"
                    class="btn btn-ghost"
                  >
                    Cancel
                  </button>
                  <button type="submit" class="btn btn-primary">
                    <%= if @editing_step do %>
                      Update Step
                    <% else %>
                      Add Step
                    <% end %>
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  # Helper functions

  defp format_question_type(:multichoice), do: "Multiple Choice"
  defp format_question_type(:reading_text), do: "Reading"
  defp format_question_type(:writing), do: "Writing"
  defp format_question_type(other), do: to_string(other)

  defp format_options(nil), do: ""
  defp format_options(options) when is_list(options), do: Enum.join(options, "\n")
  defp format_options(_), do: ""

  defp parse_options_from_params(%{"options" => options_text} = params)
       when is_binary(options_text) do
    options =
      options_text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    params = Map.put(params, "options", options)
    parse_options_from_params(params)
  end

  defp parse_options_from_params(%{"hints" => hints_text} = params)
       when is_binary(hints_text) do
    hints =
      hints_text
      |> String.trim()
      |> case do
        "" -> []
        text -> [text]
      end

    Map.put(params, "hints", hints)
  end

  defp parse_options_from_params(params), do: params

  # Detects if the search query is hiragana/katakana (reading search) or English (meaning search)
  defp detect_search_type(""), do: nil

  defp detect_search_type(query) do
    query = String.trim(query)

    # Check if query contains hiragana (\u3040-\u309F) or katakana (\u30A0-\u30FF)
    hiragana_range = ~r/[\x{3040}-\x{309F}]/u
    katakana_range = ~r/[\x{30A0}-\x{30FF}]/u

    cond do
      Regex.match?(hiragana_range, query) -> :reading
      Regex.match?(katakana_range, query) -> :reading
      # If mostly ASCII letters, it's likely a meaning search
      String.match?(query, ~r/^[a-zA-Z\s'-]+$/) -> :meaning
      true -> :mixed
    end
  end
end
