defmodule MedoruWeb.ClassroomLive.CustomLessonComplete do
  @moduledoc """
  LiveView for showing completion screen after finishing a custom lesson.
  Allows users to select which words and kanji to mark as learned.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms
  alias Medoru.Content
  alias Medoru.Learning

  @impl true
  def mount(%{"id" => classroom_id, "lesson_id" => lesson_id} = params, _session, socket) do
    user = socket.assigns.current_scope.current_user
    practice = params["practice"] == "true"

    # Verify membership
    case Classrooms.get_user_membership(classroom_id, user.id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not a member of this classroom."))
         |> push_navigate(to: ~p"/classrooms")}

      _membership ->
        load_completion(socket, classroom_id, lesson_id, user, practice)
    end
  end

  defp load_completion(socket, classroom_id, lesson_id, user, practice) do
    classroom = Classrooms.get_classroom!(classroom_id)
    lesson = Content.get_custom_lesson_with_words!(lesson_id)

    # Get the completed progress (if any)
    progress = Classrooms.get_custom_lesson_progress(classroom_id, user.id, lesson_id)

    # Calculate points (only show actual earned points, not practice)
    word_count = length(lesson.custom_lesson_words)
    points_earned = if practice, do: 0, else: (progress && progress.points_earned) || 0

    # Get already learned items
    learned_word_ids = Learning.list_learned_word_ids(user.id)
    learned_kanji_ids = Learning.list_learned_kanji_ids(user.id)

    # Get lesson words with their kanji, filtering out already learned
    lesson_words =
      lesson.custom_lesson_words
      |> Enum.map(fn clw ->
        word = clw.word
        # Get kanji for this word that are not already learned
        word_kanjis =
          case word.word_kanjis do
            %Ecto.Association.NotLoaded{} ->
              # Load kanji if not preloaded
              word_with_kanji = Content.get_word_with_kanji!(word.id)
              word_with_kanji.word_kanjis

            wk ->
              wk
          end

        kanji_list =
          word_kanjis
          |> Enum.map(& &1.kanji)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq_by(& &1.id)
          |> Enum.reject(fn k -> k.id in learned_kanji_ids end)

        %{word: word, kanji: kanji_list, already_learned: word.id in learned_word_ids}
      end)
      |> Enum.reject(& &1.already_learned)

    # Extract unique kanji from all words (not already learned)
    all_kanji =
      lesson_words
      |> Enum.flat_map(& &1.kanji)
      |> Enum.uniq_by(& &1.id)

    # Default all items to selected
    selected_word_ids = Enum.map(lesson_words, & &1.word.id)
    selected_kanji_ids = Enum.map(all_kanji, & &1.id)

    {:ok,
     socket
     |> assign(:classroom, classroom)
     |> assign(:lesson, lesson)
     |> assign(:word_count, word_count)
     |> assign(:points_earned, points_earned)
     |> assign(:practice, practice)
     |> assign(:lesson_words, lesson_words)
     |> assign(:all_kanji, all_kanji)
     |> assign(:selected_word_ids, selected_word_ids)
     |> assign(:selected_kanji_ids, selected_kanji_ids)
     |> assign(:marked_as_learned, false)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    title = if socket.assigns[:practice], do: gettext("Practice Complete!"), else: gettext("Lesson Complete!")
    {:noreply, assign(socket, :page_title, title)}
  end

  @impl true
  def handle_event("toggle_word", %{"word_id" => word_id}, socket) do
    word_id = String.trim(word_id)
    selected = socket.assigns.selected_word_ids

    new_selected =
      if word_id in selected do
        List.delete(selected, word_id)
      else
        [word_id | selected]
      end

    {:noreply, assign(socket, :selected_word_ids, new_selected)}
  end

  @impl true
  def handle_event("toggle_kanji", %{"kanji_id" => kanji_id}, socket) do
    kanji_id = String.trim(kanji_id)
    selected = socket.assigns.selected_kanji_ids

    new_selected =
      if kanji_id in selected do
        List.delete(selected, kanji_id)
      else
        [kanji_id | selected]
      end

    {:noreply, assign(socket, :selected_kanji_ids, new_selected)}
  end

  @impl true
  def handle_event("mark_as_learned", _params, socket) do
    user = socket.assigns.current_scope.current_user
    word_ids = socket.assigns.selected_word_ids
    kanji_ids = socket.assigns.selected_kanji_ids

    # Mark selected words as learned
    if word_ids != [] do
      Learning.track_words_learned(user.id, word_ids)
    end

    # Mark selected kanji as learned
    if kanji_ids != [] do
      Learning.track_kanji_learned_batch(user.id, kanji_ids)
    end

    {:noreply,
     socket
     |> assign(:marked_as_learned, true)
     |> put_flash(:info, gettext("Selected items marked as learned!"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto px-4 py-12">
        <div class="card bg-base-100 border border-base-300 shadow-lg">
          <div class="card-body py-12">
            <%!-- Success Icon --%>
            <div class="w-24 h-24 mx-auto bg-success/10 rounded-full flex items-center justify-center mb-6">
              <.icon name="hero-check-circle" class="w-16 h-16 text-success" />
            </div>

            <%!-- Title --%>
            <%= if @practice do %>
              <h1 class="text-3xl font-bold text-base-content mb-2 text-center">{gettext("Practice Complete!")}</h1>
              <p class="text-xl text-secondary mb-6 text-center">{@lesson.title}</p>

              <%!-- Practice Stats --%>
              <div class="flex justify-center gap-8 mb-8">
                <div class="text-center">
                  <div class="text-3xl font-bold text-primary">{@word_count}</div>
                  <div class="text-sm text-secondary">{gettext("Words Reviewed")}</div>
                </div>
              </div>

              <%!-- Practice Message --%>
              <div class="alert alert-info mb-8">
                <.icon name="hero-arrow-path" class="w-5 h-5" />
                <span>{gettext("Practice mode - no points awarded. Review anytime!")}</span>
              </div>
            <% else %>
              <h1 class="text-3xl font-bold text-base-content mb-2 text-center">{gettext("Lesson Complete!")}</h1>
              <p class="text-xl text-secondary mb-6 text-center">{@lesson.title}</p>

              <%!-- Stats --%>
              <div class="flex justify-center gap-8 mb-8">
                <div class="text-center">
                  <div class="text-3xl font-bold text-primary">{@word_count}</div>
                  <div class="text-sm text-secondary">{gettext("Words Learned")}</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold text-primary">+{@points_earned}</div>
                  <div class="text-sm text-secondary">{gettext("Points Earned")}</div>
                </div>
              </div>

              <%!-- Progress Message --%>
              <div class="alert alert-success mb-8">
                <.icon name="hero-trophy" class="w-5 h-5" />
                <span>{gettext("Great job! Keep up the good work!")}</span>
              </div>
            <% end %>

            <%!-- Mark as Learned Section (only if not in practice mode and not already marked) --%>
            <%= if not @practice and not @marked_as_learned do %>
              <div class="border-t border-base-200 pt-8 mb-8">
                <h2 class="text-xl font-semibold text-base-content mb-4 text-center">
                  {gettext("Select items to add to your study list")}
                </h2>
                <p class="text-secondary text-center mb-6">
                  {gettext("Uncheck items you don't want to track for review")}
                </p>

                <form phx-submit="mark_as_learned" class="space-y-6">
                  <%!-- Words Section --%>
                  <%= if @lesson_words != [] do %>
                    <div>
                      <h3 class="text-lg font-medium text-base-content mb-3">
                        <.icon name="hero-book-open" class="w-5 h-5 inline mr-1" />
                        {gettext("Words")} ({length(@lesson_words)})
                      </h3>
                      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                        <%= for item <- @lesson_words do %>
                          <label class="flex items-center gap-3 p-3 bg-base-100 border border-base-200 rounded-lg cursor-pointer hover:bg-base-50">
                            <input
                              type="checkbox"
                              name="word_ids[]"
                              value={item.word.id}
                              checked={item.word.id in @selected_word_ids}
                              phx-click="toggle_word"
                              phx-value-word_id={item.word.id}
                              class="checkbox checkbox-primary"
                            />
                            <div class="flex-1 min-w-0">
                              <div class="font-medium font-jp truncate">{item.word.text}</div>
                              <div class="text-sm text-secondary truncate">{item.word.reading}</div>
                            </div>
                          </label>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <%!-- Kanji Section --%>
                  <%= if @all_kanji != [] do %>
                    <div>
                      <h3 class="text-lg font-medium text-base-content mb-3">
                        <.icon name="hero-pencil-square" class="w-5 h-5 inline mr-1" />
                        {gettext("Kanji")} ({length(@all_kanji)})
                      </h3>
                      <div class="flex flex-wrap gap-2">
                        <%= for kanji <- @all_kanji do %>
                          <label class="flex items-center gap-2 px-3 py-2 bg-base-100 border border-base-200 rounded-lg cursor-pointer hover:bg-base-50">
                            <input
                              type="checkbox"
                              name="kanji_ids[]"
                              value={kanji.id}
                              checked={kanji.id in @selected_kanji_ids}
                              phx-click="toggle_kanji"
                              phx-value-kanji_id={kanji.id}
                              class="checkbox checkbox-primary checkbox-sm"
                            />
                            <span class="text-xl font-jp">{kanji.character}</span>
                            <span class="text-sm text-secondary">
                              {Enum.join(kanji.meanings || [], ", ")}
                            </span>
                          </label>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <%= if @lesson_words == [] and @all_kanji == [] do %>
                    <div class="alert alert-info">
                      <.icon name="hero-information-circle" class="w-5 h-5" />
                      <span>{gettext("All words and kanji from this lesson are already in your study list!")}</span>
                    </div>
                  <% end %>

                  <%= if @lesson_words != [] or @all_kanji != [] do %>
                    <div class="pt-4">
                      <button type="submit" class="btn btn-primary w-full">
                        <.icon name="hero-check" class="w-5 h-5 mr-2" />
                        {gettext("Add selected to study list")}
                      </button>
                    </div>
                  <% end %>
                </form>
              </div>
            <% end %>

            <%!-- Already marked message --%>
            <%= if @marked_as_learned do %>
              <div class="alert alert-success mb-8">
                <.icon name="hero-check-circle" class="w-5 h-5" />
                <span>{gettext("Items added to your study list! They will appear in your daily reviews.")}</span>
              </div>
            <% end %>

            <%!-- Actions --%>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <.link
                navigate={~p"/classrooms/#{@classroom.id}?tab=lessons"}
                class="btn btn-primary"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> {gettext("Back to Lessons")}
              </.link>
              <.link
                navigate={~p"/classrooms/#{@classroom.id}/rankings"}
                class="btn btn-ghost"
              >
                <.icon name="hero-chart-bar" class="w-5 h-5 mr-2" /> {gettext("View Rankings")}
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
