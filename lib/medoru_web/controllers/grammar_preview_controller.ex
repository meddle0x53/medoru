defmodule MedoruWeb.GrammarPreviewController do
  use MedoruWeb, :controller

  alias Medoru.Content

  def show(conn, %{"text" => text}) do
    case Content.get_grammar_definition_by_title(text) do
      nil ->
        send_resp(conn, 404, "")

      grammar ->
        first_example = List.first(grammar.examples || [])

        json(conn, %{
          id: grammar.id,
          title: grammar.title,
          slug: grammar.slug,
          jlpt_level: grammar.jlpt_level,
          pattern_elements: grammar.pattern_elements,
          first_example: first_example,
          path: ~p"/grammars/#{grammar.slug}"
        })
    end
  end
end
