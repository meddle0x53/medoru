defmodule Mix.Tasks.Medoru.Translations do
  @moduledoc """
  Tasks for managing content translations.

  ## Export data for translation

      mix medoru.translations.export words --output data/export/words.json
      mix medoru.translations.export kanji --output data/export/kanji.json
      mix medoru.translations.export lessons --output data/export/lessons.json

  ## Import translated data

      mix medoru.translations.import words --input data/export/words_bg.json
      mix medoru.translations.import kanji --input data/export/kanji_bg.json
      mix medoru.translations.import lessons --input data/export/lessons_bg.json

  ## Check translation status

      mix medoru.translations.status

  """

  use Mix.Task
  import Ecto.Query

  alias Medoru.Repo
  alias Medoru.Content.{Kanji, Lesson, Word}

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      ["export", type | opts] -> export(type, parse_opts(opts))
      ["import", type | opts] -> import_translations(type, parse_opts(opts))
      ["status"] -> show_status()
      _ -> print_help()
    end
  end

  defp parse_opts(opts) do
    Enum.reduce(opts, %{}, fn opt, acc ->
      case String.split(opt, "=", parts: 2) do
        ["--" <> key, value] -> Map.put(acc, String.to_atom(key), value)
        ["--" <> key] -> Map.put(acc, String.to_atom(key), true)
        _ -> acc
      end
    end)
  end

  defp export("words", opts) do
    output = opts[:output] || "data/export/words.json"

    words =
      Repo.all(Word)
      |> Enum.map(fn w ->
        %{
          id: w.id,
          text: w.text,
          reading: w.reading,
          meaning: w.meaning,
          difficulty: w.difficulty,
          translations: w.translations
        }
      end)

    write_json(output, words)
    Mix.shell().info("Exported #{length(words)} words to #{output}")
  end

  defp export("kanji", opts) do
    output = opts[:output] || "data/export/kanji.json"

    kanji =
      Repo.all(Kanji)
      |> Enum.map(fn k ->
        %{
          id: k.id,
          character: k.character,
          meanings: k.meanings,
          stroke_count: k.stroke_count,
          jlpt_level: k.jlpt_level,
          translations: k.translations
        }
      end)

    write_json(output, kanji)
    Mix.shell().info("Exported #{length(kanji)} kanji to #{output}")
  end

  defp export("lessons", opts) do
    output = opts[:output] || "data/export/lessons.json"

    lessons =
      Repo.all(Lesson)
      |> Enum.map(fn l ->
        %{
          id: l.id,
          title: l.title,
          description: l.description,
          difficulty: l.difficulty,
          order_index: l.order_index,
          lesson_type: l.lesson_type,
          translations: l.translations
        }
      end)

    write_json(output, lessons)
    Mix.shell().info("Exported #{length(lessons)} lessons to #{output}")
  end

  defp export(type, _opts) do
    Mix.shell().error("Unknown type: #{type}. Use: words, kanji, or lessons")
  end

  defp import_translations("words", opts) do
    input = opts[:input] || "data/export/words_translated.json"

    unless File.exists?(input) do
      Mix.shell().error("File not found: #{input}")
      exit({:shutdown, 1})
    end

    data = read_json(input)

    Enum.each(data, fn item ->
      word = Repo.get(Word, item["id"])

      if word do
        translations = merge_translations(word.translations, item["translations"])

        word
        |> Word.changeset(%{translations: translations})
        |> Repo.update!()
      else
        Mix.shell().warning("Word not found: #{item["id"]}")
      end
    end)

    Mix.shell().info("Imported translations for #{length(data)} words")
  end

  defp import_translations("kanji", opts) do
    input = opts[:input] || "data/export/kanji_translated.json"

    unless File.exists?(input) do
      Mix.shell().error("File not found: #{input}")
      exit({:shutdown, 1})
    end

    data = read_json(input)

    Enum.each(data, fn item ->
      kanji = Repo.get(Kanji, item["id"])

      if kanji do
        translations = merge_translations(kanji.translations, item["translations"])

        kanji
        |> Kanji.changeset(%{translations: translations})
        |> Repo.update!()
      else
        Mix.shell().warning("Kanji not found: #{item["id"]}")
      end
    end)

    Mix.shell().info("Imported translations for #{length(data)} kanji")
  end

  defp import_translations("lessons", opts) do
    input = opts[:input] || "data/export/lessons_translated.json"

    unless File.exists?(input) do
      Mix.shell().error("File not found: #{input}")
      exit({:shutdown, 1})
    end

    data = read_json(input)

    Enum.each(data, fn item ->
      lesson = Repo.get(Lesson, item["id"])

      if lesson do
        translations = merge_translations(lesson.translations, item["translations"])

        lesson
        |> Lesson.changeset(%{translations: translations})
        |> Repo.update!()
      else
        Mix.shell().warning("Lesson not found: #{item["id"]}")
      end
    end)

    Mix.shell().info("Imported translations for #{length(data)} lessons")
  end

  defp import_translations(type, _opts) do
    Mix.shell().error("Unknown type: #{type}. Use: words, kanji, or lessons")
  end

  defp show_status do
    word_count = Repo.aggregate(Word, :count)
    kanji_count = Repo.aggregate(Kanji, :count)
    lesson_count = Repo.aggregate(Lesson, :count)

    words_with_bg =
      Repo.one(
        from w in Word,
          where: fragment("?->'bg' IS NOT NULL", w.translations),
          select: count(w.id)
      )

    words_with_ja =
      Repo.one(
        from w in Word,
          where: fragment("?->'ja' IS NOT NULL", w.translations),
          select: count(w.id)
      )

    kanji_with_bg =
      Repo.one(
        from k in Kanji,
          where: fragment("?->'bg' IS NOT NULL", k.translations),
          select: count(k.id)
      )

    kanji_with_ja =
      Repo.one(
        from k in Kanji,
          where: fragment("?->'ja' IS NOT NULL", k.translations),
          select: count(k.id)
      )

    Mix.shell().info("""
    Translation Status:
    ===================

    Words:
      Total:     #{word_count}
      Bulgarian: #{words_with_bg} (#{Float.round(words_with_bg / word_count * 100, 1)}%)
      Japanese:  #{words_with_ja} (#{Float.round(words_with_ja / word_count * 100, 1)}%)

    Kanji:
      Total:     #{kanji_count}
      Bulgarian: #{kanji_with_bg} (#{Float.round(kanji_with_bg / kanji_count * 100, 1)}%)
      Japanese:  #{kanji_with_ja} (#{Float.round(kanji_with_ja / kanji_count * 100, 1)}%)

    Lessons:
      Total:     #{lesson_count}
    """)
  end

  defp print_help do
    Mix.shell().info("""
    Usage:
      mix medoru.translations.export words --output path/to/words.json
      mix medoru.translations.export kanji --output path/to/kanji.json
      mix medoru.translations.export lessons --output path/to/lessons.json

      mix medoru.translations.import words --input path/to/words_bg.json
      mix medoru.translations.import kanji --input path/to/kanji_bg.json
      mix medoru.translations.import lessons --input path/to/lessons_bg.json

      mix medoru.translations.status
    """)
  end

  defp write_json(path, data) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(data, pretty: true))
  end

  defp read_json(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end

  defp merge_translations(existing, new_translations) when is_map(new_translations) do
    existing = existing || %{}

    Enum.reduce(new_translations, existing, fn {lang, content}, acc ->
      Map.put(acc, lang, content)
    end)
  end

  defp merge_translations(existing, _), do: existing
end
