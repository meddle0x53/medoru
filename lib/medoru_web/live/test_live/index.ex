defmodule MedoruWeb.TestLive.Index do
  @moduledoc """
  Shows tests from the featured public classroom.
  Anonymous users can browse and start published tests.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.SiteSettings

  embed_templates "index*.html"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {classroom_tests, classroom} =
      case SiteSettings.featured_classroom_id() do
        nil ->
          {[], nil}

        classroom_id ->
          tests = Classrooms.list_classroom_tests(classroom_id, status: :active)
          classroom = Classrooms.get_classroom!(classroom_id)
          {tests, classroom}
      end

    {:noreply,
     socket
     |> assign(:page_title, gettext("Tests"))
     |> assign(:classroom_tests, classroom_tests)
     |> assign(:featured_classroom, classroom)}
  end

  defp format_duration(nil), do: nil

  defp format_duration(seconds) when seconds >= 60 do
    minutes = div(seconds, 60)
    gettext("%{count} min", count: minutes)
  end

  defp format_duration(seconds) do
    gettext("%{count} sec", count: seconds)
  end
end
