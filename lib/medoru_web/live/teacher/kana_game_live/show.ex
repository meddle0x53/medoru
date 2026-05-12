defmodule MedoruWeb.Teacher.KanaGameLive.Show do
  @moduledoc """
  LiveView for teachers to view a kana game's details and rankings.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.Components.Helpers, only: [display_name: 3]

  alias Medoru.Classrooms
  alias Medoru.Games

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
      sessions = Games.list_game_sessions(game.id)
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
  def handle_event("reset_student", %{"user_id" => user_id}, socket) do
    game = socket.assigns.game

    case Games.reset_session(game.id, user_id) do
      {:ok, _} ->
        sessions = Games.list_game_sessions(game.id)

        {:noreply,
         socket
         |> assign(:sessions, sessions)
         |> put_flash(:info, gettext("Student progress reset successfully."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to reset student progress."))}
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
    classroom = socket.assigns.classroom

    case Games.delete_game(game.id, user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Game deleted."))
         |> push_navigate(to: ~p"/teacher/classrooms/#{classroom.id}?tab=games")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete game."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/classrooms/#{@classroom.id}?tab=games"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Games")}
          </.link>
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div>
              <div class="flex items-center gap-3 mb-2">
                <h1 class="text-2xl sm:text-3xl font-bold text-base-content">{@game.name}</h1>
                <%= if @game.status == :published do %>
                  <span class="badge badge-success"><%= gettext("Published") %></span>
                <% else %>
                  <span class="badge badge-ghost"><%= gettext("Draft") %></span>
                <% end %>
              </div>
              <p class="text-secondary">
                {gettext("Kana Memory Card Game")} · {@game.kana_memory_card_game.board_size}
              </p>
            </div>
            <div class="flex gap-2">
              <%= if @game.status == :draft do %>
                <button phx-click="publish_game" class="btn btn-success btn-sm">
                  <.icon name="hero-eye" class="w-4 h-4 mr-1" /> <%= gettext("Publish") %>
                </button>
              <% else %>
                <button phx-click="unpublish_game" class="btn btn-ghost btn-outline btn-sm">
                  <.icon name="hero-eye-slash" class="w-4 h-4 mr-1" /> <%= gettext("Unpublish") %>
                </button>
              <% end %>
              <.link
                navigate={~p"/teacher/classrooms/#{@classroom.id}/kana-games/#{@game.id}/edit"}
                class="btn btn-primary btn-sm"
              >
                <.icon name="hero-pencil" class="w-4 h-4 mr-1" /> {gettext("Edit")}
              </.link>
              <button
                phx-click="delete_game"
                data-confirm={gettext("Are you sure you want to delete this game?")}
                class="btn btn-error btn-outline btn-sm"
              >
                <.icon name="hero-trash" class="w-4 h-4 mr-1" /> {gettext("Delete")}
              </button>
            </div>
          </div>
        </div>
        <% kmcg = @game.kana_memory_card_game %>
        <div class="card bg-base-100 border border-base-300 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title text-base-content mb-4">{gettext("Game Details")}</h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <div class="bg-base-200 p-4 rounded-lg">
                <p class="text-secondary text-sm">{gettext("Board Size")}</p>
                <p class="text-lg font-bold text-base-content">{kmcg.board_size}</p>
              </div>
              <div class="bg-base-200 p-4 rounded-lg">
                <p class="text-secondary text-sm">{gettext("Max Attempts")}</p>
                <p class="text-lg font-bold text-base-content">{kmcg.max_attempts}</p>
              </div>
              <div class="bg-base-200 p-4 rounded-lg">
                <p class="text-secondary text-sm">{gettext("Max Players")}</p>
                <p class="text-lg font-bold text-base-content">
                  <%= if @game.max_players == 1 do %>
                    <%= gettext("Single Player") %>
                  <% else %>
                    <%= @game.max_players %>
                  <% end %>
                </p>
              </div>
              <div class="bg-base-200 p-4 rounded-lg">
                <p class="text-secondary text-sm">{gettext("Collection")}</p>
                <p class="text-lg font-bold text-base-content">
                  <%= if kmcg.require_reading do %>
                    {gettext("Reading Required")}
                  <% else %>
                    {gettext("Direct")}
                  <% end %>
                </p>
              </div>
            </div>
          </div>
        </div>
        <div class="card bg-base-100 border border-base-300 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title text-base-content mb-4">
              {gettext("Selected Kana")}
              <span class="badge badge-ghost ml-2">{length(kmcg.selected_kana)}</span>
            </h2>
            <div class="flex flex-wrap gap-2">
              <%= for char <- kmcg.selected_kana do %>
                <div class="badge badge-outline badge-lg text-lg px-3 py-1">
                  {char}
                </div>
              <% end %>
            </div>
          </div>
        </div>
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-base-content mb-4">
              <.icon name="hero-trophy" class="w-5 h-5 mr-2" />
              {gettext("Rankings")}
            </h2>
            <%= if @sessions == [] do %>
              <p class="text-secondary text-center py-8">
                {gettext("No students have played this game yet.")}
              </p>
            <% else %>
              <div class="space-y-2">
                <%= for {session, index} <- Enum.with_index(@sessions, 1) do %>
                  <div class="flex items-center justify-between p-3 sm:p-4 bg-base-200 rounded-lg">
                    <div class="flex items-center gap-3 min-w-0">
                      <span class={[
                        "w-8 h-8 rounded-lg flex items-center justify-center font-bold text-sm shrink-0",
                        index == 1 && "bg-yellow-100 text-yellow-700",
                        index == 2 && "bg-gray-200 text-gray-700",
                        index == 3 && "bg-orange-100 text-orange-700",
                        index > 3 && "bg-base-300 text-secondary"
                      ]}>
                        {index}
                      </span>
                      <% avatar_src =
                        (session.user.profile && session.user.profile.avatar) || session.user.avatar_url %>
                      <%= if avatar_src do %>
                        <div class="avatar shrink-0">
                          <div class="w-8 h-8 rounded-full">
                            <img src={avatar_src} alt="" class="object-cover" />
                          </div>
                        </div>
                      <% else %>
                        <div class="avatar placeholder shrink-0">
                          <div class="bg-primary text-primary-content rounded-full w-8 h-8 flex items-center justify-center">
                            <% initial =
                              if session.user.profile && session.user.profile.display_name,
                                do: String.first(session.user.profile.display_name) |> String.upcase(),
                                else: String.first(session.user.name || session.user.email) |> String.upcase() %>
                            <span class="text-xs">{initial}</span>
                          </div>
                        </div>
                      <% end %>
                      <span class="truncate text-base-content">
                        {display_name(session.user, @current_scope.current_user.id, @current_scope.current_user.type == "admin")}
                      </span>
                    </div>
                    <div class="flex items-center gap-4 shrink-0 ml-2">
                      <div class="text-right">
                        <p class="font-bold text-base-content">{session.score} {gettext("pts")}</p>
                        <p class="text-xs text-secondary">
                          {session.attempts_used}/{session.max_attempts} {gettext("attempts")}
                        </p>
                      </div>
                      <button
                        phx-click="reset_student"
                        phx-value-user_id={session.user_id}
                        data-confirm={gettext("Reset this student's progress? They will lose their points.")}
                        class="btn btn-ghost btn-sm btn-circle text-error"
                        title={gettext("Reset student")}
                      >
                        <.icon name="hero-arrow-path" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
