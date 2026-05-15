defmodule MedoruWeb.LessonLive.Index do
  use MedoruWeb, :live_view

  alias Medoru.Classrooms

  @per_page 20

  embed_templates "index*.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, :locale, locale)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = parse_page(params["page"])

    result =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        Classrooms.list_all_student_classroom_lessons(
          socket.assigns.current_scope.current_user.id,
          page: page,
          per_page: @per_page
        )
      else
        %{lessons: [], total_count: 0, total_pages: 1}
      end

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:classroom_lessons, result.lessons)
     |> assign(:total_count, result.total_count)
     |> assign(:total_pages, result.total_pages)
     |> assign(:page_title, gettext("Lessons"))}
  end

  defp parse_page(nil), do: 1

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  def page_link_params(page) do
    [page: page]
  end

  # Skill level color coding (same as games)
  defp skill_level_color(1), do: "bg-success/10 text-success border-success/20"
  defp skill_level_color(2), do: "bg-info/10 text-info border-info/20"
  defp skill_level_color(3), do: "bg-purple-500/20 text-purple-500 border-purple-500/40"
  defp skill_level_color(4), do: "bg-error/10 text-error border-error/20"
  defp skill_level_color(5), do: "bg-warning/10 text-warning border-warning/20"
  defp skill_level_color(_), do: "bg-base-200 text-base-content border-base-300"

  defp skill_level_label(1), do: gettext("Beginner")
  defp skill_level_label(2), do: gettext("Elementary")
  defp skill_level_label(3), do: gettext("Intermediate")
  defp skill_level_label(4), do: gettext("Advanced")
  defp skill_level_label(5), do: gettext("Expert")
  defp skill_level_label(_), do: gettext("Unknown")

  defp skill_level_card_bg(1), do: "bg-success/5 border-success/20"
  defp skill_level_card_bg(2), do: "bg-info/5 border-info/20"
  defp skill_level_card_bg(3), do: "bg-purple-500/5 border-purple-500/30"
  defp skill_level_card_bg(4), do: "bg-error/5 border-error/20"
  defp skill_level_card_bg(5), do: "bg-warning/5 border-warning/20"
  defp skill_level_card_bg(_), do: "bg-base-100 border-base-300"
end
