defmodule MedoruWeb.Teacher.GameLive.New do
  @moduledoc """
  LiveView for selecting a game type to create.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms

  @impl true
  def mount(%{"classroom_id" => classroom_id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, gettext("You don't have permission to create games in this classroom."))
       |> push_navigate(to: ~p"/teacher/classrooms")}
    else
      {:ok,
       socket
       |> assign(:page_title, gettext("Create Game"))
       |> assign(:classroom, classroom)}
    end
  end

  embed_templates "new*.html"
end
