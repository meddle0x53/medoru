defmodule MedoruWeb.ClassroomLive.Rankings do
  @moduledoc """
  LiveView for displaying classroom rankings and leaderboards.
  Students can view:
  - Overall classroom leaderboard
  - Per-test rankings
  - Their own position
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms

  @impl true
  def mount(%{"id" => classroom_id}, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Verify user is a member
    if not Classrooms.is_approved_member?(classroom_id, user.id) do
      {:ok,
       socket
       |> put_flash(:error, gettext("You must be a member to view rankings."))
       |> push_navigate(to: ~p"/classrooms")}
    else
      classroom = Classrooms.get_classroom!(classroom_id)
      my_rank = Classrooms.get_user_classroom_rank(classroom_id, user.id)
      my_points = get_my_points(classroom_id, user.id)

      socket =
        socket
        |> assign(:page_title, "Rankings - #{classroom.name}")
        |> assign(:classroom, classroom)
        |> assign(:current_user, user)
        |> assign(:my_rank, my_rank)
        |> assign(:my_points, my_points)
        |> assign(:active_tab, "overall")

      {:ok, load_leaderboard_data(socket)}
    end
  end

  defp load_leaderboard_data(socket) do
    classroom_id = socket.assigns.classroom.id
    active_tab = socket.assigns.active_tab

    case active_tab do
      "overall" ->
        leaderboard = Classrooms.get_classroom_leaderboard(classroom_id, limit: 50)
        assign(socket, :leaderboard, leaderboard)

      "tests" ->
        # Get available tests for this classroom
        tests = list_classroom_tests(classroom_id)
        selected_test_id = socket.assigns[:selected_test_id] || List.first(tests)[:id]

        test_leaderboard =
          if selected_test_id do
            Classrooms.get_test_leaderboard(classroom_id, selected_test_id, limit: 50)
          else
            []
          end

        my_test_rank =
          if selected_test_id do
            Classrooms.get_user_test_rank(
              classroom_id,
              selected_test_id,
              socket.assigns.current_user.id
            )
          end

        socket
        |> assign(:tests, tests)
        |> assign(:selected_test_id, selected_test_id)
        |> assign(:test_leaderboard, test_leaderboard)
        |> assign(:my_test_rank, my_test_rank)
    end
  end

  defp list_classroom_tests(classroom_id) do
    # Get tests that have attempts in this classroom
    import Ecto.Query

    Medoru.Tests.Test
    |> join(:inner, [t], a in Medoru.Classrooms.ClassroomTestAttempt, on: a.test_id == t.id)
    |> where([t, a], a.classroom_id == ^classroom_id)
    |> select([t, a], %{id: t.id, title: t.title})
    |> distinct([t], t.id)
    |> order_by([t], desc: t.inserted_at)
    |> Medoru.Repo.all()
  end

  defp get_my_points(classroom_id, user_id) do
    import Ecto.Query

    Medoru.Classrooms.ClassroomMembership
    |> where([m], m.classroom_id == ^classroom_id and m.user_id == ^user_id)
    |> select([m], m.points)
    |> Medoru.Repo.one() || 0
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:active_tab, tab)
     |> load_leaderboard_data()}
  end

  @impl true
  def handle_event("select_test", %{"test_id" => test_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_test_id, test_id)
     |> load_leaderboard_data()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-5xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/classrooms/#{@classroom.id}"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Classroom
          </.link>

          <h1 class="text-3xl font-bold text-base-content">{@classroom.name} Rankings</h1>
          <p class="text-secondary mt-1">See how you compare with other students</p>
        </div>

        <%!-- My Stats Card --%>
        <div class="card bg-gradient-to-r from-primary/10 to-secondary/10 border border-primary/20 mb-8">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-4">
                <div class="w-16 h-16 bg-primary/20 rounded-2xl flex items-center justify-center">
                  <.icon name="hero-trophy" class="w-8 h-8 text-primary" />
                </div>
                <div>
                  <p class="text-sm text-secondary">Your Rank</p>
                  <p class="text-3xl font-bold text-base-content">
                    <%= if @my_rank do %>
                      #{@my_rank}
                    <% else %>
                      --
                    <% end %>
                  </p>
                </div>
              </div>

              <div class="text-right">
                <p class="text-sm text-secondary">Your Points</p>
                <p class="text-3xl font-bold text-primary">{@my_points}</p>
              </div>
            </div>
          </div>
        </div>

        <%!-- Tabs --%>
        <div class="border-b border-base-300 mb-6">
          <div class="flex gap-1">
            <.tab_button
              active={@active_tab == "overall"}
              click="change_tab"
              tab="overall"
              label="Overall Ranking"
              icon="hero-chart-bar"
            />
            <.tab_button
              active={@active_tab == "tests"}
              click="change_tab"
              tab="tests"
              label="Test Rankings"
              icon="hero-academic-cap"
            />
          </div>
        </div>

        <%!-- Tab Content --%>
        <div class="min-h-[400px]">
          <%= case @active_tab do %>
            <% "overall" -> %>
              <.overall_leaderboard leaderboard={@leaderboard} current_user={@current_user} />
            <% "tests" -> %>
              <.test_rankings
                tests={@tests}
                selected_test_id={@selected_test_id}
                test_leaderboard={@test_leaderboard}
                my_test_rank={@my_test_rank}
                current_user={@current_user}
              />
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ============================================================================
  # Components
  # ============================================================================

  defp tab_button(assigns) do
    ~H"""
    <button
      phx-click={@click}
      phx-value-tab={@tab}
      class={[
        "px-4 py-3 text-sm font-medium border-b-2 transition-colors flex items-center gap-2",
        @active && "border-primary text-primary",
        !@active && "border-transparent text-secondary hover:text-base-content hover:border-base-300"
      ]}
    >
      <.icon name={@icon} class="w-4 h-4" />
      {@label}
    </button>
    """
  end

  defp overall_leaderboard(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300 shadow-sm">
      <div class="card-body">
        <h2 class="card-title text-base-content mb-4">Overall Leaderboard</h2>

        <%= if @leaderboard == [] do %>
          <div class="text-center py-12 text-secondary">
            <.icon name="hero-trophy" class="w-16 h-16 text-secondary/20 mx-auto mb-4" />
            <p>No rankings yet. Complete tests and lessons to earn points!</p>
          </div>
        <% else %>
          <div class="space-y-2">
            <%= for entry <- @leaderboard do %>
              <.leaderboard_row
                rank={entry.rank}
                user={entry.user}
                points={entry.points}
                is_me={entry.user.id == @current_user.id}
              />
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp test_rankings(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Test Selector --%>
      <%= if @tests == [] do %>
        <div class="card bg-base-100 border border-base-300 shadow-sm p-8 text-center">
          <.icon name="hero-academic-cap" class="w-16 h-16 text-secondary/20 mx-auto mb-4" />
          <h3 class="text-xl font-semibold text-base-content mb-2">No Tests Yet</h3>
          <p class="text-secondary">Tests will appear here once students start taking them.</p>
        </div>
      <% else %>
        <div class="flex gap-2 flex-wrap">
          <%= for test <- @tests do %>
            <button
              phx-click="select_test"
              phx-value-test_id={test.id}
              class={[
                "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
                @selected_test_id == test.id && "bg-primary text-primary-content",
                @selected_test_id != test.id && "bg-base-200 text-base-content hover:bg-base-300"
              ]}
            >
              {test.title}
            </button>
          <% end %>
        </div>

        <%!-- Test Leaderboard --%>
        <%= if @selected_test_id do %>
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body">
              <div class="flex justify-between items-center mb-4">
                <h2 class="card-title text-base-content">Test Rankings</h2>
                <%= if @my_test_rank do %>
                  <span class="badge badge-primary">Your Rank: #{@my_test_rank}</span>
                <% end %>
              </div>

              <%= if @test_leaderboard == [] do %>
                <div class="text-center py-8 text-secondary">
                  <p>No attempts yet. Be the first to take this test!</p>
                </div>
              <% else %>
                <div class="space-y-2">
                  <%= for entry <- @test_leaderboard do %>
                    <.test_leaderboard_row
                      rank={entry.rank}
                      entry={entry}
                      is_me={entry.user.id == @current_user.id}
                    />
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp leaderboard_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-4 p-4 rounded-xl transition-colors",
      @is_me && "bg-primary/10 border border-primary/30",
      !@is_me && "hover:bg-base-200/50"
    ]}>
      <%!-- Rank --%>
      <div class="w-12 text-center">
        <%= cond do %>
          <% @rank == 1 -> %>
            <span class="text-2xl">🥇</span>
          <% @rank == 2 -> %>
            <span class="text-2xl">🥈</span>
          <% @rank == 3 -> %>
            <span class="text-2xl">🥉</span>
          <% true -> %>
            <span class="text-lg font-semibold text-secondary">#{@rank}</span>
        <% end %>
      </div>

      <%!-- User Info --%>
      <div class="flex-1 flex items-center gap-3">
        <div class="w-10 h-10 bg-base-200 rounded-full flex items-center justify-center">
          <.icon name="hero-user" class="w-5 h-5 text-secondary" />
        </div>
        <div>
          <p class="font-medium text-base-content">
            {@user.name || "Anonymous"}
            <%= if @is_me do %>
              <span class="badge badge-primary badge-sm ml-2">You</span>
            <% end %>
          </p>
        </div>
      </div>

      <%!-- Points --%>
      <div class="text-right">
        <p class="text-2xl font-bold text-primary">{@points}</p>
        <p class="text-xs text-secondary">points</p>
      </div>
    </div>
    """
  end

  defp test_leaderboard_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-4 p-4 rounded-xl transition-colors",
      @is_me && "bg-primary/10 border border-primary/30",
      !@is_me && "hover:bg-base-200/50"
    ]}>
      <%!-- Rank --%>
      <div class="w-12 text-center">
        <%= cond do %>
          <% @rank == 1 -> %>
            <span class="text-2xl">🥇</span>
          <% @rank == 2 -> %>
            <span class="text-2xl">🥈</span>
          <% @rank == 3 -> %>
            <span class="text-2xl">🥉</span>
          <% true -> %>
            <span class="text-lg font-semibold text-secondary">#{@rank}</span>
        <% end %>
      </div>

      <%!-- User Info --%>
      <div class="flex-1">
        <p class="font-medium text-base-content">
          {@entry.user.name || "Anonymous"}
          <%= if @is_me do %>
            <span class="badge badge-primary badge-sm ml-2">You</span>
          <% end %>
        </p>
        <%= if @entry.auto_submitted do %>
          <p class="text-xs text-warning">Time ran out</p>
        <% end %>
      </div>

      <%!-- Score Details --%>
      <div class="text-right">
        <p class="text-xl font-bold text-primary">{@entry.points_earned}</p>
        <p class="text-xs text-secondary">{@entry.score}/{@entry.max_score} ({@entry.percentage}%)</p>
      </div>
    </div>
    """
  end
end
