defmodule MedoruWeb.StepBuilderComponents do
  @moduledoc """
  Components for the teacher test step builder.

  Provides UI components for:
  - Step list with drag-drop reordering
  - Step preview cards
  - Step type selector
  - Empty state placeholders
  """

  use MedoruWeb, :html

  alias Medoru.Tests.TestStep

  @doc """
  Renders the step builder container with drag-drop support.
  """
  attr :steps, :list, required: true
  attr :test, :map, required: true
  attr :myself, :any, default: nil

  def step_builder_container(assigns) do
    ~H"""
    <div class="space-y-4" id="step-builder-container">
      <%= if Enum.empty?(@steps) do %>
        <.empty_steps_state test_id={@test.id} />
      <% else %>
        <div
          id="steps-list"
          phx-hook="StepSorter"
          class="space-y-3"
          data-test-id={@test.id}
        >
          <%= for {step, index} <- Enum.with_index(@steps) do %>
            <.step_card step={step} index={index} myself={@myself} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders an individual step card with drag handle and actions.
  """
  attr :step, TestStep, required: true
  attr :index, :integer, required: true
  attr :myself, :any, default: nil

  def step_card(assigns) do
    ~H"""
    <div
      id={"step-#{@step.id}"}
      data-step-id={@step.id}
      class="group bg-base-100 rounded-xl border border-base-200 shadow-sm hover:shadow-md transition-all duration-200"
    >
      <div class="p-4 flex items-start gap-4">
        <%!-- Drag Handle --%>
        <div
          class="drag-handle cursor-grab active:cursor-grabbing p-2 text-base-content/30 hover:text-base-content/60 transition-colors"
          title="Drag to reorder"
        >
          <.icon name="hero-bars-3" class="w-5 h-5" />
        </div>

        <%!-- Step Number --%>
        <div class="flex-shrink-0 w-8 h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-semibold text-sm">
          {@index + 1}
        </div>

        <%!-- Step Content Preview --%>
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 mb-1">
            <.step_type_badge step_type={@step.step_type} question_type={@step.question_type} />
            <span class="text-sm text-base-content/60">{@step.points} pts</span>
          </div>
          <p class="text-base-content font-medium truncate">
            {@step.question}
          </p>
          <%= if @step.explanation do %>
            <p class="text-sm text-secondary mt-1 line-clamp-2">
              {@step.explanation}
            </p>
          <% end %>
        </div>

        <%!-- Actions --%>
        <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            type="button"
            phx-click="edit_step"
            phx-value-step-id={@step.id}
            class="p-2 text-secondary hover:text-primary hover:bg-base-200 rounded-lg transition-colors"
            title="Edit step"
          >
            <.icon name="hero-pencil-square" class="w-5 h-5" />
          </button>
          <button
            type="button"
            phx-click="delete_step"
            phx-value-step-id={@step.id}
            data-confirm="Are you sure you want to delete this step?"
            class="p-2 text-secondary hover:text-error hover:bg-error/10 rounded-lg transition-colors"
            title="Delete step"
          >
            <.icon name="hero-trash" class="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a badge showing the step and question type.
  """
  attr :step_type, :atom, required: true
  attr :question_type, :atom, required: true

  def step_type_badge(assigns) do
    colors = %{
      multichoice: "bg-blue-100 text-blue-800",
      fill: "bg-purple-100 text-purple-800",
      match: "bg-green-100 text-green-800",
      order: "bg-orange-100 text-orange-800",
      writing: "bg-red-100 text-red-800",
      reading_text: "bg-teal-100 text-teal-800"
    }

    labels = %{
      multichoice: "Multiple Choice",
      fill: "Fill in Blank",
      match: "Matching",
      order: "Order",
      writing: "Writing",
      reading_text: "Reading"
    }

    assigns =
      assign(assigns,
        color_class: Map.get(colors, assigns.question_type, "bg-base-200 text-base-content"),
        label: Map.get(labels, assigns.question_type, to_string(assigns.question_type))
      )

    ~H"""
    <span class={["text-xs font-medium px-2 py-1 rounded-full", @color_class]}>
      {@label}
    </span>
    """
  end

  @doc """
  Renders the empty state when no steps exist.
  """
  attr :test_id, :string, required: true

  def empty_steps_state(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-2xl border border-dashed border-base-300 p-12 text-center">
      <div class="w-16 h-16 bg-base-200 rounded-full flex items-center justify-center mx-auto mb-4">
        <.icon name="hero-plus-circle" class="w-8 h-8 text-secondary" />
      </div>
      <h3 class="text-lg font-semibold text-base-content mb-2">No steps yet</h3>
      <p class="text-secondary max-w-sm mx-auto mb-6">
        Start building your test by adding questions. You can create multiple choice, writing, and reading questions.
      </p>
      <button
        type="button"
        phx-click="open_step_selector"
        class="btn btn-primary"
      >
        <.icon name="hero-plus" class="w-5 h-5" /> Add First Step
      </button>
    </div>
    """
  end

  @doc """
  Renders the step type selector modal content.
  """
  attr :on_select, :any, required: true

  def step_type_selector(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <.step_type_option
        type={:multichoice}
        icon="hero-list-bullet"
        title="Multiple Choice"
        description="Students select from options"
        points="1 point"
        on_select={@on_select}
      />
      <.step_type_option
        type={:reading_text}
        icon="hero-language"
        title="Reading Comprehension"
        description="Students type meaning and reading"
        points="2 points"
        on_select={@on_select}
      />
      <.step_type_option
        type={:writing}
        icon="hero-pencil"
        title="Kanji Writing"
        description="Students draw kanji on canvas"
        points="5 points"
        on_select={@on_select}
      />
    </div>
    """
  end

  attr :type, :atom, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :points, :string, required: true
  attr :on_select, :any, required: true

  defp step_type_option(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@on_select}
      phx-value-type={@type}
      class="group flex flex-col items-start p-4 rounded-xl border border-base-200 hover:border-primary hover:bg-primary/5 transition-all duration-200 text-left"
    >
      <div class="w-10 h-10 rounded-lg bg-primary/10 text-primary flex items-center justify-center mb-3 group-hover:bg-primary group-hover:text-primary-content transition-colors">
        <.icon name={@icon} class="w-5 h-5" />
      </div>
      <h4 class="font-semibold text-base-content mb-1">{@title}</h4>
      <p class="text-sm text-secondary mb-2">{@description}</p>
      <span class="text-xs font-medium text-primary bg-primary/10 px-2 py-1 rounded-full">
        {@points}
      </span>
    </button>
    """
  end

  @doc """
  Renders the test summary stats at the top of the builder.
  """
  attr :test, :map, required: true
  attr :step_count, :integer, required: true

  def test_summary_card(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl border border-base-200 p-4 mb-6">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-xl font-bold text-base-content">{@test.title}</h2>
          <%= if @test.description do %>
            <p class="text-secondary mt-1">{@test.description}</p>
          <% end %>
        </div>
        <div class="flex items-center gap-4 text-sm">
          <div class="text-center">
            <div class="text-2xl font-bold text-primary">{@step_count}</div>
            <div class="text-secondary">Steps</div>
          </div>
          <div class="w-px h-10 bg-base-200"></div>
          <div class="text-center">
            <div class="text-2xl font-bold text-primary">{@test.total_points}</div>
            <div class="text-secondary">Points</div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the floating action button for adding steps.
  """
  def add_step_fab(assigns) do
    ~H"""
    <div class="fixed bottom-6 right-6 flex items-center gap-3">
      <button
        type="button"
        phx-click="open_step_selector"
        class="btn btn-primary btn-circle shadow-lg hover:scale-105 transition-transform"
        title="Add Step"
      >
        <.icon name="hero-plus" class="w-6 h-6" />
      </button>
    </div>
    """
  end

  @doc """
  Renders the step builder toolbar with actions.
  """
  attr :test, :map, required: true
  attr :step_count, :integer, required: true

  def step_builder_toolbar(assigns) do
    ~H"""
    <div class="flex items-center justify-between bg-base-100 rounded-xl border border-base-200 p-4 mb-6">
      <div class="flex items-center gap-4">
        <.link navigate={~p"/teacher/tests/#{@test.id}"} class="btn btn-ghost btn-sm gap-2">
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Test
        </.link>
        <div class="w-px h-6 bg-base-200"></div>
        <span class="text-sm text-secondary">
          {@step_count} steps • {@test.total_points} total points
        </span>
      </div>

      <div class="flex items-center gap-2">
        <%= if @step_count > 0 do %>
          <button
            type="button"
            phx-click="mark_ready"
            class="btn btn-primary btn-sm gap-2"
          >
            <.icon name="hero-check" class="w-4 h-4" /> Mark Ready
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end
