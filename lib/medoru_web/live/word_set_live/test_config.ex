defmodule MedoruWeb.WordSetLive.TestConfig do
  @moduledoc """
  LiveView for configuring a practice test for a word set.
  Allows users to select step types and max steps per word.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Learning.WordSets

  @available_step_types [
    %{id: "word_to_meaning", label: gettext("Word to Meaning"), icon: "hero-book-open", 
      description: gettext("Show a Japanese word and select the English meaning")},
    %{id: "word_to_reading", label: gettext("Word to Reading"), icon: "hero-language",
      description: gettext("Show a Japanese word and select the hiragana reading")},
    %{id: "reading_text", label: gettext("Type Meaning & Reading"), icon: "hero-pencil",
      description: gettext("Type both the English meaning and hiragana reading")},
    %{id: "image_to_meaning", label: gettext("Image to Meaning"), icon: "hero-photo",
      description: gettext("Show a Japanese word and select from image options")},
    %{id: "kanji_writing", label: gettext("Kanji Writing"), icon: "hero-paint-brush",
      description: gettext("Draw kanji with correct stroke order (3 points)")}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Create Practice Test"))
     |> assign(:selected_types, ["word_to_meaning", "word_to_reading"])
     |> assign(:max_steps_per_word, 3)
     |> assign(:available_step_types, @available_step_types)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    user = socket.assigns.current_scope.current_user
    word_set = WordSets.get_word_set!(id)

    # Ensure user owns this word set
    if word_set.user_id != user.id do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to configure this word set."))
       |> push_navigate(to: ~p"/words/sets")}
    else
      # Check if word set has words
      if word_set.word_count == 0 do
        {:noreply,
         socket
         |> put_flash(:error, gettext("Add words to your set before creating a test."))
         |> push_navigate(to: ~p"/words/sets/#{word_set.id}/edit-words")}
      else
        {:noreply,
         socket
         |> assign(:word_set, word_set)}
      end
    end
  end

  @impl true
  def handle_event("toggle_type", %{"type" => type}, socket) do
    current_types = socket.assigns.selected_types

    new_types =
      if type in current_types do
        # Don't allow unchecking the last type
        if length(current_types) > 1 do
          List.delete(current_types, type)
        else
          current_types
        end
      else
        [type | current_types]
      end

    {:noreply, assign(socket, :selected_types, new_types)}
  end

  @impl true
  def handle_event("set_max_steps", %{"value" => value}, socket) do
    case Integer.parse(value) do
      {n, _} when n in 1..5 ->
        {:noreply, assign(socket, :max_steps_per_word, n)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("create_test", _params, socket) do
    word_set = socket.assigns.word_set
    step_types = socket.assigns.selected_types
    max_steps = socket.assigns.max_steps_per_word

    # Convert string types to atoms
    step_type_atoms = Enum.map(step_types, &String.to_atom/1)

    case WordSets.create_practice_test(word_set,
           step_types: step_type_atoms,
           max_steps_per_word: max_steps
         ) do
      {:ok, _test} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Practice test created successfully!"))
         |> push_navigate(to: ~p"/words/sets/#{word_set.id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to create test: %{reason}", 
          reason: inspect(reason)))}
    end
  end

  defp step_type_card_class(selected) do
    if selected do
      "border-primary bg-primary/5 ring-1 ring-primary"
    else
      "border-base-300 hover:border-primary/30 hover:bg-base-100"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{gettext("Create Practice Test")}</h1>
          <p class="text-secondary mt-2">
            {gettext("Configure your practice test for '%{name}'", name: @word_set.name)}
          </p>
        </div>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body space-y-8">
            <%!-- Step Type Selection --%>
            <div>
              <h2 class="text-sm font-medium text-secondary uppercase tracking-wide mb-4">
                {gettext("Question Types")}
              </h2>
              <div class="space-y-3">
                <%= for step_type <- @available_step_types do %>
                  <% is_selected = step_type.id in @selected_types %>
                  <button
                    type="button"
                    phx-click="toggle_type"
                    phx-value-type={step_type.id}
                    class={[
                      "w-full flex items-start gap-4 p-4 rounded-xl border-2 transition-all text-left",
                      step_type_card_class(is_selected)
                    ]}
                  >
                    <div class={[
                      "w-10 h-10 rounded-lg flex items-center justify-center shrink-0",
                      if(is_selected,
                        do: "bg-primary text-primary-content",
                        else: "bg-base-200 text-secondary"
                      )
                    ]}>
                      <.icon name={step_type.icon} class="w-5 h-5" />
                    </div>

                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2">
                        <span class="font-medium text-base-content">{step_type.label}</span>
                        <%= if is_selected do %>
                          <.icon name="hero-check-circle" class="w-5 h-5 text-primary" />
                        <% end %>
                      </div>
                      <p class="text-sm text-secondary mt-1">{step_type.description}</p>
                    </div>

                    <%= if is_selected do %>
                      <div class="w-6 h-6 rounded-full border-2 border-primary bg-primary flex items-center justify-center shrink-0">
                        <.icon name="hero-check" class="w-4 h-4 text-primary-content" />
                      </div>
                    <% else %>
                      <div class="w-6 h-6 rounded-full border-2 border-base-300 shrink-0"></div>
                    <% end %>
                  </button>
                <% end %>
              </div>

              <%= if length(@selected_types) == 1 do %>
                <div class="mt-4 p-4 bg-warning/10 rounded-lg">
                  <div class="flex items-start gap-3">
                    <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-warning mt-0.5" />
                    <div class="text-sm text-warning-content">
                      <p>{gettext("You must have at least one question type selected.")}</p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>

            <%!-- Max Steps Per Word --%>
            <div>
              <h2 class="text-sm font-medium text-secondary uppercase tracking-wide mb-4">
                {gettext("Questions Per Word")}
              </h2>
              <div class="flex items-center gap-4">
                <input
                  type="range"
                  min="1"
                  max="5"
                  value={@max_steps_per_word}
                  phx-change="set_max_steps"
                  class="flex-1 h-2 bg-base-200 rounded-lg appearance-none cursor-pointer accent-primary"
                />
                <span class="w-12 text-center font-medium text-base-content">
                  {@max_steps_per_word}
                </span>
              </div>
              <p class="text-sm text-secondary mt-2">
                {gettext("Each word will get 1 to %{max} random questions from the selected types.", max: @max_steps_per_word)}
              </p>
            </div>

            <%!-- Info Box --%>
            <div class="p-4 bg-info/10 rounded-lg">
              <div class="flex items-start gap-3">
                <.icon name="hero-information-circle" class="w-5 h-5 text-info mt-0.5" />
                <div class="text-sm text-info-content">
                  <p class="font-medium mb-1">{gettext("How it works:")}</p>
                  <p>
                    {gettext("The test will contain questions for each of your %{count} words. For each word, we'll randomly select between 1 and %{max} question types from your selection above.", 
                      count: @word_set.word_count, max: @max_steps_per_word)}
                  </p>
                </div>
              </div>
            </div>

            <%!-- Actions --%>
            <div class="flex flex-col sm:flex-row gap-3 pt-4 border-t border-base-300">
              <button
                type="button"
                phx-click="create_test"
                disabled={length(@selected_types) == 0}
                class="flex-1 px-6 py-3 bg-primary hover:bg-primary/90 disabled:bg-base-300 disabled:cursor-not-allowed text-primary-content rounded-lg font-medium transition-colors"
              >
                {gettext("Create Test")}
              </button>
              <.link
                navigate={~p"/words/sets/#{@word_set.id}"}
                class="px-6 py-3 bg-base-200 hover:bg-base-300 text-base-content rounded-lg font-medium text-center transition-colors"
              >
                {gettext("Cancel")}
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
