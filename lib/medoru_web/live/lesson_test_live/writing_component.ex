defmodule MedoruWeb.LessonTestLive.WritingComponent do
  @moduledoc """
  Component for kanji writing test steps.

  Provides a canvas-based drawing area where users can practice writing kanji.
  Supports mouse, pen, and touch input.
  """
  use Phoenix.Component

  import MedoruWeb.CoreComponents, only: [icon: 1]

  attr :step, :map, required: true
  attr :target, :any, required: true

  def writing_question(assigns) do
    ~H"""
    <div
      class="space-y-6"
      id={"writing-component-#{@step.id}"}
      phx-hook="KanjiWriting"
      data-target={@target}
    >
      <%!-- Hidden stroke data for JS library --%>
      <%!-- Use step's question_data if available, otherwise fall back to kanji's stroke_data --%>
      <% strokes =
        @step.question_data["strokes"] || (@step.kanji && @step.kanji.stroke_data["strokes"]) || [] %>
      <div data-stroke-data={Jason.encode!(strokes)} class="hidden"></div>

      <%!-- Question --%>
      <div class="text-center">
        <h2 class="text-2xl font-bold text-base-content mb-2">
          {@step.question}
        </h2>
        <p class="text-secondary text-lg">
          <%= if @step.question_data["stroke_count"] do %>
            {@step.question_data["stroke_count"]} strokes
          <% end %>
        </p>
      </div>

      <%!-- Writing Canvas Container (SVG created by KanjiWriter) --%>
      <div class="flex justify-center">
        <div
          id={"writing-canvas-container-#{@step.id}"}
          class="bg-base-100 border-2 border-base-300 rounded-xl overflow-hidden writing-canvas-container"
          style="width: 300px; height: 300px;"
        >
        </div>
      </div>

      <%!-- Controls (handled by JS hook) --%>
      <div class="flex justify-center gap-3">
        <button
          type="button"
          data-action="clear"
          class="px-4 py-2 bg-base-200 hover:bg-base-300 rounded-lg text-secondary transition-colors flex items-center gap-2"
        >
          <.icon name="hero-trash" class="w-5 h-5" /> Clear
        </button>
        <button
          type="button"
          data-action="hint"
          class="px-4 py-2 bg-info/20 hover:bg-info/30 text-info rounded-lg transition-colors flex items-center gap-2"
        >
          <.icon name="hero-light-bulb" class="w-5 h-5" /> Hint
        </button>
        <button
          type="button"
          data-action="submit"
          class="px-6 py-2 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors flex items-center gap-2"
        >
          <.icon name="hero-check" class="w-5 h-5" /> Submit
        </button>
      </div>

      <%!-- Instructions --%>
      <div class="text-center text-sm text-secondary">
        <p>Draw the kanji stroke by stroke. Red guide shows next stroke.</p>
        <p class="text-xs mt-1">Wrong strokes will be cleared automatically.</p>
      </div>
    </div>
    """
  end

  attr :kanji, :map, required: true

  def stroke_preview(assigns) do
    ~H"""
    <div class="bg-base-100 border border-base-300 rounded-2xl p-6">
      <div class="text-center mb-4">
        <div class="inline-flex items-center gap-2 text-error mb-2">
          <.icon name="hero-x-circle" class="w-6 h-6" />
          <span class="font-semibold">Incorrect - Study the correct strokes</span>
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
        <p class="text-sm text-secondary mb-4">
          <strong>Meanings:</strong> {Enum.join(@kanji.meanings || [], ", ")} •
          <strong>Strokes:</strong> {@kanji.stroke_count}
        </p>
        <button
          type="button"
          phx-click="hide_stroke_preview"
          class="px-6 py-3 bg-primary hover:bg-primary/90 text-primary-content rounded-xl font-medium transition-colors"
        >
          Continue →
        </button>
      </div>
    </div>
    """
  end
end
