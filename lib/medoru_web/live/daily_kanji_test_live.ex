defmodule MedoruWeb.DailyKanjiTestLive do
  @moduledoc """
  LiveView for the daily kanji writing challenge.
  Presents 10 learned kanji one by one for stroke practice.
  """
  use MedoruWeb, :live_view

  alias Medoru.Learning
  alias Medoru.Repo
  alias Medoru.Learning.UserProgress
  import Ecto.Query
  # alias Medoru.Content  # unused, kept for reference

  @kanji_count 15
  @xp_per_kanji 30
  @max_wrong_strokes 3

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Header --%>
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Daily Kanji Challenge")}</h1>
          <p class="text-secondary mt-1">
            {gettext("Practice writing %{count} kanji. 10 are your least-known, 5 are random. Each kanji is worth 30 XP if you keep wrong strokes under 4.", count: @kanji_count)}
          </p>
        </div>

        <%= if @finished do %>
          <%!-- Results or Already Completed --%>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body text-center py-12">
              <%= if @already_completed do %>
                <.icon name="hero-check-circle" class="w-16 h-16 text-success mx-auto mb-4" />
                <h2 class="text-2xl font-bold text-base-content mb-2">
                  {gettext("Already Completed!")}
                </h2>
                <p class="text-secondary mb-6">
                  {gettext("You have already completed today's kanji challenge.")}
                </p>
              <% else %>
                <.icon name="hero-trophy" class="w-16 h-16 text-warning mx-auto mb-4" />
                <h2 class="text-2xl font-bold text-base-content mb-2">
                  {gettext("Challenge Complete!")}
                </h2>
                <p class="text-secondary mb-6">
                  {@correct_count} / {@kanji_count} {gettext("kanji written correctly")}
                </p>

                <div class="bg-base-200 rounded-xl p-4 mb-6 max-w-sm mx-auto">
                  <div class="flex justify-between text-sm mb-2">
                    <span class="text-secondary">{gettext("Base XP")}</span>
                    <span class="font-medium">{@base_xp}</span>
                  </div>
                  <%= if @penalty_xp > 0 do %>
                    <div class="flex justify-between text-sm text-error mb-2">
                      <span>{gettext("Penalties")}</span>
                      <span>-{@penalty_xp}</span>
                    </div>
                  <% end %>
                  <div class="border-t border-base-300 pt-2 flex justify-between font-bold">
                    <span>{gettext("Total XP")}</span>
                    <span class={if(@penalty_xp > 0, do: "text-error", else: "text-success")}>
                      {@total_xp}
                    </span>
                  </div>
                </div>
              <% end %>

              <div class="flex flex-col sm:flex-row justify-center gap-3">
                <.link navigate={~p"/daily-challenges"} class="btn btn-primary">
                  <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> {gettext("Back to Challenges")}
                </.link>
                <.link navigate={~p"/dashboard"} class="btn btn-outline">
                  <.icon name="hero-home" class="w-4 h-4 mr-2" /> {gettext("Dashboard")}
                </.link>
              </div>
            </div>
          </div>
        <% else %>
          <%!-- Progress --%>
          <div class="flex items-center gap-2 mb-4">
            <%= for i <- 1..@kanji_count do %>
              <div class={[
                "h-2 flex-1 rounded-full",
                cond do
                  i < @current_index -> "bg-success"
                  i == @current_index -> "bg-primary"
                  true -> "bg-base-300"
                end
              ]}>
              </div>
            <% end %>
          </div>

          <div class="flex items-center justify-between mb-4">
            <span class="text-sm text-secondary">
              {gettext("Kanji %{current} of %{total}", current: @current_index, total: @kanji_count)}
            </span>
            <.link navigate={~p"/daily-challenges"} class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> {gettext("Back")}
            </.link>
          </div>

          <%!-- Current Kanji Writing --%>
          <%= if @current_kanji do %>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <div class="text-center mb-4">
                  <p class="text-sm text-secondary mb-1">
                    {gettext("Write the kanji for")}
                  </p>
                  <h3 class="text-xl font-bold text-base-content">
                    {@current_kanji.meanings |> Enum.take(2) |> Enum.join(", ")}
                  </h3>
                  <p class="text-sm text-secondary mt-1">
                    <span class="font-medium">{gettext("On")}:</span> {first_reading(@current_kanji, :on)} •
                    <span class="font-medium">{gettext("Kun")}:</span> {first_reading(@current_kanji, :kun)} •
                    {@current_kanji.stroke_count} {gettext("strokes")}
                  </p>
                </div>

                <%!-- Writing Component --%>
                <div
                  id={"daily-kanji-writing-" <> @current_kanji.id}
                  phx-hook="KanjiWriting"
                >
                  <div data-stroke-data={Jason.encode!((@current_kanji.stroke_data || %{})["strokes"] || [])} class="hidden"></div>

                  <div class="flex justify-center mb-4">
                    <div
                      id={"daily-writing-canvas-" <> @current_kanji.id}
                      class="bg-base-100 border-2 border-base-300 rounded-xl overflow-hidden writing-canvas-container relative"
                      style="width: min(300px, 80vw); height: min(300px, 80vw); max-width: 300px; max-height: 300px;"
                      phx-update="ignore"
                    >
                    </div>
                  </div>

                  <div class="flex flex-col sm:flex-row justify-center gap-3">
                    <button
                      type="button"
                      data-action="clear"
                      class="w-full sm:w-auto px-4 py-3 bg-base-200 hover:bg-base-300 rounded-lg text-secondary transition-colors flex items-center justify-center gap-2"
                    >
                      <.icon name="hero-trash" class="w-5 h-5" /> {gettext("Clear")}
                    </button>
                    <button
                      type="button"
                      data-action="hint"
                      class="w-full sm:w-auto px-4 py-3 bg-info/20 hover:bg-info/30 text-info rounded-lg transition-colors flex items-center justify-center gap-2"
                    >
                      <.icon name="hero-light-bulb" class="w-5 h-5" /> {gettext("Hint")}
                    </button>
                    <button
                      type="button"
                      data-action="submit"
                      class="w-full sm:w-auto px-6 py-3 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors flex items-center justify-center gap-2"
                    >
                      <.icon name="hero-check" class="w-5 h-5" /> {gettext("Submit")}
                    </button>
                  </div>
                </div>

                <p class="text-center text-sm text-secondary mt-4">
                  {gettext("Draw the kanji stroke by stroke. Wrong strokes:")}
                  <span id="kanji-wrong-stroke-count" class="font-bold text-base-content">
                    {@current_wrong_strokes}
                  </span>
                </p>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    if Learning.daily_challenge_completed?(user.id, "daily_kanji") do
      {:ok,
       socket
       |> assign(:page_title, gettext("Daily Kanji Challenge"))
       |> assign(:finished, true)
       |> assign(:already_completed, true)
       |> assign(:kanji_count, @kanji_count)
       |> assign(:correct_count, 0)
       |> assign(:base_xp, 0)
       |> assign(:penalty_xp, 0)
       |> assign(:total_xp, 0)
       |> assign(:too_many_wrong_strokes, false)}
    else
      kanji_list = Learning.list_learned_kanji_for_daily_test(user.id)

      if length(kanji_list) < @kanji_count do
        {:ok,
         socket
         |> assign(:page_title, gettext("Daily Kanji Challenge"))
         |> put_flash(:error, gettext("Not enough learned kanji with stroke data. Learn at least %{count} kanji first!", count: @kanji_count))
         |> assign(:finished, true)
         |> assign(:already_completed, false)
         |> assign(:kanji_count, @kanji_count)
         |> assign(:correct_count, 0)
         |> assign(:base_xp, 0)
         |> assign(:penalty_xp, 0)
         |> assign(:total_xp, 0)
         |> assign(:too_many_wrong_strokes, false)
         |> assign(:current_index, 1)
         |> assign(:current_kanji, nil)
         |> assign(:current_wrong_strokes, 0)
         |> assign(:results, [])}
      else
        selected_kanji = Enum.take_random(kanji_list, @kanji_count)

        {:ok,
         socket
         |> assign(:page_title, gettext("Daily Kanji Challenge"))
         |> assign(:finished, false)
         |> assign(:already_completed, false)
         |> assign(:kanji_count, @kanji_count)
         |> assign(:kanji_list, selected_kanji)
         |> assign(:current_index, 1)
         |> assign(:current_kanji, hd(selected_kanji))
         |> assign(:current_wrong_strokes, 0)
         |> assign(:results, [])
         |> assign(:correct_count, 0)
         |> assign(:base_xp, 0)
         |> assign(:total_xp, 0)
         |> assign(:too_many_wrong_strokes, false)}
      end
    end
  end

  @impl true
  def handle_event("kanji_complete", params, socket) do
    wrong_strokes = parse_wrong_strokes(params)
    proceed_to_next_kanji(socket, true, wrong_strokes)
  end

  @impl true
  def handle_event("submit_writing", params, socket) do
    completed = parse_boolean(params["completed"], false)
    wrong_strokes = parse_wrong_strokes(params)
    proceed_to_next_kanji(socket, completed, wrong_strokes)
  end

  @impl true
  def handle_event("wrong_stroke", params, socket) do
    count = params["count"] || 0
    {:noreply, assign(socket, :current_wrong_strokes, count)}
  end

  defp parse_wrong_strokes(%{"wrong_strokes" => wrong_strokes}) when is_integer(wrong_strokes), do: wrong_strokes
  defp parse_wrong_strokes(%{"wrong_strokes" => wrong_strokes}) when is_binary(wrong_strokes) do
    case Integer.parse(wrong_strokes) do
      {n, _} -> n
      :error -> 0
    end
  end
  defp parse_wrong_strokes(_), do: 0

  defp parse_boolean(true, _default), do: true
  defp parse_boolean("true", _default), do: true
  defp parse_boolean(false, _default), do: false
  defp parse_boolean("false", _default), do: false
  defp parse_boolean(nil, default), do: default
  defp parse_boolean(_, default), do: default

  defp proceed_to_next_kanji(socket, completed, wrong_strokes) do
    current_kanji = socket.assigns.current_kanji
    current_index = socket.assigns.current_index
    user = socket.assigns.current_scope.current_user

    # Update known_score for this kanji based on performance
    update_known_score(user.id, current_kanji.id, completed)

    results = [{current_kanji.id, completed, wrong_strokes} | socket.assigns.results]

    correct_count = if completed, do: socket.assigns.correct_count + 1, else: socket.assigns.correct_count

    if current_index >= @kanji_count do
      # Finished - calculate XP per kanji (<4 wrong strokes = 30 XP, 4+ = 0 XP)
      max_possible_xp = @kanji_count * @xp_per_kanji

      total_xp =
        results
        |> Enum.filter(fn {_, completed, _} -> completed end)
        |> Enum.reduce(0, fn {_, _, ws}, acc ->
          if ws <= @max_wrong_strokes, do: acc + @xp_per_kanji, else: acc
        end)

      penalty_xp = max_possible_xp - total_xp

      user = socket.assigns.current_scope.current_user

      # Award XP and record completion
      metadata_results =
        Enum.map(results, fn {kanji_id, completed, wrong_strokes} ->
          %{"kanji_id" => kanji_id, "completed" => completed, "wrong_strokes" => wrong_strokes}
        end)

      _ =
        Learning.complete_daily_challenge(user.id, "daily_kanji", total_xp,
          score: correct_count,
          metadata: %{"results" => metadata_results}
        )

      too_many_wrong = penalty_xp > 0

      {:noreply,
       socket
       |> assign(:finished, true)
       |> assign(:results, results)
       |> assign(:correct_count, correct_count)
       |> assign(:base_xp, max_possible_xp)
       |> assign(:penalty_xp, penalty_xp)
       |> assign(:total_xp, total_xp)
       |> assign(:too_many_wrong_strokes, too_many_wrong)}
    else
      next_kanji = Enum.at(socket.assigns.kanji_list, current_index)

      {:noreply,
       socket
       |> assign(:current_index, current_index + 1)
       |> assign(:current_kanji, next_kanji)
       |> assign(:current_wrong_strokes, 0)
       |> assign(:results, results)
       |> assign(:correct_count, correct_count)}
    end
  end

  defp update_known_score(user_id, kanji_id, completed) do
    progress =
      UserProgress
      |> where([up], up.user_id == ^user_id and up.kanji_id == ^kanji_id)
      |> Repo.one()

    if progress do
      new_score =
        if completed do
          progress.known_score + 1
        else
          max(progress.known_score - 1, 1)
        end

      progress
      |> Ecto.Changeset.change(known_score: new_score)
      |> Repo.update()
    end
  end

  defp first_reading(%{kanji_readings: %Ecto.Association.NotLoaded{}}, _type), do: "—"

  defp first_reading(kanji, type) do
    case Enum.find(kanji.kanji_readings || [], fn r -> r.reading_type == type end) do
      nil -> "—"
      reading -> reading.reading
    end
  end
end
