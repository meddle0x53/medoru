defmodule MedoruWeb.Teacher.GrammarLessonLive.Form do
  @moduledoc """
  Teacher form for creating and editing grammar lessons.

  Pattern elements:
  - word_slot: word_type + form (colored bubbles)
  - word_class: reference to word class (light purple bubble)
  - literal: fixed text (white bubble)
  """
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Grammar.Validator

  embed_templates "form/*"

  @word_types [
    {"Verb", "verb"},
    {"Adjective", "adjective"},
    {"Noun", "noun"},
    {"Particle", "particle"},
    {"Expression", "expression"}
  ]

  # Common Japanese particles for selection
  @particles [
    {"は (wa - topic)", "は"},
    {"が (ga - subject)", "が"},
    {"を (wo - object)", "を"},
    {"に (ni - to/at)", "に"},
    {"で (de - at/by)", "で"},
    {"へ (e - to)", "へ"},
    {"と (to - with/and)", "と"},
    {"から (kara - from)", "から"},
    {"まで (made - until)", "まで"},
    {"より (yori - than)", "より"},
    {"も (mo - also)", "も"},
    {"や (ya - and)", "や"},
    {"の (no - possessive)", "の"},
    {"か (ka - question)", "か"},
    {"ね (ne - right?)", "ね"},
    {"よ (yo - you know)", "よ"},
    {"わ (wa - emotion)", "わ"},
    {"ぞ (zo - emphasis)", "ぞ"},
    {"ぜ (ze - emphasis)", "ぜ"},
    {"な (na - prohibition)", "な"},
    {"さ (sa - casual)", "さ"},
    {"っけ (kke - I wonder)", "っけ"},
    {"もの (mono - because)", "もの"},
    {"くらい (kurai - about)", "くらい"},
    {"ぐらい (gurai - about)", "ぐらい"},
    {"だけ (dake - only)", "だけ"},
    {"しか (shika - only)", "しか"},
    {"など (nado - etc.)", "など"}
  ]

  # Colors for word type bubbles (Tailwind classes)
  @word_type_colors %{
    "verb" => "bg-emerald-500 text-white",
    "noun" => "bg-blue-500 text-white",
    "adjective" => "bg-rose-500 text-white",
    "expression" => "bg-amber-400 text-amber-950",
    "particle" => "bg-orange-500 text-white"
  }

  @impl true
  def render(assigns) do
    ~H"""
    {form_template(assigns)}
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    if user.type not in ["teacher", "admin"] do
      {:ok,
       socket
       |> put_flash(:error, gettext("Only teachers can access this page."))
       |> push_navigate(to: ~p"/classrooms")}
    else
      # Load grammar forms and word classes for pattern builder
      grammar_forms = Content.list_grammar_forms()
      word_classes = Content.list_word_classes()

      {:ok,
       socket
       |> assign(:grammar_forms, grammar_forms)
       |> assign(:word_classes, word_classes)
       |> assign(:word_types, @word_types)
       |> assign(:word_type_colors, @word_type_colors)
       |> assign(:particles, @particles)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    user = socket.assigns.current_scope.current_user

    case socket.assigns.live_action do
      :new ->
        changeset =
          Content.change_custom_lesson(%Content.CustomLesson{}, %{
            "lesson_subtype" => "grammar"
          })

        {:noreply,
         socket
         |> assign(:page_title, gettext("New Grammar Lesson"))
         |> assign(:lesson, nil)
         |> assign(:changeset, changeset)
         |> assign(:steps, [])
         |> assign(:current_step_index, nil)
         |> assign(:current_step, nil)}

      :edit ->
        lesson = Content.get_custom_lesson!(params["id"])

        if lesson.creator_id != user.id do
          {:noreply,
           socket
           |> put_flash(:error, gettext("You can only edit your own lessons."))
           |> push_navigate(to: ~p"/teacher/grammar-lessons")}
        else
          steps = Content.list_grammar_lesson_steps(lesson.id)
          changeset = Content.change_custom_lesson(lesson)

          {:noreply,
           socket
           |> assign(:page_title, gettext("Edit Grammar Lesson"))
           |> assign(:lesson, lesson)
           |> assign(:changeset, changeset)
           |> assign(:steps, steps)
           |> assign(:current_step_index, nil)
           |> assign(:current_step, nil)}
        end
    end
  end

  @impl true
  def handle_event("validate_lesson", %{"custom_lesson" => lesson_params}, socket) do
    base_lesson =
      case socket.assigns.live_action do
        :edit -> socket.assigns.lesson
        :new -> %Content.CustomLesson{}
      end

    changeset =
      base_lesson
      |> Content.change_custom_lesson(Map.put(lesson_params, "lesson_subtype", "grammar"))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save_lesson", %{"custom_lesson" => lesson_params}, socket) do
    user = socket.assigns.current_scope.current_user
    lesson_params = Map.put(lesson_params, "creator_id", user.id)
    lesson_params = Map.put(lesson_params, "lesson_subtype", "grammar")

    case socket.assigns.live_action do
      :new ->
        case Content.create_custom_lesson(lesson_params) do
          {:ok, lesson} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Grammar lesson created. Now add steps!"))
             |> push_navigate(to: ~p"/teacher/grammar-lessons/#{lesson.id}/edit")}

          {:error, changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end

      :edit ->
        lesson = socket.assigns.lesson

        case Content.update_custom_lesson(lesson, lesson_params) do
          {:ok, lesson} ->
            {:noreply,
             socket
             |> assign(:lesson, lesson)
             |> put_flash(:info, gettext("Lesson updated successfully."))}

          {:error, changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end
    end
  end

  @impl true
  def handle_event("add_step", _params, socket) do
    lesson = socket.assigns.lesson

    if is_nil(lesson) do
      {:noreply, put_flash(socket, :error, gettext("Save the lesson first before adding steps."))}
    else
      new_step = %{
        id: Ecto.UUID.generate(),
        position: length(socket.assigns.steps),
        title: "",
        explanation: "",
        pattern_elements: [],
        examples: [],
        difficulty: 1
      }

      {:noreply,
       socket
       |> assign(:current_step_index, :new)
       |> assign(:current_step, new_step)}
    end
  end

  @impl true
  def handle_event("edit_step", %{"index" => index}, socket) do
    steps = socket.assigns.steps
    step = Enum.at(steps, String.to_integer(index))

    {:noreply,
     socket
     |> assign(:current_step_index, String.to_integer(index))
     |> assign(:current_step, step)}
  end

  @impl true
  def handle_event("delete_step", %{"id" => id}, socket) do
    step = Content.get_grammar_lesson_step!(id)

    case Content.delete_grammar_lesson_step(step) do
      {:ok, _} ->
        lesson = socket.assigns.lesson
        steps = Content.list_grammar_lesson_steps(lesson.id)

        {:noreply,
         socket
         |> assign(:steps, steps)
         |> assign(:current_step_index, nil)
         |> assign(:current_step, nil)
         |> put_flash(:info, gettext("Step deleted."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete step."))}
    end
  end

  @impl true
  def handle_event("cancel_step", _params, socket) do
    {:noreply,
     socket
     |> assign(:current_step_index, nil)
     |> assign(:current_step, nil)}
  end

  @impl true
  def handle_event("update_step_field", params, socket) do
    # Form sends params with field name as key
    field = params["field"] || "title"
    value = params[field] || ""

    step = socket.assigns.current_step
    step = Map.put(step, String.to_atom(field), value)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event(
        "update_step_explanation",
        %{"step" => %{"explanation" => explanation}},
        socket
      ) do
    step = socket.assigns.current_step
    step = Map.put(step, :explanation, explanation)

    {:noreply, assign(socket, :current_step, step)}
  end

  # Handle blur event which sends value directly
  @impl true
  def handle_event(
        "update_step_explanation",
        %{"value" => explanation},
        socket
      ) do
    step = socket.assigns.current_step
    step = Map.put(step, :explanation, explanation)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("add_pattern_element", %{"type" => type}, socket) do
    step = socket.assigns.current_step
    element = create_pattern_element(type)
    pattern_elements = step.pattern_elements ++ [element]
    step = Map.put(step, :pattern_elements, pattern_elements)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("update_element_word_type", %{"index" => index, "value" => value}, socket) do
    index = String.to_integer(index)
    step = socket.assigns.current_step
    elements = step.pattern_elements
    element = Enum.at(elements, index)

    # Update word_type and reset form
    element =
      element
      |> Map.put("word_type", value)
      |> Map.put("form", nil)

    elements = List.replace_at(elements, index, element)
    step = Map.put(step, :pattern_elements, elements)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("update_element_form", %{"index" => index, "value" => value}, socket) do
    index = String.to_integer(index)
    step = socket.assigns.current_step
    elements = step.pattern_elements
    element = Enum.at(elements, index)

    element = Map.put(element, "form", value)
    elements = List.replace_at(elements, index, element)
    step = Map.put(step, :pattern_elements, elements)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("update_element_word_class", %{"index" => index, "value" => value}, socket) do
    index = String.to_integer(index)
    step = socket.assigns.current_step
    elements = step.pattern_elements
    element = Enum.at(elements, index)

    element = Map.put(element, "word_class_id", value)
    elements = List.replace_at(elements, index, element)
    step = Map.put(step, :pattern_elements, elements)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("update_element_text", %{"index" => index, "value" => value}, socket) do
    index = String.to_integer(index)
    step = socket.assigns.current_step
    elements = step.pattern_elements
    element = Enum.at(elements, index)

    element = Map.put(element, "text", value)
    elements = List.replace_at(elements, index, element)
    step = Map.put(step, :pattern_elements, elements)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("remove_pattern_element", %{"index" => index}, socket) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    elements = List.delete_at(step.pattern_elements, index)
    step = Map.put(step, :pattern_elements, elements)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("toggle_optional", %{"index" => index}, socket) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    elements = step.pattern_elements
    element = Enum.at(elements, index)
    element = Map.put(element, "optional", !element["optional"])
    elements = List.replace_at(elements, index, element)
    step = Map.put(step, :pattern_elements, elements)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("add_example", _params, socket) do
    step = socket.assigns.current_step
    examples = step.examples ++ [%{"sentence" => "", "reading" => "", "meaning" => ""}]
    step = Map.put(step, :examples, examples)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event(
        "update_example",
        %{"index" => index, "field" => field, "value" => value},
        socket
      ) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    examples = step.examples
    example = Enum.at(examples, index)
    example = Map.put(example, field, value)
    examples = List.replace_at(examples, index, example)
    step = Map.put(step, :examples, examples)

    {:noreply, assign(socket, :current_step, step)}
  end

  # Handle blur event from example inputs
  @impl true
  def handle_event(
        "update_example",
        %{"index" => index, "field" => field, "_target" => _, "value" => value},
        socket
      ) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    examples = step.examples
    example = Enum.at(examples, index)
    example = Map.put(example, field, value)
    examples = List.replace_at(examples, index, example)
    step = Map.put(step, :examples, examples)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("remove_example", %{"index" => index}, socket) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    examples = List.delete_at(step.examples, index)
    step = Map.put(step, :examples, examples)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("validate_example", %{"index" => index}, socket) do
    step = socket.assigns.current_step
    example = Enum.at(step.examples, String.to_integer(index))
    sentence = example["sentence"] || ""

    # Check if sentence is empty
    if String.trim(sentence) == "" do
      {:noreply,
       put_flash(
         socket,
         :error,
         gettext("Please enter a Japanese sentence/word before validating.")
       )}
    else
      case Validator.validate_sentence(sentence, step.pattern_elements) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, gettext("Example is valid!"))}

        {:error, %{expected: expected, got: got}} when got == "" or is_nil(got) ->
          {:noreply,
           put_flash(
             socket,
             :error,
             gettext(
               "Example doesn't match pattern. Expected: %{expected}. Make sure you've entered the correct conjugated form (not the dictionary form).",
               expected: expected
             )
           )}

        {:error, reason} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             gettext(
               "Example doesn't match pattern. Expected: %{expected}, but got: %{got}. Make sure you've entered the correct conjugated form.",
               expected: reason[:expected] || "pattern",
               got: reason[:got] || "nothing"
             )
           )}
      end
    end
  end

  @impl true
  def handle_event("save_step", _params, socket) do
    step = socket.assigns.current_step
    lesson = socket.assigns.lesson

    # Validate all examples before saving
    all_valid =
      Enum.all?(step.examples, fn example ->
        example["sentence"] != "" and
          example["reading"] != "" and
          example["meaning"] != ""
      end)

    if not all_valid do
      {:noreply,
       put_flash(
         socket,
         :error,
         gettext("All examples must have sentence, reading, and meaning.")
       )}
    else
      attrs = %{
        position: step.position,
        title: step.title,
        explanation: step.explanation,
        pattern_elements: step.pattern_elements,
        examples: step.examples,
        difficulty: step.difficulty || 1,
        custom_lesson_id: lesson.id
      }

      result =
        if socket.assigns.current_step_index == :new do
          Content.create_grammar_lesson_step(attrs)
        else
          existing_step = Enum.at(socket.assigns.steps, socket.assigns.current_step_index)
          Content.update_grammar_lesson_step(existing_step, attrs)
        end

      case result do
        {:ok, _} ->
          steps = Content.list_grammar_lesson_steps(lesson.id)

          {:noreply,
           socket
           |> assign(:steps, steps)
           |> assign(:current_step_index, nil)
           |> assign(:current_step, nil)
           |> put_flash(:info, gettext("Step saved successfully."))}

        {:error, changeset} ->
          errors =
            Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
              Regex.replace(~r/%\{(\w+)\}/, msg, fn _, key ->
                opts[String.to_existing_atom(key)] |> to_string()
              end)
            end)

          {:noreply,
           put_flash(
             socket,
             :error,
             gettext("Failed to save step: %{errors}", errors: inspect(errors))
           )}
      end
    end
  end

  @impl true
  def handle_event("toggle_requires_test", _params, socket) do
    lesson = socket.assigns.lesson
    new_value = !lesson.requires_test

    case Content.update_custom_lesson(lesson, %{requires_test: new_value}) do
      {:ok, updated_lesson} ->
        {:noreply, assign(socket, :lesson, updated_lesson)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update test setting."))}
    end
  end

  @impl true
  def handle_event("publish", _params, socket) do
    lesson = socket.assigns.lesson
    steps = socket.assigns.steps

    # Check minimum content - at least 1 grammar step
    if length(steps) < 1 do
      {:noreply,
       put_flash(socket, :error, gettext("Add at least 1 grammar step before publishing."))}
    else
      # Generate test if required and not already generated
      test_result =
        if lesson.requires_test and is_nil(lesson.test_id) do
          Medoru.Tests.GrammarLessonTestGenerator.generate_lesson_test(lesson.id)
        else
          {:ok, nil}
        end

      case test_result do
        {:ok, _} ->
          # Reload lesson to get updated test_id
          lesson = Content.get_custom_lesson!(lesson.id)

          # Mark as published
          case Content.publish_custom_lesson(lesson) do
            {:ok, lesson} ->
              {:noreply,
               socket
               |> assign(:lesson, lesson)
               |> put_flash(:info, gettext("Lesson published successfully!"))
               |> push_navigate(to: ~p"/teacher/custom-lessons/#{lesson.id}/publish")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, gettext("Failed to publish lesson."))}
          end

        {:error, reason} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             gettext("Failed to generate test: %{reason}", reason: inspect(reason))
           )}
      end
    end
  end

  # Helper functions

  defp create_pattern_element("word_slot") do
    %{
      "type" => "word_slot",
      "word_type" => "verb",
      "form" => nil,
      "optional" => false
    }
  end

  defp create_pattern_element("word_class") do
    %{
      "type" => "word_class",
      "word_class_id" => nil,
      "optional" => false
    }
  end

  defp create_pattern_element("literal") do
    %{
      "type" => "literal",
      "text" => ""
    }
  end

  # Get forms for a specific word type
  def get_forms_for_word_type(grammar_forms, word_type) do
    Enum.filter(grammar_forms, fn form -> form.word_type == word_type end)
  end
end
