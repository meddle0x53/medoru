defmodule MedoruWeb.LearnedGrammarsLive.Index do
  @moduledoc """
  LiveView for displaying a user's learned grammar definitions.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Accounts
  alias Medoru.Learning
  alias Medoru.Content

  @per_page 30

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, :locale, locale)}
  end

  @impl true
  def handle_params(%{"id" => user_id}, _url, socket) do
    user = Accounts.get_user!(user_id)

    result =
      list_learned_grammars_paginated(user_id,
        page: 1,
        per_page: @per_page
      )

    {:noreply,
     socket
     |> assign(:user, user)
     |> assign(:page, 1)
     |> assign(:grammar_definitions, result.grammar_definitions)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)
     |> assign(:page_title, gettext("%{name}'s Learned Grammar", name: user.name || user.email))}
  end

  @impl true
  def handle_event("change_page", %{"page" => page}, socket) do
    page = parse_page(page)
    user_id = socket.assigns.user.id

    result =
      list_learned_grammars_paginated(user_id,
        page: page,
        per_page: @per_page
      )

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:grammar_definitions, result.grammar_definitions)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)}
  end

  defp list_learned_grammars_paginated(user_id, opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 30)

    total_count = Learning.count_learned_grammar_definitions(user_id)

    grammar_definitions =
      Learning.list_learned_grammar_definitions(user_id,
        limit: per_page,
        offset: (page - 1) * per_page
      )

    total_pages = ceil(total_count / per_page)

    %{
      grammar_definitions: grammar_definitions,
      total_count: total_count,
      total_pages: max(1, total_pages)
    }
  end

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  # Helpers for template
  def level_badge_color(5), do: "badge-success"
  def level_badge_color(4), do: "badge-info"
  def level_badge_color(3), do: "badge-warning"
  def level_badge_color(2), do: "badge-error"
  def level_badge_color(1), do: "badge-secondary"
  def level_badge_color(_), do: "badge-ghost"

  def localized_description(%Content.GrammarDefinition{} = gd, locale) do
    Content.GrammarDefinition.localized_description(gd, locale)
  end
end
