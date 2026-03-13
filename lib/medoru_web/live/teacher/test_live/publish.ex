defmodule MedoruWeb.Teacher.TestLive.Publish do
  @moduledoc """
  LiveView for publishing a test to classrooms.

  Teachers can:
  - See all their classrooms
  - Select which classrooms to publish to
  - Set due dates and max attempts per classroom
  - Unpublish from classrooms
  - View publish status
  """
  use MedoruWeb, :live_view

  alias Medoru.Tests
  alias Medoru.Classrooms

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.current_user
    test = Tests.get_test!(id)

    # Verify ownership
    if not Tests.is_test_owner?(test, user.id) do
      {:ok,
       socket
       |> put_flash(:error, "You can only publish your own tests.")
       |> push_navigate(to: ~p"/teacher/tests")}
    else
      # Only allow publishing tests that are ready
      if test.setup_state not in ["ready", "published"] do
        {:ok,
         socket
         |> put_flash(:error, "Test must be marked as ready before publishing.")
         |> push_navigate(to: ~p"/teacher/tests/#{test.id}")}
      else
        socket = load_publish_data(socket, test, user.id)
        {:ok, socket}
      end
    end
  end

  defp load_publish_data(socket, test, teacher_id) do
    # Get publish status for all teacher's classrooms
    publish_status = Classrooms.get_test_publish_status(test.id, teacher_id)

    # Get actual classroom test records for published/unpublished
    classroom_tests = Classrooms.list_test_classrooms(test.id, status: nil)

    # Build a map of classroom_id => classroom_test for easy lookup
    classroom_tests_map =
      Enum.reduce(classroom_tests, %{}, fn ct, acc ->
        Map.put(acc, ct.classroom_id, ct)
      end)

    # Get classrooms grouped by publish status
    {published, unpublished, not_published} =
      Enum.reduce(publish_status, {[], [], []}, fn {classroom_id, data},
                                                   {published, unpublished, not_published} ->
        case data.status do
          :active ->
            ct = Map.get(classroom_tests_map, classroom_id)
            {[{classroom_id, data.classroom, ct} | published], unpublished, not_published}

          :unpublished ->
            ct = Map.get(classroom_tests_map, classroom_id)
            {published, [{classroom_id, data.classroom, ct} | unpublished], not_published}

          :not_published ->
            {published, unpublished, [{classroom_id, data.classroom} | not_published]}

          _ ->
            {published, unpublished, not_published}
        end
      end)

    socket
    |> assign(:page_title, "Publish Test - #{test.title}")
    |> assign(:test, test)
    |> assign(:classroom_tests_map, classroom_tests_map)
    |> assign(:published, Enum.reverse(published))
    |> assign(:unpublished, Enum.reverse(unpublished))
    |> assign(:not_published, Enum.reverse(not_published))
    |> assign(:selected_classrooms, [])
    |> assign(:due_date, nil)
    |> assign(:max_attempts, nil)
  end

  @impl true
  def handle_event("toggle_classroom", %{"classroom_id" => classroom_id}, socket) do
    classroom_id =
      case Ecto.UUID.cast(classroom_id) do
        {:ok, id} -> id
        :error -> classroom_id
      end

    selected = socket.assigns.selected_classrooms

    new_selected =
      if classroom_id in selected do
        List.delete(selected, classroom_id)
      else
        [classroom_id | selected]
      end

    {:noreply, assign(socket, :selected_classrooms, new_selected)}
  end

  @impl true
  def handle_event("update_due_date", %{"value" => value}, socket) do
    due_date =
      case value do
        "" ->
          nil

        date_string ->
          case DateTime.from_iso8601(date_string <> ":00Z") do
            {:ok, dt, _} -> dt
            _ -> nil
          end
      end

    {:noreply, assign(socket, :due_date, due_date)}
  end

  @impl true
  def handle_event("update_max_attempts", %{"value" => value}, socket) do
    max_attempts =
      case Integer.parse(value) do
        {n, _} when n >= 1 and n <= 10 -> n
        _ -> nil
      end

    {:noreply, assign(socket, :max_attempts, max_attempts)}
  end

  @impl true
  def handle_event("publish_to_selected", _, socket) do
    test = socket.assigns.test
    teacher_id = socket.assigns.current_scope.current_user.id
    selected = socket.assigns.selected_classrooms

    if selected == [] do
      {:noreply, put_flash(socket, :error, "Please select at least one classroom.")}
    else
      attrs = %{
        due_date: socket.assigns.due_date,
        max_attempts: socket.assigns.max_attempts
      }

      # Publish to each selected classroom
      results =
        Enum.map(selected, fn classroom_id ->
          Classrooms.publish_test_to_classroom(classroom_id, test.id, teacher_id, attrs)
        end)

      # Check results
      {successes, failures} =
        Enum.split_with(results, fn
          {:ok, _} -> true
          {:error, _} -> false
        end)

      socket =
        case {successes, failures} do
          {[], [_ | _]} ->
            put_flash(socket, :error, "Failed to publish test to selected classrooms.")

          {[_ | _], []} ->
            # Update test status to published
            Tests.publish_teacher_test(test)

            socket
            |> put_flash(:info, "Test published to #{length(successes)} classroom(s)!")
            |> load_publish_data(test, teacher_id)
            |> assign(:selected_classrooms, [])

          {_, _} ->
            Tests.publish_teacher_test(test)

            socket
            |> put_flash(
              :warning,
              "Published to #{length(successes)} classroom(s), but #{length(failures)} failed."
            )
            |> load_publish_data(test, teacher_id)
            |> assign(:selected_classrooms, [])
        end

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unpublish", %{"classroom_id" => classroom_id}, socket) do
    test = socket.assigns.test
    teacher_id = socket.assigns.current_scope.current_user.id

    classroom_test = Classrooms.get_classroom_test(classroom_id, test.id)

    case classroom_test do
      nil ->
        {:noreply, put_flash(socket, :error, "Test not found in classroom.")}

      classroom_test ->
        case Classrooms.unpublish_test_from_classroom(classroom_test, teacher_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Test unpublished from classroom.")
             |> load_publish_data(test, teacher_id)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to unpublish test.")}
        end
    end
  end

  @impl true
  def handle_event("republish", %{"classroom_id" => classroom_id}, socket) do
    test = socket.assigns.test
    teacher_id = socket.assigns.current_scope.current_user.id

    classroom_test = Classrooms.get_classroom_test(classroom_id, test.id)

    case classroom_test do
      nil ->
        {:noreply, put_flash(socket, :error, "Test not found in classroom.")}

      classroom_test ->
        case Classrooms.republish_test_to_classroom(classroom_test, teacher_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Test republished to classroom.")
             |> load_publish_data(test, teacher_id)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to republish test.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/tests/#{@test.id}"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Test
          </.link>

          <div class="flex items-center gap-3 mb-2">
            <h1 class="text-3xl font-bold text-base-content">Publish Test</h1>
            <span class="badge badge-lg badge-primary">{@test.title}</span>
          </div>
          <p class="text-secondary">
            Choose which classrooms can access this test.
          </p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Main Content - Classroom Selection --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- Not Published Section --%>
            <%= if @not_published != [] do %>
              <div class="card bg-base-100 border border-base-300 shadow-sm">
                <div class="card-body">
                  <h2 class="card-title text-base-content mb-4">
                    <.icon name="hero-plus-circle" class="w-5 h-5 text-primary" />
                    Available Classrooms
                  </h2>
                  <p class="text-sm text-secondary mb-4">
                    Select classrooms to publish this test to:
                  </p>

                  <div class="space-y-2 mb-6">
                    <%= for {classroom_id, classroom} <- @not_published do %>
                      <label class="flex items-center gap-3 p-3 bg-base-200 rounded-lg cursor-pointer hover:bg-base-300 transition-colors">
                        <input
                          type="checkbox"
                          phx-click="toggle_classroom"
                          phx-value-classroom_id={classroom_id}
                          checked={classroom_id in @selected_classrooms}
                          class="checkbox checkbox-primary"
                        />
                        <div class="flex-1">
                          <p class="font-medium text-base-content">{classroom.name}</p>
                          <p class="text-sm text-secondary">Invite code: {classroom.invite_code}</p>
                        </div>
                        <.icon name="hero-users" class="w-5 h-5 text-secondary" />
                      </label>
                    <% end %>
                  </div>

                  <%= if @selected_classrooms != [] do %>
                    <div class="border-t border-base-300 pt-4">
                      <h3 class="font-medium text-base-content mb-3">Publishing Options</h3>

                      <div class="grid grid-cols-2 gap-4 mb-4">
                        <div>
                          <label class="label">
                            <span class="label-text">Due Date (optional)</span>
                          </label>
                          <input
                            type="datetime-local"
                            phx-change="update_due_date"
                            class="input input-bordered w-full"
                          />
                        </div>
                        <div>
                          <label class="label">
                            <span class="label-text">Max Attempts (optional)</span>
                          </label>
                          <input
                            type="number"
                            min="1"
                            max="10"
                            placeholder="Unlimited"
                            phx-change="update_max_attempts"
                            class="input input-bordered w-full"
                          />
                        </div>
                      </div>

                      <button phx-click="publish_to_selected" class="btn btn-primary btn-block">
                        <.icon name="hero-rocket-launch" class="w-5 h-5 mr-2" />
                        Publish to {length(@selected_classrooms)} Classroom{if length(
                                                                                 @selected_classrooms
                                                                               ) != 1, do: "s"}
                      </button>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%!-- Published Section --%>
            <%= if @published != [] do %>
              <div class="card bg-base-100 border border-base-300 shadow-sm">
                <div class="card-body">
                  <h2 class="card-title text-base-content mb-4">
                    <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
                    Published Classrooms
                  </h2>

                  <div class="space-y-3">
                    <%= for {classroom_id, classroom, classroom_test} <- @published do %>
                      <div class="flex items-center justify-between p-4 bg-success/10 border border-success/20 rounded-lg">
                        <div>
                          <p class="font-medium text-base-content">{classroom.name}</p>
                          <div class="flex gap-4 text-sm text-secondary mt-1">
                            <%= if classroom_test && classroom_test.due_date do %>
                              <span class="flex items-center gap-1">
                                <.icon name="hero-calendar" class="w-4 h-4" />
                                Due: {format_datetime(classroom_test.due_date)}
                              </span>
                            <% end %>
                            <%= if classroom_test && classroom_test.max_attempts do %>
                              <span class="flex items-center gap-1">
                                <.icon name="hero-arrow-path" class="w-4 h-4" />
                                {classroom_test.max_attempts} attempt{if classroom_test.max_attempts !=
                                                                           1,
                                                                         do: "s"}
                              </span>
                            <% end %>
                          </div>
                        </div>
                        <button
                          phx-click="unpublish"
                          phx-value-classroom_id={classroom_id}
                          data-confirm="Unpublish this test from {classroom.name}?"
                          class="btn btn-ghost btn-sm text-error"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4 mr-1" /> Unpublish
                        </button>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Unpublished Section (can republish) --%>
            <%= if @unpublished != [] do %>
              <div class="card bg-base-100 border border-base-300 shadow-sm">
                <div class="card-body">
                  <h2 class="card-title text-base-content mb-4">
                    <.icon name="hero-x-circle" class="w-5 h-5 text-warning" /> Previously Unpublished
                  </h2>

                  <div class="space-y-3">
                    <%= for {classroom_id, classroom, _classroom_test} <- @unpublished do %>
                      <div class="flex items-center justify-between p-4 bg-warning/10 border border-warning/20 rounded-lg">
                        <div>
                          <p class="font-medium text-base-content">{classroom.name}</p>
                          <p class="text-sm text-secondary">Previously published</p>
                        </div>
                        <button
                          phx-click="republish"
                          phx-value-classroom_id={classroom_id}
                          class="btn btn-success btn-sm"
                        >
                          <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> Republish
                        </button>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- No Classrooms Message --%>
            <%= if @not_published == [] and @published == [] and @unpublished == [] do %>
              <div class="card bg-base-100 border border-base-300">
                <div class="card-body text-center py-12">
                  <.icon
                    name="hero-academic-cap"
                    class="w-16 h-16 mx-auto mb-4 text-secondary opacity-50"
                  />
                  <h3 class="text-lg font-medium text-base-content mb-2">No Classrooms Yet</h3>
                  <p class="text-secondary mb-6">
                    You need to create a classroom before you can publish tests.
                  </p>
                  <.link navigate={~p"/teacher/classrooms/new"} class="btn btn-primary">
                    <.icon name="hero-plus" class="w-4 h-4 mr-2" /> Create Classroom
                  </.link>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Sidebar --%>
          <div class="space-y-6">
            <%!-- Test Info --%>
            <div class="card bg-base-100 border border-base-300 shadow-sm">
              <div class="card-body">
                <h3 class="card-title text-base text-base-content mb-4">Test Summary</h3>
                <div class="space-y-3">
                  <div class="flex justify-between text-sm">
                    <span class="text-secondary">Steps:</span>
                    <span class="font-medium">{@test.total_points} points</span>
                  </div>
                  <div class="flex justify-between text-sm">
                    <span class="text-secondary">Time Limit:</span>
                    <span class="font-medium">
                      <%= if @test.time_limit_seconds do %>
                        {format_duration(@test.time_limit_seconds)}
                      <% else %>
                        Unlimited
                      <% end %>
                    </span>
                  </div>
                  <div class="flex justify-between text-sm">
                    <span class="text-secondary">Status:</span>
                    <span class="badge badge-sm badge-success">Ready</span>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Publishing Tips --%>
            <div class="card bg-info/10 border border-info/20">
              <div class="card-body">
                <h3 class="card-title text-info text-base">
                  <.icon name="hero-light-bulb" class="w-5 h-5" /> Tips
                </h3>
                <ul class="text-sm text-base-content space-y-2 mt-2">
                  <li class="flex gap-2">
                    <.icon name="hero-check" class="w-4 h-4 text-info flex-shrink-0 mt-0.5" />
                    Students will see the test in their classroom
                  </li>
                  <li class="flex gap-2">
                    <.icon name="hero-check" class="w-4 h-4 text-info flex-shrink-0 mt-0.5" />
                    Due dates help students prioritize
                  </li>
                  <li class="flex gap-2">
                    <.icon name="hero-check" class="w-4 h-4 text-info flex-shrink-0 mt-0.5" />
                    Max attempts prevent excessive retakes
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp format_duration(seconds) when seconds < 60 do
    "#{seconds}s"
  end

  defp format_duration(seconds) when seconds < 3600 do
    "#{div(seconds, 60)}m"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    mins = rem(seconds, 3600) |> div(60)
    "#{hours}h #{mins}m"
  end
end
