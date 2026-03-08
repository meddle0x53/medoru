defmodule MedoruWeb.StrokeAnimator do
  @moduledoc """
  LiveComponent for animating kanji stroke order.

  Provides an interactive SVG animation showing the correct
  stroke order for a kanji character.
  """
  use MedoruWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:current_stroke, 0)
     |> assign(:is_playing, false)
     |> assign(:speed, 1.0)
     |> assign(:show_numbers, true)
     |> assign(:completed_strokes, [])
     |> assign(:loop, false)}
  end

  @impl true
  def update(%{stroke_data: stroke_data} = assigns, socket) do
    strokes = get_strokes(stroke_data)
    total_strokes = length(strokes)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:strokes, strokes)
     |> assign(:total_strokes, total_strokes)
     |> assign(:bounds, get_bounds(stroke_data))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="stroke-animator" id={@id}>
      <div class="flex flex-col lg:flex-row gap-6">
        <%!-- SVG Canvas --%>
        <div class="flex-shrink-0">
          <div class="bg-base-100 border border-base-300 rounded-xl p-4 shadow-sm">
            <svg
              viewBox={@bounds["viewBox"]}
              class="w-64 h-64 mx-auto"
              style="background: linear-gradient(to right, rgba(128,128,128,0.05) 1px, transparent 1px),
                     linear-gradient(to bottom, rgba(128,128,128,0.05) 1px, transparent 1px);
                     background-size: 25% 25%, 25% 25%;"
            >
              <%!-- Completed strokes (dimmed) --%>
              <%= for stroke <- @completed_strokes do %>
                <path
                  d={stroke["path"]}
                  fill="none"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="text-base-content/30"
                />
              <% end %>

              <%!-- Current stroke (animated) --%>
              <%= if @current_stroke > 0 and @current_stroke <= @total_strokes do %>
                <% current = Enum.at(@strokes, @current_stroke - 1) %>
                <path
                  d={current["path"]}
                  fill="none"
                  stroke="currentColor"
                  stroke-width="4"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="text-primary"
                  style={animation_style(@is_playing, @speed)}
                />

                <%!-- Stroke number indicator --%>
                <%= if @show_numbers do %>
                  <% {sx, sy} = stroke_start_point(current["path"]) %>
                  <circle cx={sx} cy={sy} r="6" fill="hsl(var(--p))" />
                  <text
                    x={sx}
                    y={sy}
                    text-anchor="middle"
                    dominant-baseline="central"
                    fill="white"
                    font-size="8"
                    font-weight="bold"
                  >
                    {current["order"]}
                  </text>
                <% end %>
              <% end %>

              <%!-- Upcoming strokes (faint preview) --%>
              <%= for stroke <- upcoming_strokes(@strokes, @current_stroke) do %>
                <path
                  d={stroke["path"]}
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="text-base-content/10"
                />
              <% end %>
            </svg>
          </div>

          <%!-- Playback Controls --%>
          <div class="mt-4 flex items-center justify-center gap-2">
            <button
              type="button"
              phx-click="reset"
              phx-target={@myself}
              class="btn btn-ghost btn-sm btn-circle"
              title="Reset"
            >
              <.icon name="hero-arrow-uturn-left" class="w-5 h-5" />
            </button>

            <button
              type="button"
              phx-click="prev"
              phx-target={@myself}
              class="btn btn-ghost btn-sm btn-circle"
              title="Previous Stroke"
            >
              <.icon name="hero-chevron-left" class="w-5 h-5" />
            </button>

            <button
              type="button"
              phx-click={if @is_playing, do: "pause", else: "play"}
              phx-target={@myself}
              class="btn btn-primary btn-circle"
              title={if @is_playing, do: "Pause", else: "Play"}
            >
              <%= if @is_playing do %>
                <.icon name="hero-pause" class="w-6 h-6" />
              <% else %>
                <.icon name="hero-play" class="w-6 h-6" />
              <% end %>
            </button>

            <button
              type="button"
              phx-click="next"
              phx-target={@myself}
              class="btn btn-ghost btn-sm btn-circle"
              title="Next Stroke"
            >
              <.icon name="hero-chevron-right" class="w-5 h-5" />
            </button>

            <button
              type="button"
              phx-click="toggle_loop"
              phx-target={@myself}
              class={["btn btn-sm btn-circle", (@loop && "btn-primary") || "btn-ghost"]}
              title="Loop"
            >
              <.icon name="hero-arrow-path" class="w-5 h-5" />
            </button>
          </div>

          <%!-- Progress Indicator --%>
          <div class="mt-3 flex items-center gap-2 text-sm text-secondary">
            <span>Stroke</span>
            <span class="font-medium text-base-content">
              {@current_stroke} / {@total_strokes}
            </span>
            <div class="flex-1 h-2 bg-base-200 rounded-full overflow-hidden">
              <div
                class="h-full bg-primary transition-all duration-300"
                style={"width: #{stroke_progress(@current_stroke, @total_strokes)}%"}
              >
              </div>
            </div>
          </div>
        </div>

        <%!-- Stroke List & Settings --%>
        <div class="flex-1 min-w-0">
          <div class="bg-base-100 border border-base-300 rounded-xl p-4 shadow-sm">
            <h3 class="font-semibold text-base-content mb-3">Stroke Order</h3>

            <div class="space-y-1 max-h-64 overflow-y-auto">
              <%= for stroke <- @strokes do %>
                <div class={[
                  "flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors",
                  stroke_class(stroke["order"], @current_stroke, @completed_strokes)
                ]}>
                  <span class={[
                    "flex-shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium",
                    (stroke["order"] == @current_stroke && "bg-primary text-primary-content") ||
                      (stroke["order"] in Enum.map(@completed_strokes, & &1["order"]) &&
                         "bg-success/20 text-success") ||
                      "bg-base-200 text-secondary"
                  ]}>
                    {stroke["order"]}
                  </span>
                  <span class="capitalize text-secondary">
                    {stroke["type"]}
                  </span>
                  <span class="text-xs text-secondary/60 ml-auto">
                    {stroke["direction"]}
                  </span>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Settings --%>
          <div class="mt-4 bg-base-100 border border-base-300 rounded-xl p-4 shadow-sm">
            <h3 class="font-semibold text-base-content mb-3">Settings</h3>

            <div class="space-y-4">
              <%!-- Speed Control --%>
              <div>
                <label class="text-sm text-secondary flex items-center justify-between">
                  <span>Animation Speed</span>
                  <span class="font-medium">{format_speed(@speed)}x</span>
                </label>
                <input
                  type="range"
                  min="0.5"
                  max="3"
                  step="0.5"
                  value={@speed}
                  phx-change="set_speed"
                  phx-target={@myself}
                  class="range range-sm range-primary w-full mt-2"
                />
              </div>

              <%!-- Show Numbers Toggle --%>
              <label class="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={@show_numbers}
                  phx-click="toggle_numbers"
                  phx-target={@myself}
                  class="checkbox checkbox-primary checkbox-sm"
                />
                <span class="text-sm text-secondary">Show stroke numbers</span>
              </label>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("play", _, socket) do
    {:noreply, start_animation(socket)}
  end

  @impl true
  def handle_event("pause", _, socket) do
    {:noreply, assign(socket, :is_playing, false)}
  end

  @impl true
  def handle_event("reset", _, socket) do
    {:noreply,
     socket
     |> assign(:current_stroke, 0)
     |> assign(:is_playing, false)
     |> assign(:completed_strokes, [])}
  end

  @impl true
  def handle_event("next", _, socket) do
    {:noreply, advance_stroke(socket)}
  end

  @impl true
  def handle_event("prev", _, socket) do
    {:noreply, previous_stroke(socket)}
  end

  @impl true
  def handle_event("toggle_loop", _, socket) do
    {:noreply, update(socket, :loop, &not/1)}
  end

  @impl true
  def handle_event("set_speed", %{"value" => speed}, socket) do
    {:noreply, assign(socket, :speed, String.to_float(speed))}
  end

  @impl true
  def handle_event("toggle_numbers", _, socket) do
    {:noreply, update(socket, :show_numbers, &not/1)}
  end

  # Helper functions

  defp get_strokes(nil), do: []
  defp get_strokes(%{"strokes" => strokes}) when is_list(strokes), do: strokes
  defp get_strokes(_), do: []

  defp get_bounds(nil), do: %{"width" => 100, "height" => 100, "viewBox" => "0 0 100 100"}
  defp get_bounds(%{"bounds" => bounds}), do: bounds
  defp get_bounds(_), do: %{"width" => 100, "height" => 100, "viewBox" => "0 0 100 100"}

  defp upcoming_strokes(strokes, current) do
    strokes
    |> Enum.filter(fn s -> s["order"] > current end)
  end

  defp stroke_start_point(path) do
    # Extract first coordinate from SVG path (simplified)
    # KanjiVG uses format "Mx,y" or "M x y"
    case Regex.run(~r/^M\s*([\d.]+)[,\s]+([\d.]+)/, path) do
      [_, x, y] -> {x, y}
      _ -> {"50", "50"}
    end
  end

  defp animation_style(true, speed) do
    duration = trunc(1000 / speed)

    "stroke-dasharray: 1000; stroke-dashoffset: 1000; animation: draw #{duration}ms ease-in-out forwards;"
  end

  defp animation_style(false, _), do: ""

  defp stroke_class(order, current, completed) do
    cond do
      order == current -> "bg-primary/10 border border-primary/20"
      order in Enum.map(completed, & &1["order"]) -> "bg-success/5"
      true -> "hover:bg-base-200"
    end
  end

  defp stroke_progress(current, total) when total > 0 do
    trunc(current / total * 100)
  end

  defp stroke_progress(_, _), do: 0

  defp format_speed(speed) do
    :erlang.float_to_binary(speed, decimals: 1)
  end

  defp start_animation(socket) do
    socket =
      if socket.assigns.current_stroke == 0 do
        assign(socket, current_stroke: 1)
      else
        socket
      end

    assign(socket, :is_playing, true)
  end

  defp advance_stroke(socket) do
    current = socket.assigns.current_stroke
    strokes = socket.assigns.strokes

    if current > 0 and current <= length(strokes) do
      completed = Enum.at(strokes, current - 1)

      socket
      |> update(:completed_strokes, &[completed | &1])
      |> update(:current_stroke, &(&1 + 1))
    else
      socket
    end
  end

  defp previous_stroke(socket) do
    current = socket.assigns.current_stroke

    cond do
      current > 1 ->
        socket
        |> update(:current_stroke, &(&1 - 1))
        |> update(:completed_strokes, fn strokes ->
          # Remove the last completed stroke that matches current - 1
          Enum.reject(strokes, &(&1["order"] == current - 1))
        end)

      current == 1 ->
        assign(socket, current_stroke: 0, completed_strokes: [])

      true ->
        socket
    end
  end
end
