defmodule MedoruWeb.Teacher.TestLive.Edit do
  @moduledoc """
  LiveView for editing a teacher test and managing its steps.

  Features:
  - View all test steps in order
  - Drag-drop reordering of steps
  - Add new steps (multichoice, fill, writing)
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
  def mount(%{"id" => id}, session, socket) do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user
    test = Tests.get_test!(id)

    # Verify ownership
    if not Tests.is_test_owner?(test, user.id) do
      {:ok,
       socket
       |> put_flash(:error, gettext("You can only edit your own tests."))
       |> push_navigate(to: ~p"/teacher/tests")}
    else
      # Only allow editing in_progress tests
      if test.setup_state != "in_progress" do
        {:ok,
         socket
         |> put_flash(:info, gettext("This test can no longer be edited."))
         |> push_navigate(to: ~p"/teacher/tests/#{test.id}")}
      else
        steps = Tests.list_test_steps(test.id)

        socket =
          socket
          |> assign(:locale, locale)
          |> assign(:page_title, gettext("Edit %{title}", title: test.title))
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
          |> assign(:option_word_ids, [])
          |> assign(:option_word_search_query, "")
          |> assign(:available_option_words, [])

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
    # Validate step type to prevent crashes
    type =
      case type_str do
        "multichoice" -> :multichoice
        "picture_multichoice" -> :picture_multichoice
        "fill" -> :fill
        "writing" -> :writing
        "match" -> :match
        "order" -> :order
        "reading_text" -> :reading_text
        _ -> :multichoice
      end

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
      |> assign(:use_default_meaning, true)
      |> assign(:custom_meaning, "")
      |> assign(:selected_word, nil)
      |> assign(:reading_answer, "")
      |> assign(:include_reading, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_step_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_step_form, false)
     |> assign(:step_changeset, nil)
     |> assign(:step_form, nil)
     |> assign(:new_option_text, "")
     |> assign(:option_word_ids, [])
     |> assign(:option_word_search_query, "")
     |> assign(:available_option_words, [])}
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
    step_type = socket.assigns.step_type

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

    # For fill type, add reading_answer and include_reading to question_data
    attrs =
      if step_type == :fill do
        reading_answer = socket.assigns.reading_answer
        include_reading = socket.assigns.include_reading
        points = if include_reading, do: 3, else: 2

        question_data = Map.get(attrs, "question_data", %{})
        question_data = Map.put(question_data, "include_reading", include_reading)

        question_data =
          if include_reading && reading_answer && reading_answer != "" do
            Map.put(question_data, "reading_answer", reading_answer)
          else
            question_data
          end

        attrs
        |> Map.put("question_data", question_data)
        |> Map.put("points", points)
      else
        attrs
      end

    # For picture_multichoice, validate all words have images
    attrs_result =
      if step_type == :picture_multichoice do
        validate_picture_multichoice_words(attrs, socket.assigns[:option_word_ids] || [])
      else
        {:ok, attrs}
      end

    case attrs_result do
      {:error, error_message} ->
        {:noreply,
         socket
         |> put_flash(:error, error_message)}

      {:ok, attrs} ->
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
             |> assign(:option_word_ids, [])
             |> assign(:option_word_search_query, "")
             |> assign(:available_option_words, [])
             |> put_flash(:info, gettext("Step added successfully."))}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:step_changeset, changeset)
             |> assign(:step_form, to_form(changeset, as: :step))
             |> put_flash(:error, gettext("Failed to save step. Please check the form."))}
        end
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
      {:noreply, put_flash(socket, :error, gettext("Step not found."))}
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
         |> put_flash(:info, gettext("Step updated successfully."))}

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
           |> put_flash(:info, gettext("Step deleted."))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to delete step."))}
      end
    else
      {:noreply, put_flash(socket, :error, gettext("Step not found."))}
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
     |> put_flash(:info, gettext("Steps reordered."))}
  end

  @impl true
  def handle_event("mark_ready", _params, socket) do
    test = socket.assigns.test

    if socket.assigns.step_count == 0 do
      {:noreply,
       put_flash(socket, :error, gettext("Add at least one step before marking ready."))}
    else
      case Tests.mark_test_ready(test) do
        {:ok, _updated_test} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Test marked as ready for publishing."))
           |> push_navigate(to: ~p"/teacher/tests/#{test.id}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to update test status."))}
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
      step_type = socket.assigns.step_type

      # Don't add if already exists (case-insensitive check)
      already_exists =
        Enum.any?(existing_options, fn opt ->
          String.downcase(String.trim(opt)) == String.downcase(trimmed)
        end)

      if already_exists do
        socket =
          socket
          |> assign(:new_option_text, "")
          |> put_flash(:error, gettext("This option already exists."))

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

        # For picture_multichoice, also track option_word_ids
        socket =
          if step_type == :picture_multichoice do
            # Initialize option_word_ids if not exists
            current_word_ids = socket.assigns[:option_word_ids] || %{}
            # We don't have a word_id here - just text was typed
            # This will be filled in when a word is selected from search
            assign(socket, :option_word_ids, current_word_ids)
          else
            socket
          end

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
    step_type = socket.assigns.step_type

    # Remove option at index
    new_options = List.delete_at(existing_options, index)

    # For picture_multichoice, also remove the corresponding word_id
    # Note: option_word_ids includes correct word at index 0, options don't
    # So we need to add 1 to the index to get the correct position in option_word_ids
    socket =
      if step_type == :picture_multichoice do
        option_word_ids = socket.assigns[:option_word_ids] || []
        # +1 because option_word_ids[0] is the correct answer
        new_word_ids = List.delete_at(option_word_ids, index + 1)
        assign(socket, :option_word_ids, new_word_ids)
      else
        socket
      end

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
  def handle_event("search_option_words", %{"value" => query}, socket) do
    # For picture_multichoice - search words with images only
    words =
      if String.length(query) >= 1 do
        Content.search_words(query, limit: 10)
        |> Enum.filter(&(&1.image_path && &1.image_path != ""))
      else
        []
      end

    {:noreply,
     socket
     |> assign(:option_word_search_query, query)
     |> assign(:available_option_words, words)}
  end

  @impl true
  def handle_event("select_option_word", %{"word-id" => word_id}, socket) do
    # For picture_multichoice - add a word as a wrong option
    word = Content.get_word!(word_id)
    current_form = socket.assigns.step_form
    existing_options = current_form[:options].value || []
    correct_answer = current_form[:correct_answer].value
    option_word_ids = socket.assigns[:option_word_ids] || []

    localized_meaning = Content.get_localized_meaning(word, socket.assigns.locale)
    trimmed_meaning = String.trim(localized_meaning)

    # Don't add if already exists
    already_exists =
      Enum.any?(existing_options, fn opt ->
        String.downcase(String.trim(opt)) == String.downcase(trimmed_meaning)
      end)

    if already_exists do
      socket =
        socket
        |> assign(:option_word_search_query, "")
        |> assign(:available_option_words, [])
        |> put_flash(:error, gettext("This option already exists."))

      Process.send_after(self(), :clear_flash, 5000)

      {:noreply, socket}
    else
      # Add the word's meaning as option and track its word_id
      new_options = existing_options ++ [trimmed_meaning]
      new_option_word_ids = option_word_ids ++ [word_id]

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

      {:noreply,
       socket
       |> assign(:step_changeset, changeset)
       |> assign(:step_form, to_form(changeset, as: :step))
       |> assign(:option_word_ids, new_option_word_ids)
       |> assign(:option_word_search_query, "")
       |> assign(:available_option_words, [])}
    end
  end

  @impl true
  def handle_event("select_word", %{"word-id" => word_id}, socket) do
    word = Content.get_word!(word_id)
    search_type = socket.assigns.search_type

    # Update the form with word info - merge with existing form data
    current_form = socket.assigns.step_form
    step_type = socket.assigns.step_type

    # Generate question based on search type and step type
    # Use localized meaning for the teacher's locale
    localized_meaning = Content.get_localized_meaning(word, socket.assigns.locale)

    {question, correct_answer} =
      case {step_type, search_type} do
        {:multichoice, :reading} ->
          # User searched by reading (hiragana/katakana)
          {gettext("How do you read '%{meaning}'?", meaning: localized_meaning), word.text}

        {:multichoice, _} ->
          # User searched by meaning (English) or other
          {gettext("What is the meaning of '%{word}'?", word: word.text), localized_meaning}

        {_, _} ->
          # Default for fill and other types
          {gettext("What is the meaning of '%{word}'?", word: word.text), localized_meaning}
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
      if step_type in [:multichoice, :picture_multichoice] do
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

    socket =
      socket
      |> assign(:step_changeset, changeset)
      |> assign(:step_form, to_form(changeset, as: :step))
      |> assign(:word_search_query, "")
      |> assign(:available_words, [])
      |> assign(:search_type, nil)

    # For picture_multichoice, store the correct word_id as first in option_word_ids
    socket =
      if step_type == :picture_multichoice do
        assign(socket, :option_word_ids, [word_id])
      else
        socket
      end

    # For fill type, also store selected word and reset custom meaning
    socket =
      if step_type == :fill do
        socket
        |> assign(:selected_word, word)
        |> assign(:custom_meaning, "")
        |> assign(:use_default_meaning, true)
        |> assign(:reading_answer, word.reading)
        |> assign(:include_reading, true)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_default_meaning", _params, socket) do
    current_value = socket.assigns.use_default_meaning
    new_value = not current_value

    # Update correct_answer based on toggle
    selected_word = socket.assigns.selected_word

    correct_answer =
      cond do
        new_value and selected_word ->
          # Switching to default - use localized word meaning
          Content.get_localized_meaning(selected_word, socket.assigns.locale)

        not new_value ->
          # Switching to custom - use custom meaning if set
          socket.assigns.custom_meaning

        true ->
          ""
      end

    # Update the changeset with new correct_answer
    current_form = socket.assigns.step_form

    updated_params = %{
      "question" => current_form[:question].value,
      "correct_answer" => correct_answer,
      "word_id" => current_form[:word_id].value,
      "hints" => current_form[:hints].value,
      "explanation" => current_form[:explanation].value
    }

    changeset =
      %TestStep{}
      |> TestStep.changeset(updated_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:use_default_meaning, new_value)
     |> assign(:step_changeset, changeset)
     |> assign(:step_form, to_form(changeset, as: :step))}
  end

  @impl true
  def handle_event("update_custom_meaning", %{"value" => value}, socket) do
    # Update custom meaning and correct_answer
    current_form = socket.assigns.step_form

    updated_params = %{
      "question" => current_form[:question].value,
      "correct_answer" => value,
      "word_id" => current_form[:word_id].value,
      "hints" => current_form[:hints].value,
      "explanation" => current_form[:explanation].value
    }

    changeset =
      %TestStep{}
      |> TestStep.changeset(updated_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:custom_meaning, value)
     |> assign(:step_changeset, changeset)
     |> assign(:step_form, to_form(changeset, as: :step))}
  end

  @impl true
  def handle_event("update_reading_answer", %{"value" => value}, socket) do
    {:noreply, assign(socket, :reading_answer, value)}
  end

  @impl true
  def handle_event("toggle_include_reading", _params, socket) do
    current_value = socket.assigns.include_reading
    new_value = not current_value

    # Update points based on include_reading
    # 3 points if reading is included, 2 points if only meaning
    new_points = if new_value, do: 3, else: 2

    # Update the changeset with new points
    current_form = socket.assigns.step_form

    updated_params = %{
      "question" => current_form[:question].value,
      "correct_answer" => current_form[:correct_answer].value,
      "word_id" => current_form[:word_id].value,
      "hints" => current_form[:hints].value,
      "explanation" => current_form[:explanation].value,
      "points" => new_points
    }

    changeset =
      %TestStep{}
      |> TestStep.changeset(updated_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:include_reading, new_value)
     |> assign(:step_changeset, changeset)
     |> assign(:step_form, to_form(changeset, as: :step))}
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
        {on, []} -> gettext("On: %{readings}", readings: Enum.join(on, ", "))
        {[], kun} -> gettext("Kun: %{readings}", readings: Enum.join(kun, ", "))
        {on, kun} ->
          gettext("On: %{on_readings}, Kun: %{kun_readings}",
            on_readings: Enum.join(on, ", "),
            kun_readings: Enum.join(kun, ", ")
          )
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
      "question" => gettext("Draw the kanji for '%{meaning}'", meaning: target_meaning),
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
            <h2 class="text-lg font-semibold text-base-content">{gettext("Test Steps")}</h2>
            <%= if @step_count > 0 do %>
              <button
                type="button"
                phx-click="open_step_selector"
                class="btn btn-primary btn-sm gap-2"
              >
                <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Add Step")}
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
                <h3 class="text-xl font-bold text-base-content">{gettext("Add Step")}</h3>
                <button
                  type="button"
                  phx-click="close_step_selector"
                  class="p-2 text-secondary hover:text-base-content hover:bg-base-200 rounded-lg transition-colors"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>
              <p class="text-secondary mt-1">
                {gettext("Choose the type of question you want to add.")}
              </p>
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
                    {gettext("Edit Step")}
                  <% else %>
                    {gettext("New %{type} Step", type: format_question_type(@step_type))}
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
                    {gettext("Question")}
                  </label>
                  <.input
                    field={@step_form[:question]}
                    type="textarea"
                    rows="3"
                    placeholder={gettext("Enter your question...")}
                  />
                </div>

                <%!-- Kanji Search (for writing type) --%>
                <%= if @step_type == :writing do %>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-2">
                      {gettext("Select Kanji")}
                    </label>
                    <input
                      type="text"
                      phx-keyup="search_kanji"
                      phx-debounce="300"
                      class="input input-bordered w-full"
                      placeholder={gettext("Type kanji character, meaning, or reading...")}
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
                                    gettext("%{count} strokes", count: length(s))

                                  _ ->
                                    gettext("No stroke data")
                                end} • N{@selected_kanji.jlpt_level}
                              </p>
                            </div>
                          </div>
                          <%= if @show_kanji_preview do %>
                            <span class="badge badge-success badge-sm">
                              {gettext("Ready for writing")}
                            </span>
                          <% else %>
                            <span class="badge badge-error badge-sm">
                              {gettext("No stroke data")}
                            </span>
                          <% end %>
                        </div>

                        <%!-- Stroke Animation Preview --%>
                        <%= if @show_kanji_preview do %>
                          <div class="border-t border-base-300 pt-4">
                            <p class="text-sm font-medium text-base-content mb-3">
                              {gettext("Stroke Order Preview")}
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
                              {gettext("This kanji doesn't have stroke data. Writing validation will not work for this step.")}
                            </p>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%= if @step_type in [:multichoice, :picture_multichoice, :fill] do %>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-2">
                      <%= if @step_type == :picture_multichoice do %>
                        {gettext("Link to Word (required for picture questions)")}
                      <% else %>
                        {gettext("Link to Word (optional)")}
                      <% end %>
                      <%= case @search_type do %>
                        <% :reading -> %>
                          <span class="text-xs text-info ml-2">
                            {gettext("Reading search detected")}
                          </span>
                        <% :meaning -> %>
                          <span class="text-xs text-success ml-2">
                            {gettext("Meaning search detected")}
                          </span>
                        <% _ -> %>
                      <% end %>
                    </label>
                    <input
                      type="text"
                      phx-keyup="search_words"
                      phx-debounce="300"
                      class="input input-bordered w-full"
                      placeholder={gettext("Type to search words...")}
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
                              <span class="text-sm text-secondary">
                                {Content.get_localized_meaning(word, @locale)}
                              </span>
                            </div>
                          </button>
                        <% end %>
                      </div>
                    <% end %>

                    <%!-- Selected Word Info for Fill Type --%>
                    <%= if @step_type == :fill and @selected_word do %>
                      <div class="mt-4 bg-base-200 rounded-lg p-4">
                        <div class="flex items-center gap-4 mb-4">
                          <span class="text-2xl font-bold">{@selected_word.text}</span>
                          <div>
                            <p class="text-sm text-secondary">{@selected_word.reading}</p>
                            <p class="text-sm font-medium">
                              {Content.get_localized_meaning(@selected_word, @locale)}
                            </p>
                          </div>
                        </div>

                        <%!-- Include Reading Checkbox --%>
                        <div class="flex items-center gap-3 mb-4 p-3 bg-base-100 rounded-lg">
                          <label class="flex items-center gap-2 cursor-pointer">
                            <input
                              type="checkbox"
                              name="step[include_reading]"
                              phx-click="toggle_include_reading"
                              checked={@include_reading}
                              class="checkbox checkbox-sm checkbox-primary"
                            />
                            <span class="text-sm font-medium">
                              {gettext("Also require reading in hiragana")}
                            </span>
                          </label>
                          <span class="text-xs text-secondary">
                            <%= if @include_reading do %>
                              ({gettext("3 points total: 2 for meaning + 1 for reading")})
                            <% else %>
                              ({gettext("2 points for meaning only")})
                            <% end %>
                          </span>
                        </div>

                        <%!-- Default vs Custom Meaning Toggle --%>
                        <div class="flex items-center gap-3 mb-4">
                          <label class="flex items-center gap-2 cursor-pointer">
                            <input
                              type="checkbox"
                              phx-click="toggle_default_meaning"
                              checked={@use_default_meaning}
                              class="checkbox checkbox-sm checkbox-primary"
                            />
                            <span class="text-sm">{gettext("Use default meaning as answer")}</span>
                          </label>
                        </div>

                        <%!-- Custom Meaning Input --%>
                        <%= if not @use_default_meaning do %>
                          <div class="mb-4">
                            <label class="block text-sm font-medium text-base-content mb-2">
                              {gettext("Custom Meaning Answer")}
                            </label>
                            <input
                              type="text"
                              name="step[custom_meaning]"
                              value={@custom_meaning}
                              phx-keyup="update_custom_meaning"
                              class="input input-bordered w-full"
                              placeholder={gettext("Enter custom meaning...")}
                            />
                            <p class="text-xs text-secondary mt-1">
                              {gettext("Students must match this exactly (case-insensitive)")}
                            </p>
                          </div>
                        <% end %>

                        <%!-- Reading Answer (Hiragana) - Only show if include_reading is checked --%>
                        <%= if @include_reading do %>
                          <div>
                            <label class="block text-sm font-medium text-base-content mb-2">
                              {gettext("Reading Answer (Hiragana)")}
                              <span class="text-xs text-secondary ml-1">
                                - {gettext("students must also enter this")}
                              </span>
                            </label>
                            <input
                              type="text"
                              name="step[reading_answer]"
                              value={@reading_answer || @selected_word.reading}
                              phx-keyup="update_reading_answer"
                              class="input input-bordered w-full"
                              placeholder={gettext("Enter hiragana reading (e.g., あおい)...")}
                            />
                            <p class="text-xs text-secondary mt-1">
                              {gettext("Default from word database. Edit if you want a different reading accepted.")}
                            </p>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%!-- Correct Answer --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Correct Answer")}
                  </label>
                  <.input
                    field={@step_form[:correct_answer]}
                    type="text"
                    placeholder={gettext("Enter the correct answer...")}
                    phx-keyup="update_correct_answer"
                    phx-debounce="3000"
                  />
                  <p class="text-xs text-secondary mt-1">
                    {gettext("Changes will update the correct option after 3 seconds of inactivity.")}
                  </p>
                </div>

                <%!-- Options for multichoice and picture_multichoice --%>
                <%= if @step_type in [:multichoice, :picture_multichoice] do %>
                  <div>
                    <label class="block text-sm font-medium text-base-content mb-2">
                      <%= if @step_type == :picture_multichoice do %>
                        {gettext("Answer Options (must be words with images)")}
                      <% else %>
                        {gettext("Answer Options")}
                      <% end %>
                      <span class="text-xs text-secondary ml-2">
                        ({gettext("4-8 options required")})
                      </span>
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
                          <span class="text-xs opacity-70">({gettext("correct")})</span>
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
                              title={gettext("Remove option")}
                            >
                              <.icon name="hero-x-mark" class="w-4 h-4" />
                            </button>
                          </div>
                        <% end %>
                      <% end %>

                      <%!-- Empty state --%>
                      <%= if length(options) < 4 do %>
                        <span class="text-sm text-secondary italic">
                          {gettext("Add %{count} more option(s)", count: 4 - length(options))}
                        </span>
                      <% end %>
                    </div>

                    <%!-- Add new option input --%>
                    <%= if @step_type == :picture_multichoice do %>
                      <%!-- For picture_multichoice: search and select words with images --%>
                      <div>
                        <label class="block text-xs font-medium text-secondary mb-1">
                          {gettext("Search for a word with image to add as option")}
                        </label>
                        <input
                          type="text"
                          phx-keyup="search_option_words"
                          phx-debounce="300"
                          class="input input-bordered w-full"
                          placeholder={gettext("Type to search words with images...")}
                          value={@option_word_search_query}
                        />
                        <%= if length(@available_option_words) > 0 do %>
                          <div class="mt-2 bg-base-200 rounded-lg p-2 max-h-40 overflow-y-auto">
                            <%= for word <- @available_option_words do %>
                              <button
                                type="button"
                                phx-click="select_option_word"
                                phx-value-word-id={word.id}
                                class="w-full text-left p-2 hover:bg-base-300 rounded-lg transition-colors flex items-center gap-3"
                              >
                                <%= if word.image_path do %>
                                  <img src={word.image_path} alt={word.text} class="w-10 h-10 object-cover rounded" />
                                <% end %>
                                <div>
                                  <span class="font-medium">{word.text}</span>
                                  <span class="text-sm text-secondary ml-2">
                                    {Content.get_localized_meaning(word, @locale)}
                                  </span>
                                </div>
                              </button>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    <% else %>
                      <%!-- For regular multichoice: type text --%>
                      <div class="flex gap-2">
                        <input
                          type="text"
                          id="new-option-input"
                          value={@new_option_text}
                          phx-keyup="update_new_option"
                          phx-hook="OptionInput"
                          class="input input-bordered flex-1"
                          placeholder={gettext("Type a wrong answer and press Enter...")}
                        />
                        <button
                          type="button"
                          phx-click="add_option"
                          disabled={String.trim(@new_option_text) == ""}
                          class="btn btn-outline btn-sm"
                        >
                          <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Add")}
                        </button>
                      </div>
                    <% end %>

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
                    {gettext("Hint (optional)")}
                  </label>
                  <.input
                    field={@step_form[:hints]}
                    type="text"
                    placeholder={gettext("Give students a hint...")}
                  />
                </div>

                <%!-- Explanation --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Explanation (shown after answering)")}
                  </label>
                  <.input
                    field={@step_form[:explanation]}
                    type="textarea"
                    rows="2"
                    placeholder={gettext("Explain the correct answer...")}
                  />
                </div>

                <%!-- Form Actions --%>
                <div class="flex items-center justify-end gap-3 pt-4 border-t border-base-200">
                  <button
                    type="button"
                    phx-click="close_step_form"
                    class="btn btn-ghost"
                  >
                    {gettext("Cancel")}
                  </button>
                  <button type="submit" class="btn btn-primary">
                    <%= if @editing_step do %>
                      {gettext("Update Step")}
                    <% else %>
                      {gettext("Add Step")}
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

  defp format_question_type(:multichoice), do: gettext("Multiple Choice")
  defp format_question_type(:picture_multichoice), do: gettext("Picture Multiple Choice")
  defp format_question_type(:reading_text), do: gettext("Reading")
  defp format_question_type(:fill), do: gettext("Fill in Blank")
  defp format_question_type(:writing), do: gettext("Writing")
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

  defp parse_options_from_params(%{"question_data" => question_data} = params)
       when is_map(question_data) do
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

  # Validates that all words in a picture_multichoice step have images
  # option_word_ids is a list where:
  #   - index 0 is the correct answer word_id
  #   - index 1+ are the wrong option word_ids
  # Returns {:ok, attrs_with_question_data} or {:error, error_message}
  defp validate_picture_multichoice_words(attrs, option_word_ids) do
    _correct_answer = attrs["correct_answer"] || ""
    options = attrs["options"] || []

    # Validate we have word_ids for all options
    # options includes correct answer + wrong options
    # option_word_ids should match the count of options
    expected_count = length(options)

    if length(option_word_ids) < expected_count do
      missing_count = expected_count - length(option_word_ids)

      error =
        gettext(
          "Missing word links for %{count} option(s). Please search and select words for all options.",
          count: missing_count
        )

      {:error, error}
    else
      # Fetch all words and check for images
      words =
        option_word_ids
        |> Enum.map(&Content.get_word/1)
        |> Enum.reject(&is_nil/1)

      words_missing_images =
        words
        |> Enum.filter(fn word ->
          is_nil(word.image_path) or word.image_path == ""
        end)

      case words_missing_images do
        [] ->
          # All words have images - build question_data
          # Get word details for display
          correct_word = List.first(words)

          image_options =
            words
            |> Enum.map(fn word ->
              %{
                "word_id" => word.id,
                "word_text" => word.text,
                "image_path" => word.image_path
              }
            end)

          # Build question_data for image_to_meaning
          question_data = %{
            "type" => "image_to_meaning",
            "word_text" => correct_word.text,
            "word_reading" => correct_word.reading,
            "option_word_ids" => option_word_ids,
            "image_options" => image_options
          }

          # Update attrs with question_data and word_id
          attrs =
            attrs
            |> Map.put("question_data", question_data)
            |> Map.put("word_id", correct_word.id)
            |> Map.put("question_type", "multichoice")

          {:ok, attrs}

        missing_words ->
          # Some words don't have images
          word_texts = Enum.map(missing_words, & &1.text)

          error =
            gettext(
              "The following words don't have images: %{words}. Please select words with images.",
              words: Enum.join(word_texts, ", ")
            )

          {:error, error}
      end
    end
  end
end
