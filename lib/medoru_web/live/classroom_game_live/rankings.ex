defmodule MedoruWeb.ClassroomGameLive.Rankings do
  @moduledoc """
  LiveView for students to view game rankings.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.Components.Helpers, only: [display_name: 3]

  alias Medoru.Classrooms
  alias Medoru.Games
  alias MedoruWeb.PublicAccess

  @impl true
  def mount(%{"classroom_id" => classroom_id, "game_id" => game_id} = params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    return_to = params["return_to"]
    is_anonymous = is_nil(user)

    classroom = Classrooms.get_classroom!(classroom_id)

    has_access =
      if is_anonymous do
        PublicAccess.featured_classroom?(classroom_id)
      else
        is_teacher = classroom.teacher_id == user.id
        membership = Classrooms.get_user_membership(classroom_id, user.id)
        is_approved = membership != nil and membership.status == :approved
        is_teacher or is_approved
      end

    if not has_access do
      redirect_path = if is_anonymous, do: ~p"/auth/google", else: ~p"/classrooms"

      message =
        cond do
          is_anonymous -> gettext("You must sign in to view this page.")
          Classrooms.get_user_membership(classroom_id, user.id) == nil -> gettext("You are not a member of this classroom.")
          true -> gettext("Your membership is pending approval.")
        end

      {:ok,
       socket
       |> put_flash(:error, message)
       |> push_navigate(to: redirect_path)}
    else
      game = Games.get_game_for_play!(game_id)

      if game.classroom_id != classroom_id do
        {:ok,
         socket
         |> put_flash(:error, gettext("Game not found in this classroom."))
         |> push_navigate(to: ~p"/classrooms/#{classroom_id}")}
      else
        if game.status != :published do
          {:ok,
           socket
           |> put_flash(:error, gettext("This game is not available yet."))
           |> push_navigate(to: ~p"/classrooms/#{classroom_id}?tab=games")}
        else
          sessions = Games.list_game_sessions(game.id)

          {:ok,
           socket
           |> assign(:page_title, gettext("%{game_name} - Rankings", game_name: game.name))
           |> assign(:classroom, classroom)
           |> assign(:game, game)
           |> assign(:return_to, return_to)
           |> assign(:sessions, sessions)
           |> assign(:is_anonymous, is_anonymous)}
        end
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto px-4 py-6">
        <%!-- Header --%>
        <div class="mb-6">
          <.link
            navigate={@return_to || ~p"/classrooms/#{@classroom.id}?tab=games"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-3 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Games")}
          </.link>

          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <div>
              <h1 class="text-xl sm:text-2xl font-bold text-base-content">{@game.name}</h1>
              <p class="text-secondary text-sm">{gettext("Rankings")}</p>
            </div>
            <.link
              navigate={~p"/classrooms/#{@classroom.id}/games/#{@game.id}"}
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-play" class="w-4 h-4 mr-1" /> {gettext("Play")}
            </.link>
          </div>
        </div>

        <%!-- Rankings --%>
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
                        (session.user.profile && session.user.profile.avatar) ||
                          session.user.avatar_url %>
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
                                do:
                                  String.first(session.user.profile.display_name) |> String.upcase(),
                                else:
                                  String.first(session.user.name || session.user.email)
                                  |> String.upcase() %>
                            <span class="text-xs">{initial}</span>
                          </div>
                        </div>
                      <% end %>
                      <span class="truncate text-base-content">
                        {display_name(
                          session.user,
                          @current_scope.current_user && @current_scope.current_user.id,
                          @current_scope.current_user && @current_scope.current_user.type == "admin"
                        )}
                      </span>
                    </div>
                    <div class="flex items-center gap-4 shrink-0 ml-2">
                      <div class="text-right">
                        <p class="font-bold text-base-content">{session.score} {gettext("pts")}</p>
                        <p class="text-xs text-secondary">
                          {session.attempts_used}/{session.max_attempts} {gettext("attempts")}
                        </p>
                      </div>
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
