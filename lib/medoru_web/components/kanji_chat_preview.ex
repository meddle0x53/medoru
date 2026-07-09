defmodule MedoruWeb.KanjiChatPreview do
  @moduledoc """
  Compact kanji preview for chat messages.
  Shows meanings, stroke SVG, and readings in a clickable card.
  """
  use MedoruWeb, :html

  alias Medoru.Content

  def kanji_chat_preview(assigns) do
    strokes = get_strokes(assigns.kanji.stroke_data)
    bounds = get_bounds(assigns.kanji.stroke_data)
    total = length(strokes)

    assigns =
      assigns
      |> assign(:strokes, strokes)
      |> assign(:bounds, bounds)
      |> assign(:total_strokes, total)

    ~H"""
    <a
      href={kanji_path(@kanji)}
      target="_blank"
      rel="noopener noreferrer"
      class="block max-w-[180px] kanji-chat-preview"
    >
      <div class="bg-base-100 border border-base-300 rounded-xl p-3 shadow-sm hover:shadow-md hover:border-primary/30 transition-all">
        <%!-- Meanings --%>
        <div class="text-xs text-center text-secondary mb-2 truncate px-1">
          <%= for {meaning, i} <- Enum.with_index(@meanings) do %>
            <%= if i > 0 do %>
              <span class="text-base-content/30">, </span>
            <% end %>
            <span>{meaning}</span>
          <% end %>
        </div>

        <%!-- Stroke SVG --%>
        <div class="bg-base-100 border border-base-300 rounded-lg p-2 mx-auto w-fit">
          <svg viewBox={@bounds["viewBox"]} class="w-20 h-20">
            <%= for stroke <- @strokes do %>
              <path
                d={stroke["path"]}
                fill="none"
                stroke="currentColor"
                stroke-width="3"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="text-primary"
                style={stroke_style(stroke["order"], @total_strokes)}
              />
            <% end %>
          </svg>
        </div>

        <%!-- Readings --%>
        <div class="text-xs text-center mt-2 flex justify-center gap-2">
          <%= if @on_reading do %>
            <span class="font-medium text-primary">{@on_reading}</span>
          <% end %>
          <%= if @kun_reading do %>
            <span class="font-medium text-accent">{@kun_reading}</span>
          <% end %>
        </div>
      </div>
    </a>
    """
  end

  @doc """
  Renders the kanji preview as a safe HTML string for use outside of HEEx templates.
  """
  def render_html(%{
        kanji: kanji,
        meanings: meanings,
        on_reading: on_reading,
        kun_reading: kun_reading
      }) do
    strokes = get_strokes(kanji.stroke_data)
    bounds = get_bounds(kanji.stroke_data)
    total = length(strokes)

    meanings_html =
      meanings
      |> Enum.with_index()
      |> Enum.map_join("", fn {meaning, i} ->
        sep = if i > 0, do: ~s|<span class="text-base-content/30">, </span>|, else: ""
        "#{sep}<span>#{Phoenix.HTML.html_escape(meaning) |> elem(1)}</span>"
      end)

    on_html =
      if on_reading do
        ~s|<span class="font-medium text-primary">#{Phoenix.HTML.html_escape(on_reading) |> elem(1)}</span>|
      else
        ""
      end

    kun_html =
      if kun_reading do
        ~s|<span class="font-medium text-accent">#{Phoenix.HTML.html_escape(kun_reading) |> elem(1)}</span>|
      else
        ""
      end

    stroke_paths =
      strokes
      |> Enum.with_index()
      |> Enum.map_join("", fn {stroke, idx} ->
        order = stroke["order"] || idx + 1
        style = stroke_style(order, total)
        path = Phoenix.HTML.html_escape(stroke["path"]) |> elem(1)

        ~s|<path d="#{path}" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="text-primary" style="#{style}" />|
      end)

    viewbox = bounds["viewBox"] || "0 0 100 100"
    kanji_path = kanji_path(kanji)

    # Build compact HTML with no extra whitespace to avoid issues with whitespace-pre-wrap
    html =
      ~s|<a href="#{kanji_path}" target="_blank" rel="noopener noreferrer" class="block max-w-[180px] kanji-chat-preview -mt-1 -mb-1">| <>
        ~s|<div class="bg-base-100 border border-base-300 rounded-xl p-2 shadow-sm hover:shadow-md hover:border-primary/30 transition-all">| <>
        ~s|<div class="text-xs text-center text-secondary mb-1 truncate px-1">#{meanings_html}</div>| <>
        ~s|<div class="bg-base-100 border border-base-300 rounded-lg p-1.5 mx-auto w-fit"><svg viewBox="#{viewbox}" class="w-20 h-20">#{stroke_paths}</svg></div>| <>
        ~s|<div class="text-xs text-center mt-1 flex justify-center gap-2">#{on_html}#{kun_html}</div>| <>
        ~s|</div></a>|

    {:safe, html}
  end

  defp get_strokes(%{"strokes" => strokes}) when is_list(strokes) do
    strokes
    |> Enum.with_index(1)
    |> Enum.map(fn
      {stroke, _idx} when is_map(stroke) -> stroke
      {path, idx} when is_binary(path) -> %{"path" => path, "order" => idx}
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_strokes(_), do: []

  defp get_bounds(%{"bounds" => bounds}), do: bounds
  defp get_bounds(_), do: %{"width" => 100, "height" => 100, "viewBox" => "0 0 100 100"}

  defp stroke_style(order, total) when total > 0 do
    delay = (order - 1) * 400
    duration = max(600, trunc(800 / total * 4))

    "stroke-dasharray: 1000; stroke-dashoffset: 1000; animation-name: draw; animation-duration: #{duration}ms; animation-timing-function: ease-in-out; animation-fill-mode: forwards; animation-delay: #{delay}ms;"
  end

  defp stroke_style(_, _), do: ""

  @doc """
  Builds preview assigns from a kanji struct.
  """
  def build_preview_assigns(kanji, locale) do
    readings = kanji.kanji_readings
    on = Enum.find(readings, &(&1.reading_type == :on))
    kun = Enum.find(readings, &(&1.reading_type == :kun))
    meanings = Content.get_localized_kanji_meanings(kanji, locale)

    %{
      kanji: kanji,
      meanings: Enum.take(meanings, 3),
      on_reading: on && on.reading,
      kun_reading: kun && kun.reading
    }
  end
end
