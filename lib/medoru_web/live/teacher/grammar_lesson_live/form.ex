defmodule MedoruWeb.Teacher.GrammarLessonLive.Form do
  @moduledoc """
  Teacher form for creating and editing grammar lessons.
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
       |> assign(:word_types, @word_types)}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    user = socket.assigns.current_scope.current_user

    case socket.assigns.live_action do
      :new ->
        changeset = Content.change_custom_lesson(%Content.CustomLesson{}, %{
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
    changeset =
      %Content.CustomLesson{}
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
  def handle_event("update_step_field", %{"field" => field, "value" => value}, socket) do
    step = socket.assigns.current_step
    step = Map.put(step, String.to_atom(field), value)

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
  def handle_event("update_pattern_element", %{"index" => index, "field" => field, "value" => value}, socket) do
    step = socket.assigns.current_step
    index = String.to_integer(index)
    elements = step.pattern_elements
    element = Enum.at(elements, index)
    element = Map.put(element, field, value)
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
  def handle_event("update_example", %{"index" => index, "field" => field, "value" => value}, socket) do
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

    case Validator.validate_sentence(example["sentence"], step.pattern_elements) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, gettext("Example is valid!"))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, gettext("Example doesn't match pattern: %{reason}", reason: inspect(reason)))}
    end
  end

  @impl true
  def handle_event("save_step", _params, socket) do
    step = socket.assigns.current_step
    lesson = socket.assigns.lesson

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
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Regex.replace(~r/%\{(\w+)\}/, msg, fn _, key ->
            opts[String.to_existing_atom(key)] |> to_string()
          end)
        end)

        {:noreply, put_flash(socket, :error, gettext("Failed to save step: %{errors}", errors: inspect(errors)))}
    end
  end

  # Helper functions

  defp create_pattern_element("word_slot") do
    %{
      "type" => "word_slot",
      "word_type" => "verb",
      "forms" => [],
      "word_class" => nil,
      "optional" => false
    }
  end

  defp create_pattern_element("literal") do
    %{
      "type" => "literal",
      "text" => ""
    }
  end
end
