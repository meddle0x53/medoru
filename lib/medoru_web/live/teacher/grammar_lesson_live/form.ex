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

  # 32 background colors for teacher-defined word highlighting
  @color_palette [
    "bg-red-200", "bg-red-300",
    "bg-orange-200", "bg-orange-300",
    "bg-amber-200", "bg-amber-300",
    "bg-yellow-200", "bg-yellow-300",
    "bg-lime-200", "bg-lime-300",
    "bg-green-200", "bg-green-300",
    "bg-emerald-200", "bg-emerald-300",
    "bg-teal-200", "bg-teal-300",
    "bg-cyan-200", "bg-cyan-300",
    "bg-sky-200", "bg-sky-300",
    "bg-blue-200", "bg-blue-300",
    "bg-indigo-200", "bg-indigo-300",
    "bg-violet-200", "bg-violet-300",
    "bg-purple-200", "bg-purple-300",
    "bg-fuchsia-200", "bg-fuchsia-300",
    "bg-pink-200", "bg-pink-300",
    "bg-rose-200", "bg-rose-300"
  ]

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
       |> assign(:color_palette, @color_palette)
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
            "lesson_subtype" => "grammar",
            "difficulty" => 1
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
  def handle_event("add_step", %{"type" => step_type}, socket) do
    lesson = socket.assigns.lesson

    if is_nil(lesson) do
      {:noreply, put_flash(socket, :error, gettext("Save the lesson first before adding steps."))}
    else
      new_step = create_step(step_type, length(socket.assigns.steps))

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
  def handle_event("move_step_up", %{"index" => index}, socket) do
    index = String.to_integer(index)
    steps = socket.assigns.steps

    if index > 0 do
      step = Enum.at(steps, index)
      prev_step = Enum.at(steps, index - 1)

      case Content.swap_step_positions(step, prev_step) do
        :ok ->
          lesson = socket.assigns.lesson
          steps = Content.list_grammar_lesson_steps(lesson.id)
          {:noreply, assign(socket, :steps, steps)}

        :error ->
          {:noreply, put_flash(socket, :error, gettext("Failed to reorder steps."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_step_down", %{"index" => index}, socket) do
    index = String.to_integer(index)
    steps = socket.assigns.steps

    if index < length(steps) - 1 do
      step = Enum.at(steps, index)
      next_step = Enum.at(steps, index + 1)

      case Content.swap_step_positions(step, next_step) do
        :ok ->
          lesson = socket.assigns.lesson
          steps = Content.list_grammar_lesson_steps(lesson.id)
          {:noreply, assign(socket, :steps, steps)}

        :error ->
          {:noreply, put_flash(socket, :error, gettext("Failed to reorder steps."))}
      end
    else
      {:noreply, socket}
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


  @impl true
  def handle_event("remove_example", %{"index" => index}, socket) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    examples = List.delete_at(step.examples, index)
    step = Map.put(step, :examples, examples)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("add_explanation_section", _params, socket) do
    step = socket.assigns.current_step
    sections = step.explanation_sections || []
    sections = sections ++ [""]
    step = Map.put(step, :explanation_sections, sections)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("update_explanation_section", %{"index" => index, "value" => value}, socket) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    sections = step.explanation_sections || []
    sections = List.replace_at(sections, index, value)
    step = Map.put(step, :explanation_sections, sections)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("remove_explanation_section", %{"index" => index}, socket) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    sections = List.delete_at(step.explanation_sections || [], index)
    step = Map.put(step, :explanation_sections, sections)

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
    step_type = step.step_type || "grammar"

    attrs =
      case step_type do
        "grammar" ->
          # Validate all examples before saving
          all_valid =
            Enum.all?(step.examples, fn example ->
              example["sentence"] != "" and
                example["reading"] != "" and
                example["meaning"] != ""
            end)

          if not all_valid do
            {:error, :invalid_examples}
          else
            {:ok,
             %{
               position: step.position,
               step_type: "grammar",
               title: step.title,
               explanation: step.explanation,
               explanation_sections: [],
               pattern_elements: step.pattern_elements,
               examples: step.examples,
               word_colors: step.word_colors || [],
               difficulty: step.difficulty || 1,
               include_in_test: step.include_in_test || false,
               allows_student_validation: step.allows_student_validation || false,
               custom_lesson_id: lesson.id
             }}
          end

        _ ->
          {:ok,
           %{
             position: step.position,
             step_type: step_type,
             title: step.title,
             explanation: "",
             explanation_sections: step.explanation_sections || [],
             pattern_elements: [],
             examples: [],
             word_colors: step.word_colors || [],
             difficulty: step.difficulty || 1,
             include_in_test: false,
             allows_student_validation: false,
             custom_lesson_id: lesson.id
           }}
      end

    case attrs do
      {:error, :invalid_examples} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("All examples must have sentence, reading, and meaning.")
         )}

      {:ok, attrs} ->
        result =
          if socket.assigns.current_step_index == :new do
            Content.create_grammar_lesson_step(attrs)
          else
            existing_step = Enum.at(socket.assigns.steps, socket.assigns.current_step_index)
            Content.update_grammar_lesson_step(existing_step, attrs)
          end

        case result do
          {:ok, saved_step} ->
            steps = Content.list_grammar_lesson_steps(lesson.id)

            # If this grammar step is included in test, ensure lesson requires_test
            socket =
              if saved_step.step_type == "grammar" and saved_step.include_in_test and
                   not lesson.requires_test do
                case Content.update_custom_lesson(lesson, %{requires_test: true}) do
                  {:ok, updated_lesson} -> assign(socket, :lesson, updated_lesson)
                  {:error, _} -> socket
                end
              else
                socket
              end

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
    steps = socket.assigns.steps

    # Update lesson test setting
    case Content.update_custom_lesson(lesson, %{requires_test: new_value}) do
      {:ok, updated_lesson} ->
        socket = assign(socket, :lesson, updated_lesson)

        # If enabling tests, mark all grammar steps as included
        if new_value do
          grammar_steps = Enum.filter(steps, &(&1.step_type == "grammar"))

          Enum.each(grammar_steps, fn step ->
            Content.update_grammar_lesson_step(step, %{include_in_test: true})
          end)

          steps = Content.list_grammar_lesson_steps(lesson.id)
          {:noreply, assign(socket, :steps, steps)}
        else
          # If disabling tests, mark all grammar steps as not included
          grammar_steps = Enum.filter(steps, &(&1.step_type == "grammar"))

          Enum.each(grammar_steps, fn step ->
            Content.update_grammar_lesson_step(step, %{include_in_test: false})
          end)

          steps = Content.list_grammar_lesson_steps(lesson.id)
          {:noreply, assign(socket, :steps, steps)}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update test setting."))}
    end
  end

  @impl true
  def handle_event("toggle_step_include_in_test", %{"index" => _index}, socket) do
    step = socket.assigns.current_step
    new_value = !(step.include_in_test || false)
    step = Map.put(step, :include_in_test, new_value)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("toggle_step_validation", %{"index" => _index}, socket) do
    step = socket.assigns.current_step
    new_value = !(step.allows_student_validation || false)
    step = Map.put(step, :allows_student_validation, new_value)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("publish", _params, socket) do
    lesson = socket.assigns.lesson
    steps = socket.assigns.steps

    grammar_steps = Enum.filter(steps, &(&1.step_type == "grammar"))

    cond do
      length(steps) < 1 ->
        {:noreply,
         put_flash(socket, :error, gettext("Add at least 1 step before publishing."))}

      lesson.requires_test and length(grammar_steps) < 1 ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Add at least 1 grammar step to generate a test.")
         )}

      true ->
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

  # Lesson-level word color handlers

  @impl true
  def handle_event("add_lesson_word_color", _params, socket) do
    lesson = socket.assigns.lesson

    if is_nil(lesson) do
      {:noreply, put_flash(socket, :error, gettext("Save the lesson first before adding word colors."))}
    else
      word_colors = lesson.word_colors || []

      new_color = %{
        "word" => "",
        "color_index" => 0,
        "apply_to" => "both"
      }

      case Content.update_custom_lesson(lesson, %{word_colors: word_colors ++ [new_color]}) do
        {:ok, updated_lesson} ->
          {:noreply, assign(socket, :lesson, updated_lesson)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to add word color."))}
      end
    end
  end

  @impl true
  def handle_event("remove_lesson_word_color", %{"index" => index}, socket) do
    lesson = socket.assigns.lesson
    index = String.to_integer(index)
    word_colors = List.delete_at(lesson.word_colors || [], index)

    case Content.update_custom_lesson(lesson, %{word_colors: word_colors}) do
      {:ok, updated_lesson} ->
        {:noreply, assign(socket, :lesson, updated_lesson)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove word color."))}
    end
  end

  @impl true
  def handle_event(
        "update_lesson_word_color",
        %{"index" => index, "field" => field} = params,
        socket
      ) do
    lesson = socket.assigns.lesson
    index = String.to_integer(index)
    word_colors = lesson.word_colors || []

    value = params["color"] || params["value"] || params[field]

    color = Enum.at(word_colors, index)

    updated_value =
      case field do
        "color_index" -> String.to_integer(value)
        _ -> value
      end

    color = Map.put(color, field, updated_value)
    word_colors = List.replace_at(word_colors, index, color)

    case Content.update_custom_lesson(lesson, %{word_colors: word_colors}) do
      {:ok, updated_lesson} ->
        {:noreply, assign(socket, :lesson, updated_lesson)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update word color."))}
    end
  end

  # Step-level word color handlers

  @impl true
  def handle_event("add_step_word_color", _params, socket) do
    step = socket.assigns.current_step

    new_color = %{
      "word" => "",
      "color_index" => 0,
      "apply_to" => "both"
    }

    word_colors = (step.word_colors || []) ++ [new_color]
    step = Map.put(step, :word_colors, word_colors)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event("remove_step_word_color", %{"index" => index}, socket) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    word_colors = List.delete_at(step.word_colors || [], index)
    step = Map.put(step, :word_colors, word_colors)

    {:noreply, assign(socket, :current_step, step)}
  end

  @impl true
  def handle_event(
        "update_step_word_color",
        %{"index" => index, "field" => field} = params,
        socket
      ) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    word_colors = step.word_colors || []

    value = params["color"] || params["value"] || params[field]

    color = Enum.at(word_colors, index)

    updated_value =
      case field do
        "color_index" -> String.to_integer(value)
        _ -> value
      end

    color = Map.put(color, field, updated_value)
    word_colors = List.replace_at(word_colors, index, color)
    step = Map.put(step, :word_colors, word_colors)

    {:noreply, assign(socket, :current_step, step)}
  end

  # Word Color Editor Component

  attr :word_colors, :list, default: []
  attr :color_palette, :list, required: true
  attr :update_event, :string, required: true
  attr :remove_event, :string, required: true

  def word_color_editor(assigns) do
    ~H"""
    <div class="space-y-2 max-h-80 overflow-y-auto">
      <%= for {color, idx} <- Enum.with_index(@word_colors) do %>
        <div class="border border-base-300 rounded-lg p-2 bg-base-50">
          <div class="flex items-center gap-2 mb-2">
            <input
              type="text"
              value={color["word"]}
              phx-blur={@update_event}
              phx-value-index={idx}
              phx-value-field="word"
              class="input input-bordered input-sm w-full font-jp"
              placeholder={gettext("Word")}
            />
            <button
              type="button"
              phx-click={@remove_event}
              phx-value-index={idx}
              class="text-error hover:opacity-70 shrink-0"
            >
              <.icon name="hero-trash" class="w-4 h-4" />
            </button>
          </div>
          <div class="grid grid-cols-8 gap-1 mb-2">
            <%= for {color_class, cidx} <- Enum.with_index(@color_palette) do %>
              <button
                type="button"
                phx-click={@update_event}
                phx-value-index={idx}
                phx-value-field="color_index"
                phx-value-color={cidx}
                class={[
                  "w-full aspect-square rounded border-2 transition-all",
                  color_class,
                  if(color["color_index"] == cidx, do: "border-primary scale-110", else: "border-transparent hover:border-base-content/30")
                ]}
                title={cidx + 1}
              />
            <% end %>
          </div>
          <select
            name="apply_to"
            phx-change={@update_event}
            phx-value-index={idx}
            phx-value-field="apply_to"
            class="select select-bordered select-sm w-full"
          >
            <option value="both" selected={color["apply_to"] == "both"}>{gettext("Both")}</option>
            <option value="examples" selected={color["apply_to"] == "examples"}>{gettext("Examples only")}</option>
            <option value="explanation" selected={color["apply_to"] == "explanation"}>{gettext("Explanation only")}</option>
          </select>
        </div>
      <% end %>
    </div>
    """
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

  defp create_step("grammar", position) do
    %{
      id: Ecto.UUID.generate(),
      position: position,
      step_type: "grammar",
      title: "",
      explanation: "",
      explanation_sections: [],
      pattern_elements: [],
      examples: [],
      word_colors: [],
      difficulty: 1,
      include_in_test: false,
      allows_student_validation: false
    }
  end

  defp create_step("text", position) do
    %{
      id: Ecto.UUID.generate(),
      position: position,
      step_type: "text",
      title: "",
      explanation: "",
      explanation_sections: [""],
      pattern_elements: [],
      examples: [],
      word_colors: [],
      difficulty: 1
    }
  end
end
