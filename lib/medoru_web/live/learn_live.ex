defmodule MedoruWeb.LearnLive do
  @moduledoc """
  LiveView for interactive lesson learning.
  Users study words one at a time with kanji breakdowns.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content
  alias Medoru.Learning

  @impl true
  def render(assigns),
    do: ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-6">
        <%= if @completed do %>
          <%!-- Completion Screen --%>
          <div class="text-center py-12">
            <div class="w-24 h-24 bg-primary/15 rounded-full flex items-center justify-center mx-auto mb-6">
              <.icon name="hero-check-badge" class="w-12 h-12 text-primary" />
            </div>
            <h1 class="text-3xl font-bold text-base-content mb-3">Lesson Complete!</h1>
            <p class="text-lg text-secondary mb-2">
              You've finished learning <strong>{@lesson.title}</strong>
            </p>
            <p class="text-secondary mb-8">
              You've studied {length(@words)} words
            </p>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <button
                phx-click="finish"
                class="bg-primary hover:bg-primary/90 text-primary-content px-8 py-3 rounded-xl font-medium
                       transition-all shadow-sm hover:shadow-md active:scale-[0.98]"
              >
                Back to Lesson
              </button>
              <.link
                navigate={~p"/lessons?difficulty=#{@lesson.difficulty}"}
                class="px-8 py-3 rounded-xl font-medium text-base-content bg-base-200 hover:bg-base-300
                       transition-colors"
              >
                Browse More Lessons
              </.link>
            </div>
          </div>
        <% else %>
          <%!-- Progress Header --%>
          <div class="mb-6">
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-3">
                <span class="text-sm font-medium text-secondary">
                  Word {@current_index + 1} of {length(@words)}
                </span>
                <span class="text-sm text-secondary/70">
                  {@lesson.title}
                </span>
              </div>
              <button
                phx-click="complete_lesson"
                class="text-sm text-secondary/70 hover:text-primary transition-colors"
              >
                Finish Early
              </button>
            </div>
            <div class="w-full bg-base-200 rounded-full h-2.5">
              <div
                class="bg-primary h-2.5 rounded-full transition-all duration-300"
                style={"width: #{@progress_percentage}%"}
              >
              </div>
            </div>
          </div>

          <%!-- Main Word Card --%>
          <div class="bg-base-100 border border-base-300 rounded-2xl p-8 mb-6 shadow-sm">
            <%!-- Word Display --%>
            <div class="text-center mb-8">
              <div class="text-6xl font-medium text-base-content mb-4">
                {@current_word.text}
              </div>
              <div class="text-2xl text-secondary/80 mb-2">
                {@current_word.reading}
              </div>
              <div class="text-xl text-secondary">
                {@current_word.meaning}
              </div>
            </div>

            <%!-- Kanji Breakdown --%>
            <div class="border-t border-base-200 pt-6 mb-6">
              <h3 class="text-sm font-semibold text-secondary/80 uppercase tracking-wider mb-4">
                Kanji Breakdown
              </h3>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for word_kanji <- @current_word.word_kanjis do %>
                  <div class="bg-base-200/50 rounded-xl p-4">
                    <div class="flex items-start gap-3">
                      <div class="w-14 h-14 bg-base-100 border border-base-300 rounded-xl flex items-center justify-center flex-shrink-0 shadow-sm">
                        <span class="text-2xl font-medium text-base-content">
                          {word_kanji.kanji.character}
                        </span>
                      </div>
                      <div class="flex-1 min-w-0">
                        <%= if word_kanji.kanji_reading do %>
                          <div class="text-sm font-medium text-base-content mb-1">
                            {word_kanji.kanji_reading.reading}
                          </div>
                          <div class="text-xs text-secondary/80 mb-1">
                            {word_kanji.kanji_reading.romaji}
                          </div>
                        <% end %>
                        <div class="text-xs text-secondary/70 line-clamp-2">
                          {Enum.join(word_kanji.kanji.meanings, ", ")}
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Example Words for Each Kanji (if available) --%>
            <%= if length(@current_word.word_kanjis) > 0 do %>
              <div class="border-t border-base-200 pt-6">
                <h3 class="text-sm font-semibold text-secondary/80 uppercase tracking-wider mb-4">
                  Kanji Details
                </h3>
                <div class="space-y-3">
                  <%= for word_kanji <- @current_word.word_kanjis do %>
                    <div class="flex items-center justify-between py-2.5 px-4 bg-base-200/50 rounded-xl">
                      <div class="flex items-center gap-3">
                        <span class="text-xl font-medium text-base-content">
                          {word_kanji.kanji.character}
                        </span>
                        <div>
                          <%= if word_kanji.kanji_reading do %>
                            <div class="text-sm text-secondary">
                              {word_kanji.kanji_reading.reading} · {word_kanji.kanji_reading.romaji}
                            </div>
                            <div class="text-xs text-secondary/70">
                              {word_kanji.kanji_reading.reading_type} reading
                            </div>
                          <% else %>
                            <div class="text-sm text-secondary/70">
                              Reading not available
                            </div>
                          <% end %>
                        </div>
                      </div>
                      <.link
                        navigate={~p"/kanji/#{word_kanji.kanji.id}"}
                        class="text-sm text-primary hover:text-primary/80 transition-colors"
                      >
                        View Kanji →
                      </.link>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Navigation Buttons --%>
          <div class="flex items-center justify-between gap-4">
            <button
              phx-click="previous"
              disabled={@current_index == 0}
              class="flex items-center gap-2 px-6 py-3 rounded-xl font-medium
                     disabled:opacity-50 disabled:cursor-not-allowed
                     bg-base-200 text-base-content hover:bg-base-300 transition-colors"
            >
              <.icon name="hero-arrow-left" class="w-5 h-5" /> Previous
            </button>

            <%= if @current_scope && @current_scope.current_user do %>
              <button
                phx-click="mark_learned"
                class="flex items-center gap-2 px-6 py-3 rounded-xl font-medium
                       bg-primary/20 text-primary/80 hover:bg-primary/30 transition-colors"
              >
                <.icon name="hero-check" class="w-5 h-5" /> Mark Learned
              </button>
            <% end %>

            <button
              phx-click="next"
              class="flex items-center gap-2 px-6 py-3 rounded-xl font-medium
                     bg-primary text-white hover:bg-primary/80 transition-colors"
            >
              <%= if @current_index + 1 >= length(@words) do %>
                Finish <.icon name="hero-check-circle" class="w-5 h-5" />
              <% else %>
                Next <.icon name="hero-arrow-right" class="w-5 h-5" />
              <% end %>
            </button>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Learn")
     |> assign(:current_index, 0)
     |> assign(:lesson, nil)
     |> assign(:words, [])
     |> assign(:current_word, nil)
     |> assign(:progress, nil)
     |> assign(:lesson_progress, nil)
     |> assign(:completed, false)}
  end

  @impl true
  def handle_params(%{"lesson_id" => lesson_id}, _url, socket) do
    lesson = Content.get_lesson_for_learning!(lesson_id)
    words = Enum.map(lesson.lesson_words, & &1.word)

    current_word = List.first(words)

    # Load or create lesson progress if user is authenticated
    lesson_progress =
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        user_id = socket.assigns.current_scope.current_user.id
        # Start lesson if not already started
        {:ok, lp} = Learning.start_lesson(user_id, lesson_id)
        lp
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:lesson, lesson)
     |> assign(:words, words)
     |> assign(:current_word, current_word)
     |> assign(:lesson_progress, lesson_progress)
     |> assign(:page_title, "Learn: #{lesson.title}")
     |> assign_progress_percentage()}
  end

  @impl true
  def handle_event("next", _params, socket) do
    new_index = socket.assigns.current_index + 1
    words = socket.assigns.words

    if new_index < length(words) do
      current_word = Enum.at(words, new_index)

      # Track word as learned if user is authenticated
      if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
        user_id = socket.assigns.current_scope.current_user.id
        Learning.track_word_learned(user_id, current_word.id)
      end

      {:noreply,
       socket
       |> assign(:current_index, new_index)
       |> assign(:current_word, current_word)
       |> assign_progress_percentage()}
    else
      # Complete the lesson
      {:noreply, complete_lesson(socket)}
    end
  end

  @impl true
  def handle_event("previous", _params, socket) do
    new_index = max(0, socket.assigns.current_index - 1)
    words = socket.assigns.words
    current_word = Enum.at(words, new_index)

    {:noreply,
     socket
     |> assign(:current_index, new_index)
     |> assign(:current_word, current_word)
     |> assign_progress_percentage()}
  end

  @impl true
  def handle_event("mark_learned", _params, socket) do
    if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
      user_id = socket.assigns.current_scope.current_user.id
      word = socket.assigns.current_word

      # Track word as learned
      Learning.track_word_learned(user_id, word.id)

      # Check if any kanji from this word should be auto-learned
      # (when all words containing that kanji are learned)
      Enum.each(word.word_kanjis, fn wk ->
        Learning.check_and_auto_learn_kanji(user_id, wk.kanji_id)
      end)

      # Move to next word automatically
      send(self(), :auto_advance)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("complete_lesson", _params, socket) do
    {:noreply, complete_lesson(socket)}
  end

  @impl true
  def handle_event("finish", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/lessons/#{socket.assigns.lesson.id}")}
  end

  @impl true
  def handle_info(:auto_advance, socket) do
    # Small delay before auto-advancing
    Process.send_after(self(), :do_advance, 500)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:do_advance, socket) do
    handle_event("next", %{}, socket)
  end

  defp assign_progress_percentage(socket) do
    words = socket.assigns.words
    current_index = socket.assigns.current_index

    percentage =
      if length(words) > 0 do
        trunc(current_index / length(words) * 100)
      else
        0
      end

    # Update lesson progress in database
    if socket.assigns.lesson_progress do
      user_id = socket.assigns.current_scope.current_user.id
      lesson_id = socket.assigns.lesson.id
      Learning.update_lesson_progress(user_id, lesson_id, percentage)
    end

    assign(socket, :progress_percentage, percentage)
  end

  defp complete_lesson(socket) do
    lesson = socket.assigns.lesson

    # Complete the lesson if user is authenticated
    if socket.assigns.current_scope && socket.assigns.current_scope.current_user do
      user_id = socket.assigns.current_scope.current_user.id
      Learning.complete_lesson(user_id, lesson.id)
    end

    socket
    |> assign(:completed, true)
    |> assign(:progress_percentage, 100)
    |> assign(:page_title, "Lesson Complete!")
  end

  @doc """
  Returns mastery label for a given level.
  """
  def mastery_label(level) do
    case level do
      0 -> "New"
      1 -> "Learning"
      2 -> "Learning+"
      3 -> "Advanced"
      4 -> "Mastered"
      _ -> "Unknown"
    end
  end

  @doc """
  Returns color class for mastery level.
  """
  def mastery_color(level) do
    case level do
      0 -> "bg-base-200 text-secondary"
      1 -> "bg-yellow-100 text-yellow-700"
      2 -> "bg-orange-100 text-orange-700"
      3 -> "bg-accent/20 text-accent/80"
      4 -> "bg-primary/20 text-primary/80"
      _ -> "bg-base-200 text-secondary"
    end
  end
end
