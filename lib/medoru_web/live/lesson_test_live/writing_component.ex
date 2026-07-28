defmodule MedoruWeb.LessonTestLive.WritingComponent do
  @moduledoc """
  Component for kanji writing test steps.

  Provides a canvas-based drawing area where users can practice writing kanji.
  Supports mouse, pen, and touch input.
  """
  use Phoenix.Component
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.CoreComponents, only: [icon: 1]

  attr :step, :map, required: true
  attr :target, :any, required: true
  attr :locale, :string, default: "en"
  attr :show_submit, :boolean, default: true
  attr :kanji_drawing, :boolean, default: false
  attr :challenge_base, :integer, default: 0
  attr :total_points, :integer, default: 0
  attr :current_wrong_strokes, :integer, default: 0

  def writing_question(assigns) do
    ~H"""
    <div
      class="space-y-6"
      id={"writing-component-#{@step.id}"}
      phx-hook="KanjiWriting"
      data-target={@target}
      data-kanji-drawing={@kanji_drawing}
      data-stroke-points={@step.points}
      data-challenge-base={@challenge_base}
      data-total-points={@total_points}
      data-step-id={@step.id}
      data-current-wrong-strokes={@current_wrong_strokes}
    >
      <%= if @kanji_drawing do %>
        <% current_points = max(0, @step.points - @current_wrong_strokes) %>
        <% challenge_points = @challenge_base %>
        <div class="mb-4 p-3 bg-base-200 rounded-lg flex flex-wrap items-center justify-center gap-4 text-sm">
          <div class="flex items-center gap-2">
            <.icon name="hero-x-circle" class="w-4 h-4 text-error" />
            <span class="text-secondary">{gettext("Wrong strokes")}:</span>
            <span id={"kanji-wrong-stroke-count-#{@step.id}"} class="font-bold text-error">
              {@current_wrong_strokes}
            </span>
          </div>
          <div class="flex items-center gap-2">
            <.icon name="hero-pencil-square" class="w-4 h-4 text-primary" />
            <span class="text-secondary">{gettext("This kanji")}:</span>
            <span id={"kanji-current-points-#{@step.id}"} class="font-bold text-primary">
              {current_points} / {@step.points}
            </span>
          </div>
          <div class="flex items-center gap-2">
            <.icon name="hero-trophy" class="w-4 h-4 text-warning" />
            <span class="text-secondary">{gettext("Challenge")}:</span>
            <span id={"kanji-challenge-points-#{@step.id}"} class="font-bold text-warning">
              {challenge_points} / {@total_points}
            </span>
          </div>
        </div>
      <% end %>
      <%!-- Hidden stroke data for JS library --%>
      <%!-- Use step's question_data if available, otherwise fall back to kanji's stroke_data --%>
      <% strokes =
        @step.question_data["strokes"] || (@step.kanji && @step.kanji.stroke_data["strokes"]) || [] %>
      <div data-stroke-data={Jason.encode!(strokes)} class="hidden"></div>

      <%!-- Question --%>
      <div class="text-center">
        <h2 class="text-2xl font-bold text-base-content mb-2">
          {translate_question(@step, @locale)}
        </h2>
        <%= if word_context_step?(@step) do %>
          <p class="text-secondary text-lg mt-1">
            <%= if @step.question_data["reading_is_fallback"] do %>
              {gettext("Reading %{reading} (general kanji reading — no specific word reading set)",
                reading: @step.question_data["reading_display"]
              )}
            <% else %>
              {gettext("Reading %{reading}", reading: @step.question_data["reading_display"])}
            <% end %>
          </p>
        <% end %>
        <p class="text-secondary text-lg">
          <%= if @step.question_data["stroke_count"] do %>
            {@step.question_data["stroke_count"]} {gettext("strokes")}
          <% end %>
        </p>
        <%= if @step.kanji && @step.kanji.kanji_readings != [] && !word_context_step?(@step) do %>
          <p class="text-sm text-secondary mt-1">
            <span class="font-medium">{gettext("On")}:</span> {first_reading(@step.kanji, :on)} •
            <span class="font-medium">{gettext("Kun")}:</span> {first_reading(@step.kanji, :kun)}
          </p>
        <% end %>
        <%= if @step.question_data["hint_word_reading"] do %>
          <p class="text-sm text-secondary mt-1">
            <span class="font-medium">{gettext("Word")}:</span> {@step.question_data[
              "hint_word_reading"
            ]} ({@step.question_data["hint_word_meaning"]})
          </p>
        <% end %>
      </div>

      <%!-- Writing Canvas Container --%>
      <div class="flex justify-center">
        <div
          id={"writing-canvas-container-#{@step.id}"}
          class="bg-base-100 border-2 border-base-300 rounded-xl overflow-hidden writing-canvas-container relative"
          style="width: min(300px, 80vw); height: min(300px, 80vw); max-width: 300px; max-height: 300px;"
          phx-update="ignore"
        >
        </div>
      </div>

      <%!-- Controls (handled by JS hook) --%>
      <div class="flex flex-col sm:flex-row justify-center gap-3">
        <button
          type="button"
          data-action="clear"
          class="w-full sm:w-auto px-4 py-3 bg-base-200 hover:bg-base-300 rounded-lg text-secondary transition-colors flex items-center justify-center gap-2"
        >
          <.icon name="hero-trash" class="w-5 h-5" /> {gettext("Clear")}
        </button>
        <button
          type="button"
          data-action="hint"
          class="w-full sm:w-auto px-4 py-3 bg-info/20 hover:bg-info/30 text-info rounded-lg transition-colors flex items-center justify-center gap-2"
        >
          <.icon name="hero-light-bulb" class="w-5 h-5" /> {gettext("Hint")}
        </button>
        <%= if @show_submit do %>
          <button
            type="button"
            data-action="submit"
            class="w-full sm:w-auto px-6 py-3 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
          >
            <.icon name="hero-check" class="w-5 h-5" /> {gettext("Submit")}
          </button>
        <% end %>
      </div>

      <%= if @step.hints != [] do %>
        <div
          id={"writing-hint-text-#{@step.id}"}
          data-hint-text
          class="hidden text-center bg-info/10 border border-info/30 rounded-lg p-4"
        >
          <p class="text-sm text-info">
            <.icon name="hero-light-bulb" class="w-4 h-4 mr-1" />
            {List.first(@step.hints)}
          </p>
        </div>
      <% end %>

      <%!-- Instructions --%>
      <div class="text-center text-sm text-secondary">
        <p>{gettext("Draw the kanji stroke by stroke. Red guide shows next stroke.")}</p>
        <p class="text-xs mt-1">{gettext("Wrong strokes will be cleared automatically.")}</p>
      </div>
    </div>
    """
  end

  attr :kanji, :map, required: true
  attr :locale, :string, default: "en"

  def stroke_preview(assigns) do
    ~H"""
    <div class="bg-base-100 border border-base-300 rounded-2xl p-6">
      <div class="text-center mb-4">
        <div class="inline-flex items-center gap-2 text-error mb-2">
          <.icon name="hero-x-circle" class="w-6 h-6" />
          <span class="font-semibold">{gettext("Incorrect - Study the correct strokes")}</span>
        </div>
        <h3 class="text-3xl font-bold text-base-content">
          {@kanji.character}
        </h3>
      </div>

      <%!-- Use the same StrokeAnimator component as the kanji show page --%>
      <.live_component
        module={MedoruWeb.StrokeAnimator}
        id="wrong-answer-stroke-animator"
        stroke_data={@kanji.stroke_data}
      />

      <div class="mt-4 text-center">
        <p class="text-sm text-secondary mb-2">
          <strong>{gettext("Meanings")}:</strong> {get_localized_meanings(@kanji, @locale)}
        </p>
        <p class="text-sm text-secondary mb-4">
          <strong>{gettext("On")}:</strong> {first_reading(@kanji, :on)} •
          <strong>{gettext("Kun")}:</strong> {first_reading(@kanji, :kun)} •
          <strong>{gettext("Strokes")}:</strong> {@kanji.stroke_count}
        </p>
        <button
          type="button"
          phx-click="hide_stroke_preview"
          class="px-6 py-3 bg-primary hover:bg-primary/90 text-primary-content rounded-xl font-medium transition-colors"
        >
          {gettext("Continue")} →
        </button>
      </div>
    </div>
    """
  end

  # Translate question text, handling message key format
  defp translate_question(nil, _locale), do: ""

  defp translate_question(step, locale) when is_map(step) do
    question = step.question || ""

    case question do
      "__MSG_WRITE_KANJI_IN_WORD__|" <> rest ->
        case String.split(rest, "|", parts: 2) do
          [word_reading, word_meaning] ->
            gettext(
              "Write the kanji in the word %{word_reading} (%{word_meaning})",
              word_reading: word_reading,
              word_meaning: word_meaning
            )

          _ ->
            gettext("Write the kanji")
        end

      "__MSG_WRITE_KANJI_FOR__|" <> _ ->
        # Get localized meanings for the question
        meanings = get_localized_meanings_for_step(step, locale)
        gettext("Write the kanji for '%{meanings}'", meanings: meanings)

      _ ->
        # For backward compatibility: if question is plain meanings, try to localize
        # by looking up the kanji and getting its localized meanings
        localized = get_localized_meanings_for_step(step, locale)

        if localized != question and localized != "" do
          gettext("Write the kanji for '%{meanings}'", meanings: localized)
        else
          question
        end
    end
  end

  defp translate_question(question, _locale) when is_binary(question), do: question

  # Get localized meanings for display (first 1-2 only)
  defp get_localized_meanings(kanji, locale) do
    localized = Medoru.Content.get_localized_kanji_meanings(kanji, locale)
    localized |> Enum.take(2) |> Enum.join(", ")
  end

  # Get localized meanings for the step question (first 1-2 only)
  defp get_localized_meanings_for_step(step, locale) do
    # Try to get kanji from step
    kanji =
      case step.kanji do
        %Ecto.Association.NotLoaded{} -> nil
        nil -> nil
        k -> k
      end

    if kanji do
      get_localized_meanings(kanji, locale)
    else
      # Fallback to stored meanings in question_data (first 1-2 only)
      qd = step.question_data || %{}
      stored = qd["meanings"] || qd[:meanings] || []

      if stored != [] do
        stored |> Enum.take(2) |> Enum.join(", ")
      else
        # Last resort: extract from question string
        case String.split(step.question || "", "|") do
          [_, m] -> m
          _ -> ""
        end
      end
    end
  end

  # Get the first reading of a given type (:on or :kun) by admin-defined position
  defp first_reading(%{kanji_readings: %Ecto.Association.NotLoaded{}}, _type), do: "—"

  defp first_reading(kanji, type) do
    reading =
      (kanji.kanji_readings || [])
      |> Enum.filter(&(&1.reading_type == type))
      |> Enum.min_by(& &1.position, fn -> nil end)

    case reading do
      nil -> "—"
      reading -> reading.reading
    end
  end

  defp word_context_step?(step) do
    step.question_data && step.question_data["word_reading"] not in [nil, ""]
  end
end
