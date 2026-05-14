defmodule MedoruWeb.Teacher.KanjiFallingGameLive.Show do
  @moduledoc """
  LiveView for teachers to view a kanji falling game's details and rankings.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.Components.Helpers, only: [display_name: 3]

  alias Medoru.Classrooms
  alias Medoru.Games

  embed_templates "show*.html"

  @impl true
  def mount(%{"classroom_id" => classroom_id, "id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    game = Games.get_game!(id)
    classroom = Classrooms.get_classroom!(classroom_id)

    if classroom.teacher_id != user.id or game.classroom_id != classroom_id do
      {:ok,
       socket
       |> put_flash(:error, gettext("You don't have permission to view this game."))
       |> push_navigate(to: ~p"/teacher/classrooms")}
    else
      sessions = Games.list_kanji_falling_sessions(game.id)
      members = Classrooms.list_classroom_members(classroom_id)

      {:ok,
       socket
       |> assign(:page_title, game.name)
       |> assign(:classroom, classroom)
       |> assign(:game, game)
       |> assign(:sessions, sessions)
       |> assign(:members, members)}
    end
  end

  @impl true
  def handle_event("publish_game", _, socket) do
    user = socket.assigns.current_scope.current_user
    game = socket.assigns.game

    case Games.publish_game(game.id, user.id) do
      {:ok, updated_game} ->
        {:noreply,
         socket
         |> assign(:game, %{game | status: updated_game.status})
         |> put_flash(:info, gettext("Game published."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to publish game."))}
    end
  end

  @impl true
  def handle_event("unpublish_game", _, socket) do
    user = socket.assigns.current_scope.current_user
    game = socket.assigns.game

    case Games.unpublish_game(game.id, user.id) do
      {:ok, updated_game} ->
        {:noreply,
         socket
         |> assign(:game, %{game | status: updated_game.status})
         |> put_flash(:info, gettext("Game unpublished."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to unpublish game."))}
    end
  end

  @impl true
  def handle_event("delete_game", _, socket) do
    user = socket.assigns.current_scope.current_user
    game = socket.assigns.game
    classroom_id = game.classroom_id

    case Games.delete_game(game, user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Game deleted."))
         |> push_navigate(to: ~p"/teacher/classrooms/#{classroom_id}?tab=games")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete game."))}
    end
  end
end
