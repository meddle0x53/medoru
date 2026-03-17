defmodule MedoruWeb.Teacher.CustomLessonLive.Edit do
  @moduledoc """
  LiveView for editing a custom lesson - adding/removing/reordering words.
  """
  use MedoruWeb, :live_view

  alias Medoru.Content

  @impl true
  def mount(%{"id" => id}, session, socket) do
    locale = session["locale"] || "en"
    user = socket.assigns.current_scope.current_user

    # Verify user is a teacher
    if user.type not in ["teacher", "admin"] do
      {:ok,
       socket
       |> put_flash(:error, gettext("Only teachers can edit lessons."))
       |> push_navigate(to: ~p"/classrooms")}
    else
      lesson = Content.get_custom_lesson_with_words!(id)

      # Verify ownership
      if lesson.creator_id != user.id do
        {:ok,
         socket
         |> put_flash(:error, gettext("You can only edit your own lessons."))
         |> push_navigate(to: ~p"/teacher/custom-lessons")}
      else
        lesson_words = Content.list_lesson_words(lesson.id)

        {:ok,
         socket
         |> assign(:locale, locale)
         |> assign(:lesson, lesson)
         |> assign(:lesson_words, lesson_words)
         |> assign(:word_search_query, "")
         |> assign(:word_search_results, [])
         |> assign(:editing_word_id, nil)
         |> assign(:editing_custom_meaning, nil)
         |> assign(:editing_examples, nil)
         |> assign(:publish_modal_open, false)
         |> assign(:test_settings_changed, false)}
      end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(
       socket,
       :page_title,
       gettext("Edit Lesson: %{title}", title: socket.assigns.lesson.title)
     )}
  end

  @impl true
  def handle_event("word_search", %{"query" => query}, socket) do
    results =
      if String.length(query) >= 1 do
        Content.search_words(query, limit: 10)
      else
        []
      end

    {:noreply, assign(socket, word_search_query: query, word_search_results: results)}
  end

  @impl true
  def handle_event("add_word", %{"word_id" => word_id}, socket) do
    lesson = socket.assigns.lesson
    position = length(socket.assigns.lesson_words)

    # Check if word already exists in lesson
    existing = Enum.find(socket.assigns.lesson_words, fn lw -> lw.word_id == word_id end)

    if existing do
      {:noreply, put_flash(socket, :error, gettext("This word is already in the lesson."))}
    else
      case Content.add_word_to_lesson(lesson.id, word_id, %{position: position}) do
        {:ok, _} ->
          lesson_words = Content.list_lesson_words(lesson.id)
          lesson = Content.get_custom_lesson!(lesson.id)

          {:noreply,
           socket
           |> assign(:lesson_words, lesson_words)
           |> assign(:lesson, lesson)
           |> assign(:word_search_query, "")
           |> assign(:word_search_results, [])
           |> put_flash(:info, gettext("Word added!"))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to add word."))}
      end
    end
  end

  @impl true
  def handle_event("remove_word", %{"word_id" => word_id}, socket) do
    lesson = socket.assigns.lesson

    case Content.remove_word_from_lesson(lesson.id, word_id) do
      {:ok, _} ->
        lesson_words = Content.list_lesson_words(lesson.id)
        lesson = Content.get_custom_lesson!(lesson.id)

        {:noreply,
         socket
         |> assign(:lesson_words, lesson_words)
         |> assign(:lesson, lesson)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove word."))}
    end
  end

  @impl true
  def handle_event("reorder", %{"word_ids" => word_ids}, socket) do
    lesson = socket.assigns.lesson
    Content.reorder_lesson_words(lesson.id, word_ids)

    lesson_words = Content.list_lesson_words(lesson.id)
    {:noreply, assign(socket, :lesson_words, lesson_words)}
  end

  @impl true
  def handle_event("edit_word", %{"id" => id}, socket) do
    lesson_word = Enum.find(socket.assigns.lesson_words, fn lw -> lw.id == id end)
    
    {:noreply,
     socket
     |> assign(:editing_word_id, id)
     |> assign(:editing_custom_meaning, lesson_word.custom_meaning)
     |> assign(:editing_examples, Enum.join(lesson_word.examples || [], "\n"))}
  end
  
  @impl true
  def handle_event("update_editing_meaning", %{"value" => value}, socket) do
    {:noreply, assign(socket, :editing_custom_meaning, value)}
  end
  
  @impl true
  def handle_event("update_editing_examples", %{"value" => value}, socket) do
    {:noreply, assign(socket, :editing_examples, value)}
  end

  @impl true
  def handle_event("save_word", %{"id" => id}, socket) do
    lesson_word = Enum.find(socket.assigns.lesson_words, fn lw -> lw.id == id end)
    meaning = socket.assigns.editing_custom_meaning
    examples = socket.assigns.editing_examples

    # Parse examples (split by newline, remove empty)
    examples_list =
      examples
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    attrs = %{
      custom_meaning: meaning,
      examples: examples_list
    }

    case Content.update_custom_lesson_word(lesson_word, attrs) do
      {:ok, _} ->
        lesson_words = Content.list_lesson_words(socket.assigns.lesson.id)

        {:noreply,
         socket
         |> assign(:lesson_words, lesson_words)
         |> assign(:editing_word_id, nil)
         |> assign(:editing_custom_meaning, nil)
         |> assign(:editing_examples, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to update word."))}
    end
  end

  @impl true
  def handle_event("cancel_edit_word", _, socket) do
    {:noreply, assign(socket, :editing_word_id, nil)}
  end

  @impl true
  def handle_event("toggle_requires_test", _params, socket) do
    lesson = socket.assigns.lesson
    new_value = !lesson.requires_test

    # If enabling test and lesson is published but has no test, generate one
    test_result =
      if new_value and lesson.status == "published" and is_nil(lesson.test_id) do
        Medoru.Tests.CustomLessonTestGenerator.generate_lesson_test(
          lesson.id,
          include_writing: lesson.include_writing
        )
      else
        {:ok, nil}
      end

    case test_result do
      {:ok, _} ->
        case Content.update_custom_lesson(lesson, %{requires_test: new_value}) do
          {:ok, _updated_lesson} ->
            # Reload to get test_id if test was generated
            updated_lesson = Content.get_custom_lesson!(lesson.id)

            {:noreply,
             socket
             |> assign(:lesson, updated_lesson)
             |> assign(:test_settings_changed, true)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to update test setting."))}
        end

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, gettext("Failed to generate test: %{reason}", reason: inspect(reason)))}
    end
  end

  @impl true
  def handle_event("toggle_include_writing", _params, socket) do
    lesson = socket.assigns.lesson

    # Only allow toggling if requires_test is true
    if not lesson.requires_test do
      {:noreply, put_flash(socket, :error, gettext("Enable test requirement first."))}
    else
      new_value = !lesson.include_writing

      # If lesson is published and has a test, regenerate with new writing setting
      test_result =
        if lesson.status == "published" and not is_nil(lesson.test_id) do
          Medoru.Tests.CustomLessonTestGenerator.generate_lesson_test(
            lesson.id,
            include_writing: new_value
          )
        else
          {:ok, nil}
        end

      case test_result do
        {:ok, _} ->
          case Content.update_custom_lesson(lesson, %{include_writing: new_value}) do
            {:ok, _updated_lesson} ->
              # Reload to get updated test
              updated_lesson = Content.get_custom_lesson!(lesson.id)

              {:noreply,
               socket
               |> assign(:lesson, updated_lesson)
               |> assign(:test_settings_changed, true)}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, gettext("Failed to update writing setting."))}
          end

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, gettext("Failed to regenerate test: %{reason}", reason: inspect(reason)))}
      end
    end
  end

  @impl true
  def handle_event("publish", _params, socket) do
    lesson = socket.assigns.lesson

    # Check minimum word count
    if lesson.word_count < 1 do
      {:noreply, put_flash(socket, :error, gettext("Add at least 1 word before publishing."))}
    else
      # Generate test if required and not already generated
      test_result =
        if lesson.requires_test and is_nil(lesson.test_id) do
          Medoru.Tests.CustomLessonTestGenerator.generate_lesson_test(
            lesson.id,
            include_writing: lesson.include_writing
          )
        else
          {:ok, nil}
        end

      case test_result do
        {:ok, _test} ->
          # Reload lesson to get updated test_id
          lesson = Content.get_custom_lesson!(lesson.id)

          # Mark as published
          case Content.publish_custom_lesson(lesson) do
            {:ok, lesson} ->
              {:noreply,
               socket
               |> assign(:lesson, lesson)
               |> push_navigate(to: ~p"/teacher/custom-lessons/#{lesson.id}/publish")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, gettext("Failed to publish lesson."))}
          end

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, gettext("Failed to generate test: %{reason}", reason: inspect(reason)))}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={%{}} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/custom-lessons"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Lessons")}
          </.link>
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-base-content">{@lesson.title}</h1>
              <p class="text-secondary text-sm">
                {length(@lesson_words)} {gettext("words")} • {@lesson.status}
              </p>
            </div>
            <%= if @lesson.status == "draft" and @lesson.word_count >= 1 do %>
              <button phx-click="publish" class="btn btn-primary">
                <.icon name="hero-check" class="w-5 h-5 mr-2" /> {gettext("Publish")}
              </button>
            <% end %>
          </div>
        </div>

        <div class="grid gap-6 lg:grid-cols-3">
          <%!-- Word List --%>
          <div class="lg:col-span-2 space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-base-content">{gettext("Words")}</h2>
              <span class={["badge", (length(@lesson_words) > 50 && "badge-error") || "badge-ghost"]}>
                {length(@lesson_words)}/{gettext("50")}
              </span>
            </div>

            <%= if @lesson_words == [] do %>
              <div class="card bg-base-200">
                <div class="card-body text-center py-12">
                  <.icon name="hero-magnifying-glass" class="w-12 h-12 mx-auto text-base-300 mb-4" />
                  <p class="text-secondary">{gettext("Search for words to add to your lesson")}</p>
                </div>
              </div>
            <% else %>
              <div
                class="space-y-3"
                id="lesson-words"
                phx-hook="StepSorter"
                data-target="lesson-words"
              >
                <%= for {lesson_word, index} <- Enum.with_index(@lesson_words) do %>
                  <div
                    id={"word-#{lesson_word.id}"}
                    data-word-id={lesson_word.word_id}
                    class="card bg-base-100 border border-base-300"
                  >
                    <%= if @editing_word_id == lesson_word.id do %>
                      <%!-- Edit Mode --%>
                      <div class="card-body p-4">
                        <div class="flex items-start gap-4">
                          <div class="text-2xl font-jp">{lesson_word.word.text}</div>
                          <div class="flex-1 space-y-3">
                            <div>
                              <label class="label text-sm">
                                {gettext("Custom Meaning (optional)")}
                              </label>
                              <input
                                type="text"
                                id={"meaning-#{lesson_word.id}"}
                                value={@editing_custom_meaning}
                                phx-change="update_editing_meaning"
                                class="input input-bordered w-full input-sm"
                                placeholder={Content.get_localized_meaning(lesson_word.word, @locale)}
                              />
                            </div>
                            <div>
                              <label class="label text-sm">
                                {gettext("Examples (one per line, max 5)")}
                              </label>
                              <textarea
                                id={"examples-#{lesson_word.id}"}
                                phx-change="update_editing_examples"
                                class="textarea textarea-bordered w-full textarea-sm"
                                rows={3}
                                placeholder={gettext("Add example sentences using this word...")}
                              >{@editing_examples}</textarea>
                            </div>
                          </div>
                        </div>
                        <div class="flex justify-end gap-2 mt-4">
                          <button
                            phx-click="cancel_edit_word"
                            class="btn btn-ghost btn-sm"
                          >
                            Cancel
                          </button>
                          <button
                            phx-click="save_word"
                            phx-value-id={lesson_word.id}
                            class="btn btn-primary btn-sm"
                          >
                            Save
                          </button>
                        </div>
                      </div>
                    <% else %>
                      <%!-- View Mode --%>
                      <div class="card-body p-4">
                        <div class="flex items-start gap-4">
                          <div class="cursor-move p-2 hover:bg-base-200 rounded" data-drag-handle>
                            <.icon name="hero-bars-3" class="w-5 h-5 text-secondary" />
                          </div>
                          <div class="flex-1">
                            <div class="flex items-baseline gap-3">
                              <span class="text-2xl font-jp">{lesson_word.word.text}</span>
                              <span class="text-secondary">{lesson_word.word.reading}</span>
                            </div>
                            <p class="text-base-content mt-1">
                              {lesson_word.custom_meaning ||
                                Content.get_localized_meaning(lesson_word.word, @locale)}
                            </p>
                            <%= if lesson_word.examples != [] do %>
                              <div class="mt-2 space-y-1">
                                <%= for example <- lesson_word.examples do %>
                                  <p class="text-sm text-secondary font-jp">• {example}</p>
                                <% end %>
                              </div>
                            <% end %>
                          </div>
                          <div class="flex gap-2">
                            <button
                              phx-click="edit_word"
                              phx-value-id={lesson_word.id}
                              class="btn btn-ghost btn-sm"
                            >
                              <.icon name="hero-pencil" class="w-4 h-4" />
                            </button>
                            <button
                              phx-click="remove_word"
                              phx-value-word_id={lesson_word.word_id}
                              data-confirm={gettext("Remove this word?")}
                              class="btn btn-ghost btn-sm text-error"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                            </button>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <%!-- Sidebar: Add Words --%>
          <div class="space-y-4">
            <h2 class="text-lg font-semibold text-base-content">{gettext("Add Words")}</h2>

            <div class="card bg-base-100 border border-base-300">
              <div class="card-body p-4">
                <%!-- Search --%>
                <form phx-change="word_search" class="mb-4">
                  <div class="relative">
                    <.icon
                      name="hero-magnifying-glass"
                      class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-secondary"
                    />
                    <input
                      type="text"
                      name="query"
                      value={@word_search_query}
                      placeholder={gettext("Search words...")}
                      class="input input-bordered w-full pl-10"
                      phx-debounce="300"
                    />
                  </div>
                </form>

                <%!-- Results --%>
                <div class="space-y-2 max-h-96 overflow-y-auto">
                  <%= for word <- @word_search_results do %>
                    <div class="flex items-center gap-2 p-2 hover:bg-base-200 rounded-lg">
                      <button
                        phx-click="add_word"
                        phx-value-word_id={word.id}
                        class="btn btn-ghost btn-sm flex-shrink-0"
                        disabled={length(@lesson_words) >= 50}
                      >
                        <.icon name="hero-plus" class="w-4 h-4" />
                      </button>
                      <div class="min-w-0 flex-1">
                        <div class="flex items-baseline gap-2">
                          <span class="text-lg font-jp truncate">{word.text}</span>
                          <span class="text-sm text-secondary truncate">{word.reading}</span>
                        </div>
                        <p class="text-sm text-secondary truncate">
                          {Content.get_localized_meaning(word, @locale)}
                        </p>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%= if @word_search_query != "" and @word_search_results == [] do %>
                  <p class="text-center text-secondary py-4">{gettext("No words found")}</p>
                <% end %>

                <%= if length(@lesson_words) >= 50 do %>
                  <p class="text-center text-error text-sm mt-4">
                    {gettext("Maximum 50 words reached")}
                  </p>
                <% end %>
              </div>
            </div>

            <%!-- Test Settings --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body p-4">
                <h3 class="font-semibold text-base-content mb-4">
                  <.icon name="hero-pencil-square" class="w-5 h-5 mr-1 inline" />
                  {gettext("Test Settings")}
                </h3>

                <div class="space-y-4">
                  <%!-- Require Test --%>
                  <label class="flex items-start gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={@lesson.requires_test}
                      phx-click="toggle_requires_test"
                      class="checkbox checkbox-primary mt-0.5"
                    />
                    <div>
                      <div class="font-medium text-sm">{gettext("Require test to complete")}</div>
                      <div class="text-xs text-secondary">
                        {gettext("Students must pass a test to finish the lesson")}
                      </div>
                    </div>
                  </label>

                  <%!-- Include Writing --%>
                  <label class={["flex items-start gap-3 cursor-pointer", not @lesson.requires_test && "opacity-50"]}>
                    <input
                      type="checkbox"
                      checked={@lesson.include_writing}
                      disabled={not @lesson.requires_test}
                      phx-click="toggle_include_writing"
                      class="checkbox checkbox-primary mt-0.5"
                    />
                    <div>
                      <div class="font-medium text-sm">{gettext("Include kanji writing")}</div>
                      <div class="text-xs text-secondary">
                        {gettext("Add drawing steps for kanji in lesson words")}
                      </div>
                    </div>
                  </label>
                </div>

                <%= if @test_settings_changed do %>
                  <div class="mt-4 p-3 bg-info/10 rounded-lg">
                    <p class="text-xs text-info flex items-center gap-2">
                      <.icon name="hero-information-circle" class="w-4 h-4" />
                      <%= if @lesson.status == "published" do %>
                        {gettext("Settings saved. Changes will apply to new students.")}
                      <% else %>
                        {gettext("Settings saved. Test will be generated on publish.")}
                      <% end %>
                    </p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
