defmodule Medoru.Content.GrammarImageBuilder do
  @moduledoc """
  Builds a custom grammar lesson from AI-extracted grammar sections.

  For each extracted section:
  - Creates a grammar step (with examples) if the title has pattern markers
  - Creates a text step (description only) otherwise
  - Pattern elements are left as a placeholder for the teacher to fill in
  """

  require Logger

  alias Medoru.Content

  @default_title "Grammar lesson from image — change the name"

  # Placeholder pattern element for grammar steps
  @placeholder_pattern [%{"type" => "literal", "text" => "—"}]

  @doc """
  Builds a custom grammar lesson from extracted sections.

  ## Parameters

    * `extracted_data` - Map from `Medoru.AI.GrammarParser.parse_extracted_grammar/1`
    * `lesson_attrs` - Map with `:title` (optional) and `:description` (optional)
    * `creator_id` - User ID of the admin/teacher creating the lesson

  ## Returns

    * `{:ok, %CustomLesson{}}` - Lesson created successfully with steps
    * `{:error, String.t() | Ecto.Changeset.t()}` - Error message or changeset
  """
  def build_lesson_from_extracted_grammar(%{"sections" => []}, _lesson_attrs, _creator_id) do
    return_error("No grammar sections found")
  end

  def build_lesson_from_extracted_grammar(extracted_data, lesson_attrs, creator_id) do
    sections = extracted_data["sections"] || []

    if sections == [] do
      return_error("No grammar sections found")
    else
      lesson_title = lesson_attrs[:title] || extracted_data["title"] || @default_title
      lesson_description = lesson_attrs[:description] || ""

      lesson_attrs = %{
        title: lesson_title,
        description: lesson_description,
        lesson_type: "reading",
        lesson_subtype: "grammar",
        status: "draft",
        difficulty: lesson_attrs[:difficulty] || 5,
        creator_id: creator_id,
        requires_test: false,
        include_writing: false,
        steps_per_word: 3,
        show_pictures: true,
        show_sounds: true
      }

      case Content.create_custom_lesson(lesson_attrs) do
        {:ok, lesson} ->
          add_steps_to_lesson(lesson, sections)

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  defp add_steps_to_lesson(lesson, sections) do
    results =
      sections
      |> Enum.with_index()
      |> Enum.map(fn {section, index} ->
        create_step(lesson.id, section, index)
      end)

    errors =
      Enum.filter(results, fn
        {:error, _} -> true
        _ -> false
      end)

    if errors == [] do
      {:ok, Content.get_custom_lesson!(lesson.id)}
    else
      hd(errors)
    end
  end

  defp create_step(lesson_id, section, position) do
    step_type = section["step_type"] || "text"
    title = (section["title"] || "") |> String.slice(0, 100)
    description = section["description"] || ""
    examples = (section["examples"] || []) |> Enum.take(5)

    attrs =
      case step_type do
        "grammar" ->
          %{
            position: position,
            custom_lesson_id: lesson_id,
            step_type: "grammar",
            title: title,
            explanation: String.slice(description, 0, 10_000),
            explanation_sections: [],
            pattern_elements: @placeholder_pattern,
            examples: examples,
            word_colors: [],
            difficulty: 1,
            include_in_test: false,
            allows_student_validation: false
          }

        _ ->
          %{
            position: position,
            custom_lesson_id: lesson_id,
            step_type: "text",
            title: title,
            explanation: "",
            explanation_sections: split_description(description),
            pattern_elements: [],
            examples: [],
            word_colors: [],
            difficulty: 1,
            include_in_test: false,
            allows_student_validation: false
          }
      end

    case Content.create_grammar_lesson_step(attrs) do
      {:ok, step} ->
        Logger.info("[GrammarImageBuilder] Created #{step_type} step #{position}: #{title}")
        {:ok, step}

      {:error, changeset} ->
        error_msg =
          case changeset.errors do
            [{field, {msg, _}} | _] -> "#{field}: #{msg}"
            _ -> "Failed to create step '#{title}'"
          end

        Logger.error("[GrammarImageBuilder] Step error: #{error_msg}")
        return_error(error_msg)
    end
  end

  defp split_description(""), do: []

  defp split_description(description) do
    # Split description into paragraphs by double newlines,
    # then chunk any paragraph > 255 chars to fit varchar(255)[]
    description
    |> String.split("\n\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(&chunk_text(&1, 250))
  end

  defp chunk_text(text, max_len) do
    if String.length(text) <= max_len do
      [text]
    else
      # Try to split at sentence boundaries (。, ., \n)
      # Fallback to splitting at max_len
      do_chunk_text(text, max_len, [])
    end
  end

  defp do_chunk_text("", _max_len, acc), do: Enum.reverse(acc)

  defp do_chunk_text(text, max_len, acc) do
    len = String.length(text)

    if len <= max_len do
      Enum.reverse([text | acc])
    else
      # Find a good split point within max_len
      slice = String.slice(text, 0, max_len)

      # Try to find the last sentence boundary
      split_point =
        case Regex.run(~r/.*[。\.\n]/u, slice, return: :index) do
          [{0, idx}] when idx > 50 -> idx
          _ -> max_len
        end

      chunk = String.slice(text, 0, split_point) |> String.trim()
      rest = String.slice(text, split_point, len - split_point) |> String.trim()

      if rest == "" do
        Enum.reverse([chunk | acc])
      else
        do_chunk_text(rest, max_len, [chunk | acc])
      end
    end
  end

  defp return_error(msg), do: {:error, msg}
end
