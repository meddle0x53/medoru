defmodule MedoruWeb.GrammarChatPreview do
  @moduledoc """
  Compact grammar definition preview for chat messages and white board posts.
  Shows title, JLPT badge, and colored pattern elements in a clickable card.
  """
  use MedoruWeb, :html

  def grammar_chat_preview(assigns) do
    ~H"""
    <a
      href={~p"/grammars/#{@grammar.slug}"}
      target="_blank"
      rel="noopener noreferrer"
      class="block max-w-full sm:max-w-[320px] grammar-chat-preview -mt-1 -mb-1"
    >
      <div class="bg-base-100 border border-base-300 rounded-xl p-3 shadow-sm hover:shadow-md hover:border-primary/30 transition-all">
        <%!-- Title + JLPT --%>
        <div class="flex items-center gap-2 mb-2">
          <div class="font-semibold text-sm text-base-content truncate">
            {@grammar.title}
          </div>
          <%= if @grammar.jlpt_level do %>
            <span class="badge badge-sm badge-primary shrink-0">
              N{@grammar.jlpt_level}
            </span>
          <% end %>
        </div>

        <%!-- Colored Pattern --%>
        <div class="flex flex-wrap gap-1.5 items-center">
          <%= for element <- @grammar.pattern_elements do %>
            <%= case element["type"] do %>
              <% "literal" -> %>
                <span class="px-2 py-0.5 bg-base-200 rounded text-base-content font-medium text-sm">
                  {element["text"] || ""}
                </span>
              <% "word_slot" -> %>
                <span class="px-2 py-0.5 bg-primary/10 rounded text-primary font-medium border border-primary/30 text-sm">
                  <%= if element["word_class"] do %>
                    {element["word_class"]}
                  <% else %>
                    {element["word_type"] || gettext("word")}
                  <% end %>
                  <%= if element["forms"] && length(element["forms"]) > 0 do %>
                    <span class="text-xs opacity-80">
                      ({Enum.join(element["forms"], ", ")})
                    </span>
                  <% end %>
                </span>
              <% "particle" -> %>
                <span class="px-2 py-0.5 bg-secondary/10 rounded text-secondary font-medium border border-secondary/30 text-sm">
                  {element["text"] || gettext("particle")}
                </span>
              <% _ -> %>
                <span class="px-2 py-0.5 bg-base-200 rounded text-base-content text-sm">
                  {element["type"]}
                </span>
            <% end %>
          <% end %>
        </div>

        <%!-- First example if available --%>
        <%= if @first_example do %>
          <div class="mt-2 pt-2 border-t border-base-200">
            <p class="text-sm text-base-content font-medium">
              {@first_example["sentence"]}
            </p>
            <%= if @first_example["meaning"] do %>
              <p class="text-xs text-secondary mt-0.5">
                {@first_example["meaning"]}
              </p>
            <% end %>
          </div>
        <% end %>
      </div>
    </a>
    """
  end

  @doc """
  Renders the grammar preview as a safe HTML string for use outside of HEEx templates.
  """
  def render_html(%{grammar: grammar}) do
    first_example = List.first(grammar.examples || [])

    jlpt_badge =
      if grammar.jlpt_level do
        ~s|<span class="badge badge-sm badge-primary shrink-0">N#{grammar.jlpt_level}</span>|
      else
        ""
      end

    pattern_html =
      (grammar.pattern_elements || [])
      |> Enum.map(fn element ->
        case element["type"] do
          "literal" ->
            text = Phoenix.HTML.html_escape(element["text"] || "") |> elem(1)

            ~s|<span class="px-2 py-0.5 bg-base-200 rounded text-base-content font-medium text-sm">#{text}</span>|

          "word_slot" ->
            label =
              if element["word_class"] do
                Phoenix.HTML.html_escape(element["word_class"]) |> elem(1)
              else
                Phoenix.HTML.html_escape(element["word_type"] || gettext("word")) |> elem(1)
              end

            forms_html =
              if element["forms"] && length(element["forms"]) > 0 do
                forms = Enum.join(element["forms"], ", ") |> Phoenix.HTML.html_escape() |> elem(1)
                ~s|<span class="text-xs opacity-80">(#{forms})</span>|
              else
                ""
              end

            ~s|<span class="px-2 py-0.5 bg-primary/10 rounded text-primary font-medium border border-primary/30 text-sm">#{label}#{forms_html}</span>|

          "particle" ->
            text = Phoenix.HTML.html_escape(element["text"] || gettext("particle")) |> elem(1)

            ~s|<span class="px-2 py-0.5 bg-secondary/10 rounded text-secondary font-medium border border-secondary/30 text-sm">#{text}</span>|

          _ ->
            type = Phoenix.HTML.html_escape(element["type"]) |> elem(1)

            ~s|<span class="px-2 py-0.5 bg-base-200 rounded text-base-content text-sm">#{type}</span>|
        end
      end)
      |> Enum.join("")

    example_html =
      if first_example do
        sentence = Phoenix.HTML.html_escape(first_example["sentence"] || "") |> elem(1)
        meaning = first_example["meaning"]

        meaning_html =
          if meaning && meaning != "" do
            escaped_meaning = Phoenix.HTML.html_escape(meaning) |> elem(1)
            ~s|<p class="text-xs text-secondary mt-0.5">#{escaped_meaning}</p>|
          else
            ""
          end

        ~s|<div class="mt-2 pt-2 border-t border-base-200"><p class="text-sm text-base-content font-medium">#{sentence}</p>#{meaning_html}</div>|
      else
        ""
      end

    grammar_path = ~p"/grammars/#{grammar.slug}"
    title = Phoenix.HTML.html_escape(grammar.title) |> elem(1)

    html =
      ~s|<a href="#{grammar_path}" target="_blank" rel="noopener noreferrer" class="block max-w-[320px] grammar-chat-preview -mt-1 -mb-1">| <>
        ~s|<div class="bg-base-100 border border-base-300 rounded-xl p-3 shadow-sm hover:shadow-md hover:border-primary/30 transition-all">| <>
        ~s|<div class="flex items-center gap-2 mb-2"><div class="font-semibold text-sm text-base-content truncate">#{title}</div>#{jlpt_badge}</div>| <>
        ~s|<div class="flex flex-wrap gap-1.5 items-center">#{pattern_html}</div>| <>
        example_html <>
        ~s|</div></a>|

    {:safe, html}
  end

  @doc """
  Builds preview assigns from a grammar definition struct.
  """
  def build_preview_assigns(grammar) do
    %{
      grammar: grammar,
      first_example: List.first(grammar.examples || [])
    }
  end
end
