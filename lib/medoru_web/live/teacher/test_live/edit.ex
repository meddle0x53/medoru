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
  alias Ecto.Changeset

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
          |> assign(:selected_kanji, nil)
          |> assign(:show_kanji_preview, false)
          |> assign(:search_type, nil)
          |> assign(:new_option_text, "")

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

    # Create changeset WITHOUT running validations for initial form display
    changeset =
      %TestStep{}
      |> Changeset.cast(attrs, [
        :order_index,
        :step_type,
        :question_type,
        :points
      ])

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
      |> assign(:selected_kanji, nil)
      |> assign(:show_kanji_preview, false)
      |> assign(:search_type, nil)
      |> assign(:new_option_text, "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_step_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_step_form, false)
     |> assign(:step_changeset, nil)
     |> assign(:step_form, nil)
     |> assign(:new_option_text, "")}
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

    # Include question_data from the current changeset if it exists
    attrs =
      case socket.assigns.step_changeset do
        %{changes: %{question_data: data}} when is_map(data) and map_size(data) > 0 ->
          Map.put(attrs, "question_data", data)
        _ ->
          attrs
      end

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
         |> assign(:new_option_text, "")
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
       |> assign(:step_type, step.question_type)
       |> assign(:new_option_text, "")}
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
  def handle_event("add_option", _params, socket) do
    value = socket.assigns.new_option_text
    trimmed = String.trim(value)

    if trimmed == "" do
      {:noreply, socket}
    else
      current_form = socket.assigns.step_form
      existing_options = current_form[:options].value || []
      correct_answer = current_form[:correct_answer].value

      # Don't add if already exists (case-insensitive check)
      already_exists =
        Enum.any?(existing_options, fn opt ->
          String.downcase(String.trim(opt)) == String.downcase(trimmed)
        end)

      if already_exists do
        socket =
          socket
          |> assign(:new_option_text, "")
          |> put_flash(:error, "This option already exists.")

        # Schedule flash clear after 5 seconds
        Process.send_after(self(), :clear_flash, 5000)

        {:noreply, push_event(socket, "clear_option_input", %{})}
      else
        # Add new option (wrong answer)
        new_options = existing_options ++ [trimmed]

        updated_params = %{
          "question" => current_form[:question].value,
          "correct_answer" => correct_answer,
          "word_id" => current_form[:word_id].value,
          "options" => new_options,
          "hints" => current_form[:hints].value,
          "explanation" => current_form[:explanation].value,
          "kanji_id" => current_form[:kanji_id].value
        }

        changeset =
          %TestStep{}
          |> TestStep.changeset(updated_params)
          |> Map.put(:action, :validate)

        socket =
          socket
          |> assign(:step_changeset, changeset)
          |> assign(:step_form, to_form(changeset, as: :step))
          |> assign(:new_option_text, "")

        {:noreply, push_event(socket, "clear_option_input", %{})}
      end
    end
  end

  @impl true
  def handle_event("remove_option", %{"index" => index}, socket) do
    index = String.to_integer(index)
    current_form = socket.assigns.step_form
    existing_options = current_form[:options].value || []

    # Remove option at index
    new_options = List.delete_at(existing_options, index)

    updated_params = %{
      "question" => current_form[:question].value,
      "correct_answer" => current_form[:correct_answer].value,
      "word_id" => current_form[:word_id].value,
      "options" => new_options,
      "hints" => current_form[:hints].value,
      "explanation" => current_form[:explanation].value,
      "kanji_id" => current_form[:kanji_id].value
    }

    changeset =
      %TestStep{}
      |> TestStep.changeset(updated_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:step_changeset, changeset)
     |> assign(:step_form, to_form(changeset, as: :step))}
  end

  @impl true
  def handle_event("update_new_option", %{"value" => value}, socket) do
    {:noreply, assign(socket, :new_option_text, value)}
  end

  @impl true
  def handle_event("update_correct_answer", %{"value" => new_answer}, socket) do
    current_form = socket.assigns.step_form
    existing_options = current_form[:options].value || []
    old_answer = current_form[:correct_answer].value

    new_answer_trimmed = String.trim(new_answer)
    old_answer_trimmed = if old_answer, do: String.trim(old_answer), else: ""

    # Only update if the answer has actually changed
    if new_answer_trimmed == "" or new_answer_trimmed == old_answer_trimmed do
      {:noreply, socket}
    else
      # Replace old correct answer with new one in the options list
      updated_options =
        existing_options
        |> Enum.map(fn opt ->
          if String.trim(opt) == old_answer_trimmed do
            new_answer_trimmed
          else
            opt
          end
        end)
        |> Enum.reject(&(&1 == ""))
        |> Enum.uniq_by(&String.downcase(String.trim(&1)))

      # Ensure new answer is in options if it wasn't there
      updated_options =
        if Enum.any?(updated_options, fn opt ->
             String.downcase(String.trim(opt)) == String.downcase(new_answer_trimmed)
           end) do
          updated_options
        else
          [new_answer_trimmed | updated_options]
        end

      updated_params = %{
        "question" => current_form[:question].value,
        "correct_answer" => new_answer_trimmed,
        "word_id" => current_form[:word_id].value,
        "options" => updated_options,
        "hints" => current_form[:hints].value,
        "explanation" => current_form[:explanation].value,
        "kanji_id" => current_form[:kanji_id].value
      }

      changeset =
        %TestStep{}
        |> TestStep.changeset(updated_params)
        |> Map.put(:action, :validate)

      {:noreply,
       socket
       |> assign(:step_changeset, changeset)
       |> assign(:step_form, to_form(changeset, as: :step))}
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

    # For multichoice, ensure correct_answer is in options and trimmed
    trimmed_answer = String.trim(correct_answer)
    existing_options = current_form[:options].value || []

    # Clean up existing options - remove empty strings and the old correct answer if any
    cleaned_options =
      existing_options
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    options =
      if step_type == :multichoice do
        # Don't duplicate if already exists
        if trimmed_answer in cleaned_options do
          cleaned_options
        else
          [trimmed_answer | cleaned_options]
        end
      else
        cleaned_options
      end

    updated_params = %{
      "question" => question,
      "correct_answer" => trimmed_answer,
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

    # Extract stroke data for validation
    strokes =
      case kanji.stroke_data do
        %{"strokes" => s} when is_list(s) -> s
        _ -> []
      end

    updated_params = %{
      "question" => "Draw the kanji for \"#{target_meaning}\"",
      "correct_answer" => String.trim(kanji.character),
      "kanji_id" => kanji_id,
      "hints" => [],
      "explanation" => readings_text,
      "question_data" => %{
        "type" => "kanji_writing",
        "kanji" => kanji.character,
        "meanings" => kanji.meanings,
        "stroke_count" => kanji.stroke_count,
        "strokes" => strokes
      }
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
  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
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

                    <%!-- Selected Kanji Info & Preview --%>
                    <%= if @selected_kanji do %>
                      <div class="mt-4 bg-base-200 rounded-xl p-4">
                        <%!-- Kanji Info Header --%>
                        <div class="flex items-center justify-between mb-4">
                          <div class="flex items-center gap-4">
                            <span class="text-4xl font-bold text-base-content">
                              {@selected_kanji.character}
                            </span>
                            <div>
                              <p class="text-sm text-secondary">
                                {Enum.join(@selected_kanji.meanings, ", ")}
                              </p>
                              <p class="text-xs text-secondary mt-1">
                                {case @selected_kanji.stroke_data do
                                  %{"strokes" => s} when is_list(s) ->
                                    "#{length(s)} strokes"

                                  _ ->
                                    "No stroke data"
                                end} • N{@selected_kanji.jlpt_level}
                              </p>
                            </div>
                          </div>
                          <%= if @show_kanji_preview do %>
                            <span class="badge badge-success badge-sm">Ready for writing</span>
                          <% else %>
                            <span class="badge badge-error badge-sm">No stroke data</span>
                          <% end %>
                        </div>

                        <%!-- Stroke Animation Preview --%>
                        <%= if @show_kanji_preview do %>
                          <div class="border-t border-base-300 pt-4">
                            <p class="text-sm font-medium text-base-content mb-3">
                              Stroke Order Preview
                            </p>
                            <.live_component
                              module={MedoruWeb.StrokeAnimator}
                              id="kanji-writing-preview"
                              stroke_data={@selected_kanji.stroke_data}
                            />
                          </div>
                        <% else %>
                          <div class="bg-error/10 border border-error/30 rounded-lg p-4 text-center">
                            <.icon name="hero-exclamation-triangle" class="w-6 h-6 text-error mb-2" />
                            <p class="text-sm text-error">
                              This kanji doesn't have stroke data. Writing validation will not work for this step.
                            </p>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%= if @step_type == :multichoice or @step_type == :reading_text do %>
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
                    phx-keyup="update_correct_answer"
                    phx-debounce="3000"
                  />
                  <p class="text-xs text-secondary mt-1">
                    Changes will update the correct option after 3 seconds of inactivity.
                  </p>
                </div>

                <%!-- Options for multichoice --%>
                <%= if @step_type == :multichoice do %>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-2">
                      Answer Options
                      <span class="text-xs text-secondary ml-2">(4-8 options required)</span>
                    </label>

                    <% options = @step_form[:options].value || [] %>
                    <% correct = @step_form[:correct_answer].value %>
                    <% correct_trimmed = if correct, do: String.trim(correct), else: "" %>

                    <%!-- Options as tags --%>
                    <div class="flex flex-wrap gap-2 mb-3 min-h-[40px] p-3 bg-base-200 rounded-lg">
                      <%!-- Correct answer tag (not removable) --%>
                      <%= if correct_trimmed != "" do %>
                        <div class="inline-flex items-center gap-2 px-3 py-1.5 bg-success/20 text-success border border-success/30 rounded-lg">
                          <.icon name="hero-check-circle" class="w-4 h-4" />
                          <span class="font-medium">{correct_trimmed}</span>
                          <span class="text-xs opacity-70">(correct)</span>
                        </div>
                      <% end %>

                      <%!-- Wrong answer tags (removable) --%>
                      <%= for {option, index} <- Enum.with_index(options) do %>
                        <% trimmed = if is_binary(option), do: String.trim(option), else: "" %>
                        <% is_correct = correct_trimmed == trimmed %>
                        <%= if not is_correct and trimmed != "" do %>
                          <div class="inline-flex items-center gap-2 px-3 py-1.5 bg-base-100 border border-base-300 rounded-lg group">
                            <span>{trimmed}</span>
                            <button
                              type="button"
                              phx-click="remove_option"
                              phx-value-index={index}
                              class="text-secondary hover:text-error transition-colors"
                              title="Remove option"
                            >
                              <.icon name="hero-x-mark" class="w-4 h-4" />
                            </button>
                          </div>
                        <% end %>
                      <% end %>

                      <%!-- Empty state --%>
                      <%= if length(options) < 4 do %>
                        <span class="text-sm text-secondary italic">
                          Add {4 - length(options)} more option(s)
                        </span>
                      <% end %>
                    </div>

                    <%!-- Add new option input --%>
                    <div class="flex gap-2">
                      <input
                        type="text"
                        id="new-option-input"
                        value={@new_option_text}
                        phx-keyup="update_new_option"
                        phx-hook="OptionInput"
                        class="input input-bordered flex-1"
                        placeholder="Type a wrong answer and press Enter..."
                      />
                      <button
                        type="button"
                        phx-click="add_option"
                        disabled={String.trim(@new_option_text) == ""}
                        class="btn btn-outline btn-sm"
                      >
                        <.icon name="hero-plus" class="w-4 h-4" /> Add
                      </button>
                    </div>

                    <%!-- Validation messages --%>
                    <%= if @step_changeset && @step_changeset.errors[:options] do %>
                      <p class="text-error text-sm mt-2">
                        {elem(@step_changeset.errors[:options], 0)}
                      </p>
                    <% end %>
                    <%= if @step_changeset && @step_changeset.errors[:correct_answer] do %>
                      <p class="text-error text-sm mt-2">
                        {elem(@step_changeset.errors[:correct_answer], 0)}
                      </p>
                    <% end %>

                    <%!-- Textarea for form submission ( visually hidden but functionally present) --%>
                    <% all_options =
                      if correct_trimmed != "",
                        do: [
                          correct_trimmed
                          | Enum.reject(options, &(String.trim(&1) == correct_trimmed))
                        ],
                        else: options %>
                    <textarea
                      name="step[options]"
                      class="sr-only"
                      aria-hidden="true"
                      readonly
                    >{format_options_for_submission(all_options)}</textarea>
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

  defp format_options_for_submission(options) when is_list(options) do
    options
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp format_options_for_submission(_), do: ""

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

  defp parse_options_from_params(%{"question_data" => question_data} = params) when is_map(question_data) do
    # Already a map, just continue processing other fields
    parse_options_from_params(Map.delete(params, "question_data"))
  end

  defp parse_options_from_params(%{"question_data" => question_data_json} = params)
       when is_binary(question_data_json) do
    # Parse JSON question_data from hidden field
    decoded =
      case Jason.decode(question_data_json) do
        {:ok, data} when is_map(data) -> data
        _ -> %{}
      end

    # Replace with decoded map
    params
    |> Map.put("question_data", decoded)
    |> Map.delete("question_data_json")
    |> parse_options_from_params()
  end

  defp parse_options_from_params(params) do
    # Ensure correct_answer is always trimmed
    params =
      case Map.get(params, "correct_answer") do
        nil -> params
        answer -> Map.put(params, "correct_answer", String.trim(answer))
      end

    params
  end

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
