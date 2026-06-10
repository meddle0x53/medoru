defmodule MedoruWeb.Teacher.CustomLessonLive.FromImage do
  @moduledoc """
  LiveView for creating a custom vocabulary lesson from an uploaded image.

  Admin-only feature (for now). Upload an image of a vocabulary page,
  AI extracts the words, admin reviews and creates a draft lesson,
  then gets redirected to the lesson editor.
  """
  use MedoruWeb, :live_view

  alias Medoru.AI.ImageVocabulary
  alias Medoru.Content.ImageLessonBuilder

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Only admins for now
    if user.type != "admin" do
      {:ok,
       socket
       |> put_flash(:error, gettext("Only admins can create lessons from images."))
       |> push_navigate(to: ~p"/teacher/custom-lessons")}
    else
      {:ok,
       socket
       |> assign(:page_title, gettext("Create Lesson from Image"))
       |> assign(:step, :upload)
       |> assign(:extracted_words, [])
       |> assign(:selected_word_indices, MapSet.new())
       |> assign(:lesson_title, gettext("Vocabulary lesson from image — change the name"))
       |> assign(:lesson_description, "")
       |> assign(:loading, false)
       |> assign(:error, nil)
       |> allow_upload(:image,
         accept: ~w(.jpg .jpeg .png .webp),
         max_entries: 1,
         max_file_size: 5_000_000
       )}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("extract", _params, socket) do
    case consume_uploaded_entries(socket, :image, fn %{path: path}, _entry ->
           {:ok, File.read!(path)}
         end) do
      [] ->
        {:noreply, put_flash(socket, :error, gettext("Please select an image file."))}

      [image_binary] ->
        {:noreply,
         socket
         |> assign(:loading, true)
         |> assign(:error, nil)
         |> start_async(:extract, fn -> ImageVocabulary.extract_vocabulary(image_binary) end)}
    end
  end

  @impl true
  def handle_event("toggle_word", %{"index" => index}, socket) do
    index = String.to_integer(index)

    selected =
      if MapSet.member?(socket.assigns.selected_word_indices, index) do
        MapSet.delete(socket.assigns.selected_word_indices, index)
      else
        MapSet.put(socket.assigns.selected_word_indices, index)
      end

    {:noreply, assign(socket, :selected_word_indices, selected)}
  end

  @impl true
  def handle_event("update_word", %{"index" => index, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index)
    words = socket.assigns.extracted_words

    updated_words =
      List.update_at(words, index, fn word ->
        Map.put(word, field, value)
      end)

    {:noreply, assign(socket, :extracted_words, updated_words)}
  end

  @impl true
  def handle_event("update_title", %{"title" => title}, socket) do
    {:noreply, assign(socket, :lesson_title, title)}
  end

  @impl true
  def handle_event("update_description", %{"description" => description}, socket) do
    {:noreply, assign(socket, :lesson_description, description)}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    indices =
      socket.assigns.extracted_words
      |> Enum.with_index()
      |> Enum.map(fn {_, i} -> i end)
      |> MapSet.new()

    {:noreply, assign(socket, :selected_word_indices, indices)}
  end

  @impl true
  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_word_indices, MapSet.new())}
  end

  @impl true
  def handle_event("create_lesson", _params, socket) do
    user = socket.assigns.current_scope.current_user
    words = socket.assigns.extracted_words
    selected = socket.assigns.selected_word_indices

    selected_words =
      words
      |> Enum.with_index()
      |> Enum.filter(fn {_, i} -> MapSet.member?(selected, i) end)
      |> Enum.map(fn {word, _} -> word end)

    if selected_words == [] do
      {:noreply, put_flash(socket, :error, gettext("Please select at least one word."))}
    else
      lesson_attrs = %{
        title: socket.assigns.lesson_title,
        description: socket.assigns.lesson_description
      }

      case ImageLessonBuilder.build_lesson_from_extracted_words(
             selected_words,
             lesson_attrs,
             user.id
           ) do
        {:ok, lesson} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Lesson created! Redirecting to editor..."))
           |> push_navigate(to: ~p"/teacher/custom-lessons/#{lesson.id}/edit")}

        {:error, msg} when is_binary(msg) ->
          {:noreply, put_flash(socket, :error, msg)}

        {:error, %Ecto.Changeset{} = changeset} ->
          errors =
            Enum.map_join(changeset.errors, ", ", fn {field, {msg, _}} ->
              "#{field}: #{msg}"
            end)

          {:noreply, put_flash(socket, :error, gettext("Failed to create lesson: %{errors}", errors: errors))}
      end
    end
  end

  @impl true
  def handle_async(:extract, {:ok, {:ok, words}}, socket) do
    selected =
      words
      |> Enum.with_index()
      |> Enum.map(fn {_, i} -> i end)
      |> MapSet.new()

    {:noreply,
     socket
     |> assign(:step, :preview)
     |> assign(:extracted_words, words)
     |> assign(:selected_word_indices, selected)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_async(:extract, {:ok, {:error, msg}}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:error, msg)
     |> put_flash(:error, gettext("Extraction failed: %{message}", message: msg))}
  end

  @impl true
  def handle_async(:extract, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:error, inspect(reason))
     |> put_flash(:error, gettext("Extraction process crashed."))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-5xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/custom-lessons"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Lessons")}
          </.link>
          <h1 class="text-2xl sm:text-3xl font-bold text-base-content">
            {gettext("Create Lesson from Image")}
          </h1>
          <p class="text-secondary mt-1">
            {gettext("Upload a vocabulary page and let AI extract the words")}
          </p>
        </div>

        <%= case @step do %>
          <% :upload -> %>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <.form
                  for={%{}}
                  id="image-upload-form"
                  phx-change="validate"
                  phx-submit="extract"
                  class="space-y-6"
                >
                  <div>
                    <label class="label">
                      <span class="label-text font-medium">{gettext("Vocabulary Page Image")}</span>
                    </label>
                    <div
                      class="border-2 border-dashed border-base-300 rounded-xl p-8 text-center hover:border-primary transition-colors cursor-pointer"
                      phx-drop-target={@uploads.image.ref}
                    >
                      <.live_file_input upload={@uploads.image} class="hidden" />
                      <div phx-click={JS.dispatch("click", to: "##{@uploads.image.ref}")}>
                        <.icon name="hero-photo" class="w-12 h-12 mx-auto text-base-300 mb-3" />
                        <p class="text-base-content font-medium">
                          {gettext("Click or drag an image here")}
                        </p>
                        <p class="text-secondary text-sm mt-1">
                          {gettext("JPG, PNG, WebP up to 5MB")}
                        </p>
                      </div>
                    </div>

                    <%= for entry <- @uploads.image.entries do %>
                      <div class="mt-4 flex items-center gap-3 p-3 bg-base-200 rounded-lg">
                        <.icon name="hero-document" class="w-5 h-5 text-primary" />
                        <span class="text-sm text-base-content flex-1 truncate">{entry.client_name}</span>
                        <button
                          type="button"
                          phx-click="cancel-upload"
                          phx-value-ref={entry.ref}
                          class="text-error hover:text-error/80"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4" />
                        </button>
                      </div>

                      <%= for err <- upload_errors(@uploads.image, entry) do %>
                        <p class="text-error text-sm mt-1">{error_to_string(err)}</p>
                      <% end %>
                    <% end %>
                  </div>

                  <div class="flex justify-end">
                    <button
                      type="submit"
                      class="btn btn-primary"
                      disabled={@uploads.image.entries == []}
                    >
                      <.icon name="hero-sparkles" class="w-5 h-5 mr-2" />
                      {gettext("Extract Vocabulary")}
                    </button>
                  </div>
                </.form>
              </div>
            </div>

          <% :preview -> %>
            <% selected_count = MapSet.size(@selected_word_indices) %>

            <div class="space-y-6">
              <%!-- Lesson Info --%>
              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <h2 class="card-title text-lg">{gettext("Lesson Details")}</h2>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2">
                    <div>
                      <label class="label">
                        <span class="label-text">{gettext("Title")}</span>
                      </label>
                      <input
                        type="text"
                        class="input input-bordered w-full"
                        value={@lesson_title}
                        phx-change="update_title"
                        phx-debounce="300"
                      />
                    </div>
                    <div>
                      <label class="label">
                        <span class="label-text">{gettext("Description")}</span>
                      </label>
                      <input
                        type="text"
                        class="input input-bordered w-full"
                        value={@lesson_description}
                        phx-change="update_description"
                        phx-debounce="300"
                      />
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Words Table --%>
              <div class="card bg-base-100 border border-base-300">
                <div class="card-body">
                  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
                    <h2 class="card-title text-lg">
                      {gettext("Extracted Words")}
                      <span class="badge badge-primary badge-sm">
                        {selected_count}/{length(@extracted_words)}
                      </span>
                    </h2>
                    <div class="flex gap-2">
                      <button
                        type="button"
                        phx-click="select_all"
                        class="btn btn-ghost btn-xs"
                      >
                        {gettext("Select All")}
                      </button>
                      <button
                        type="button"
                        phx-click="deselect_all"
                        class="btn btn-ghost btn-xs"
                      >
                        {gettext("Deselect All")}
                      </button>
                    </div>
                  </div>

                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr>
                          <th class="w-10"></th>
                          <th>{gettext("Text")}</th>
                          <th>{gettext("Reading")}</th>
                          <th>{gettext("Meaning")}</th>
                          <th>{gettext("Type")}</th>
                          <th>{gettext("Notes")}</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for {word, index} <- Enum.with_index(@extracted_words) do %>
                          <% checked = MapSet.member?(@selected_word_indices, index) %>
                          <tr class={if not checked, do: "opacity-50"}>
                            <td>
                              <input
                                type="checkbox"
                                class="checkbox checkbox-sm checkbox-primary"
                                checked={checked}
                                phx-click="toggle_word"
                                phx-value-index={index}
                              />
                            </td>
                            <td>
                              <input
                                type="text"
                                class="input input-bordered input-sm w-full min-w-[120px]"
                                value={word["text"]}
                                phx-change="update_word"
                                phx-value-index={index}
                                phx-value-field="text"
                                phx-debounce="300"
                              />
                            </td>
                            <td>
                              <input
                                type="text"
                                class="input input-bordered input-sm w-full min-w-[120px]"
                                value={word["reading"]}
                                phx-change="update_word"
                                phx-value-index={index}
                                phx-value-field="reading"
                                phx-debounce="300"
                              />
                            </td>
                            <td>
                              <input
                                type="text"
                                class="input input-bordered input-sm w-full min-w-[150px]"
                                value={word["meaning"]}
                                phx-change="update_word"
                                phx-value-index={index}
                                phx-value-field="meaning"
                                phx-debounce="300"
                              />
                            </td>
                            <td>
                              <span class="badge badge-sm badge-ghost">
                                {word["word_type"]}
                              </span>
                            </td>
                            <td class="text-sm text-secondary max-w-[200px] truncate">
                              {word["notes"]}
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>

                  <div class="flex justify-end gap-3 mt-6">
                    <.link
                      navigate={~p"/teacher/custom-lessons"}
                      class="btn btn-ghost"
                    >
                      {gettext("Cancel")}
                    </.link>
                    <button
                      type="button"
                      phx-click="create_lesson"
                      class="btn btn-primary"
                      disabled={selected_count == 0}
                    >
                      <.icon name="hero-plus" class="w-5 h-5 mr-2" />
                      {gettext("Create Draft Lesson (%{count} words)", count: selected_count)}
                    </button>
                  </div>
                </div>
              </div>
            </div>
        <% end %>

        <%!-- Loading Overlay --%>
        <%= if @loading do %>
          <div class="fixed inset-0 bg-base-100/80 backdrop-blur-sm z-50 flex items-center justify-center">
            <div class="text-center">
              <span class="loading loading-spinner loading-lg text-primary"></span>
              <p class="mt-4 text-base-content font-medium">
                {gettext("Analyzing image with AI...")}
              </p>
              <p class="text-secondary text-sm mt-1">
                {gettext("This may take 10-30 seconds")}
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp error_to_string(:too_large), do: gettext("File is too large (max 5MB)")
  defp error_to_string(:too_many_files), do: gettext("Too many files")
  defp error_to_string(:not_accepted), do: gettext("File type not accepted")
  defp error_to_string(err), do: to_string(err)
end
