defmodule Medoru.Content.ImageLessonBuilder do
  @moduledoc """
  Builds a custom vocabulary lesson from AI-extracted vocabulary.

  For each extracted word:
  - Tries to find an existing word in the database by exact text match
  - If found, links the existing word to the lesson
  - If not found, creates a new word and links it
  - Stores the original image form and notes as custom_meaning on the lesson word
  """

  require Logger

  alias Medoru.Content
  alias Medoru.Content.Word

  @default_title "Vocabulary lesson from image — change the name"
  @max_title_length 100
  @max_description_length 500

  @doc """
  Builds a custom lesson from extracted vocabulary words.

  ## Parameters

    * `extracted_words` - List of maps from `Medoru.AI.ImageVocabulary.extract_vocabulary/1`
    * `lesson_attrs` - Map with `:title` (optional) and `:description` (optional)
    * `creator_id` - User ID of the admin/teacher creating the lesson

  ## Returns

    * `{:ok, %CustomLesson{}}` - Lesson created successfully with words linked
    * `{:error, String.t() | Ecto.Changeset.t()}` - Error message or changeset
  """
  def build_lesson_from_extracted_words([], _lesson_attrs, _creator_id) do
    return_error("No words provided")
  end

  def build_lesson_from_extracted_words(extracted_words, lesson_attrs, creator_id) do
    lesson_title =
      String.slice(lesson_attrs[:title] || @default_title, 0, @max_title_length)

    lesson_description =
      String.slice(lesson_attrs[:description] || "", 0, @max_description_length)

    # Create the lesson first
    lesson_attrs = %{
      title: lesson_title,
      description: lesson_description,
      lesson_type: "reading",
      lesson_subtype: "vocabulary",
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
        add_words_to_lesson(lesson, extracted_words)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp add_words_to_lesson(lesson, extracted_words) do
    results =
      extracted_words
      |> Enum.with_index()
      |> Enum.map(fn {word_data, position} ->
        add_single_word(lesson.id, word_data, position)
      end)

    errors =
      Enum.filter(results, fn
        {:error, _} -> true
        _ -> false
      end)

    if errors == [] do
      # Refresh lesson with word count updated
      {:ok, Content.get_custom_lesson!(lesson.id)}
    else
      # Return first error
      hd(errors)
    end
  end

  defp add_single_word(lesson_id, word_data, position) do
    text = word_data["text"]
    reading = Word.normalize_reading(word_data["reading"])
    meaning = word_data["meaning"]
    word_type = word_data["word_type"]
    image_text = word_data["image_text"]
    notes = word_data["notes"]

    # If text has no kanji, try to find a kanji version in the DB by reading
    text =
      if has_kanji?(text) do
        Logger.info("[ImageLessonBuilder] Word '#{text}' already has kanji, using as-is")
        text
      else
        case find_kanji_version_by_reading(reading) do
          nil ->
            Logger.info(
              "[ImageLessonBuilder] No kanji fallback for '#{text}' (reading: '#{reading}') — keeping as-is"
            )

            text

          kanji_text ->
            Logger.info(
              "[ImageLessonBuilder] Kanji fallback: '#{text}' → '#{kanji_text}' (reading: '#{reading}')"
            )

            kanji_text
        end
      end

    # Build examples from image form + notes so the lesson uses the DB word meaning
    examples = build_examples(image_text, notes)

    # Try to find existing word by text
    existing_word = Content.get_word_by_text(text)

    # If the matched word is kana-only, try to upgrade to a kanji version from DB
    existing_word =
      case existing_word do
        nil ->
          nil

        word ->
          if has_kanji?(word.text) do
            word
          else
            case find_kanji_version_by_reading(reading) do
              nil -> word
              kanji_text -> Content.get_word_by_text(kanji_text) || word
            end
          end
      end

    word_id =
      case existing_word do
        nil ->
          Logger.debug(
            "[ImageLessonBuilder] Creating new word: text='#{text}', reading='#{reading}'"
          )

          # Create new word
          word_attrs = %{
            text: text,
            reading: reading,
            meaning: meaning,
            difficulty: 5,
            word_type: safe_word_type_atom(word_type),
            usage_frequency: 1000
          }

          case Content.create_word(word_attrs) do
            {:ok, word} ->
              word.id

            {:error, changeset} ->
              # Try to extract a cleaner error
              error_msg =
                case changeset.errors do
                  [{field, {msg, _}} | _] -> "#{field}: #{msg}"
                  _ -> "Failed to create word '#{text}'"
                end

              return_error(error_msg)
          end

        word ->
          word.id
      end

    if is_binary(word_id) do
      lesson_word_attrs = %{
        position: position,
        examples: examples
      }

      Content.add_word_to_lesson(lesson_id, word_id, lesson_word_attrs)
    else
      word_id
    end
  end

  defp build_examples(image_text, notes) do
    image_text = String.trim(image_text)
    notes = String.trim(notes)

    case {image_text, notes} do
      {"", ""} -> []
      {_, ""} -> [image_text]
      {"", _} -> [notes]
      {_, _} -> ["#{image_text} (#{notes})"]
    end
  end

  defp has_kanji?(text) when is_binary(text) do
    String.to_charlist(text)
    |> Enum.any?(fn cp ->
      (cp >= 0x4E00 and cp <= 0x9FFF) or
        (cp >= 0x3400 and cp <= 0x4DBF)
    end)
  end

  defp find_kanji_version_by_reading(reading) do
    words = Content.find_words_by_reading(reading)
    count = length(words)

    if count == 0 do
      Logger.info("[ImageLessonBuilder] No DB words found for reading '#{reading}'")
    else
      Logger.info(
        "[ImageLessonBuilder] DB search for reading '#{reading}' found #{count} word(s)"
      )
    end

    case words do
      [] ->
        nil

      words ->
        # Pick the first word that has kanji in its text
        result =
          Enum.find_value(words, fn word ->
            has_kanji = has_kanji?(word.text)

            Logger.info(
              "[ImageLessonBuilder]   candidate: text='#{word.text}', reading='#{word.reading}', has_kanji=#{has_kanji}"
            )

            if has_kanji do
              word.text
            else
              nil
            end
          end)

        if is_nil(result) do
          Logger.info("[ImageLessonBuilder]   none of the #{count} candidate(s) had kanji")
        else
          Logger.info("[ImageLessonBuilder]   selected kanji text: '#{result}'")
        end

        result
    end
  end

  defp safe_word_type_atom(word_type) do
    valid_types = [
      "noun",
      "verb",
      "adjective",
      "adverb",
      "particle",
      "pronoun",
      "counter",
      "expression",
      "other"
    ]

    if word_type in valid_types do
      String.to_existing_atom(word_type)
    else
      :other
    end
  end

  defp return_error(msg), do: {:error, msg}
end
