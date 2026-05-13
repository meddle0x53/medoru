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
end
