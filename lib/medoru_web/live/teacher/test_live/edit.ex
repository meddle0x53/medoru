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
    changeset =
      %TestStep{}
      |> TestStep.changeset(step_params)
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
      if String.length(query) >= 2 do
        Content.search_words(query, limit: 10)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:word_search_query, query)
     |> assign(:available_words, words)}
  end

  @impl true
  def handle_event("select_word", %{"word-id" => word_id}, socket) do
    word = Content.get_word!(word_id)

    # Update the form with word info - merge with existing form data
    current_form = socket.assigns.step_form

    updated_params = %{
      "question" => "What is the meaning of \"#{word.text}\"?",
      "correct_answer" => word.meaning,
      "word_id" => word_id,
      "options" => current_form[:options].value,
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
     |> assign(:available_words, [])}
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

                <%!-- Word Search (for linking to vocabulary) --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    Link to Word (optional)
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

    Map.put(params, "options", options)
  end

  defp parse_options_from_params(params), do: params
end
