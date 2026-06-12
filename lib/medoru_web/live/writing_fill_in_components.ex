defmodule MedoruWeb.WritingFillInComponents do
  @moduledoc """
  Shared UI component for writing fill-in test steps.
  """

  use Phoenix.Component

  use Gettext, backend: MedoruWeb.Gettext

  attr :step, :map, required: true
  attr :answers, :map, default: %{}
  attr :input_event, :string, default: "update_writing_fill_in"
  attr :disabled, :boolean, default: false

  def fill_in_question(assigns) do
    qd = assigns.step.question_data || %{}
    template = qd["template"] || ""
    parts = String.split(template, "___")
    blanks_count = max(length(parts) - 1, 0)

    assigns =
      assign(assigns,
        examples: List.wrap(qd["examples"]) |> Enum.reject(&(&1 == "")),
        legacy_example: qd["example"] || "",
        parts: parts,
        blanks_count: blanks_count
      )

    ~H"""
    <div class="space-y-6 mb-6">
      <div class="text-base-content font-medium">
        {@step.question}
      </div>

      <%= if @examples != [] do %>
        <div class="bg-base-200 rounded-xl p-4 space-y-2">
          <div class="text-sm text-secondary mb-1">{gettext("Examples")}</div>
          <%= for example <- @examples do %>
            <div class="text-lg font-jp text-base-content">{example}</div>
          <% end %>
        </div>
      <% end %>
      <%= if @examples == [] && @legacy_example != "" do %>
        <div class="bg-base-200 rounded-xl p-4">
          <div class="text-sm text-secondary mb-1">{gettext("Example")}</div>
          <div class="text-lg font-jp text-base-content">{@legacy_example}</div>
        </div>
      <% end %>

      <div class="text-lg font-jp text-base-content leading-loose">
        <%= for {part, index} <- Enum.with_index(@parts) do %>
          <span>{part}</span>
          <%= if index < @blanks_count do %>
            <input
              type="text"
              name={"writing_fill_in_answer[#{index}]"}
              value={@answers[to_string(index)] || ""}
              phx-change={@input_event}
              phx-value-index={index}
              class="input input-bordered w-32 sm:w-40 font-jp text-lg mx-1"
              placeholder={gettext("...")}
              disabled={@disabled}
            />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Builds the full sentence by filling `answers` into the template's `___` blanks.
  """
  def build_filled_sentence(template, answers) when is_binary(template) and is_map(answers) do
    parts = String.split(template, "___")

    {result, _} =
      Enum.reduce(parts, {"", 0}, fn part, {acc, idx} ->
        value = if idx > 0, do: Map.get(answers, to_string(idx - 1), ""), else: ""
        {acc <> value <> part, idx + 1}
      end)

    result
  end

  def build_filled_sentence(_template, _answers), do: ""
end
