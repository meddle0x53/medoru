defmodule MedoruWeb.Teacher.GrammarLessonLive.FromImage do
  @moduledoc """
  LiveView for creating a custom grammar lesson from an uploaded image.

  Admin-only feature. Upload an image of a grammar page,
  AI extracts the sections, admin reviews and creates a draft lesson,
  then gets redirected to the lesson editor.
  """
  use MedoruWeb, :live_view

  alias Medoru.AI.ImageGrammar
  alias Medoru.AI.GrammarParser
  alias Medoru.Content.GrammarImageBuilder

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Only admins for now
    if user.type != "admin" do
      {:ok,
       socket
       |> put_flash(:error, gettext("Only admins can create lessons from images."))
       |> push_navigate(to: ~p"/teacher/grammar-lessons")}
    else
      {:ok,
       socket
       |> assign(:page_title, gettext("Create Grammar Lesson from Image"))
       |> assign(:step, :upload)
       |> assign(:extracted_sections, [])
       |> assign(:selected_section_indices, MapSet.new())
       |> assign(:lesson_title, gettext("Grammar lesson from image — change the name"))
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
         |> start_async(:extract, fn -> ImageGrammar.extract_grammar(image_binary) end)}
    end
  end

  @impl true
  def handle_event("toggle_section", %{"index" => index}, socket) do
    index = String.to_integer(index)

    selected =
      if MapSet.member?(socket.assigns.selected_section_indices, index) do
        MapSet.delete(socket.assigns.selected_section_indices, index)
      else
        MapSet.put(socket.assigns.selected_section_indices, index)
      end

    {:noreply, assign(socket, :selected_section_indices, selected)}
  end

  @impl true
  def handle_event(
        "update_section",
        %{"index" => index, "field" => field, "value" => value},
        socket
      ) do
    index = String.to_integer(index)
    sections = socket.assigns.extracted_sections

    updated_sections =
      List.update_at(sections, index, fn section ->
        Map.put(section, field, value)
      end)

    {:noreply, assign(socket, :extracted_sections, updated_sections)}
  end

  @impl true
  def handle_event(
        "update_example",
        %{"section_index" => sidx, "example_index" => eidx, "field" => field, "value" => value},
        socket
      ) do
    sidx = String.to_integer(sidx)
    eidx = String.to_integer(eidx)
    sections = socket.assigns.extracted_sections

    updated_sections =
      List.update_at(sections, sidx, fn section ->
        examples = section["examples"] || []

        updated_examples =
          List.update_at(examples, eidx, fn ex ->
            Map.put(ex, field, value)
          end)

        Map.put(section, "examples", updated_examples)
      end)

    {:noreply, assign(socket, :extracted_sections, updated_sections)}
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
      socket.assigns.extracted_sections
      |> Enum.with_index()
      |> Enum.map(fn {_, i} -> i end)
      |> MapSet.new()

    {:noreply, assign(socket, :selected_section_indices, indices)}
  end

  @impl true
  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_section_indices, MapSet.new())}
  end

  @impl true
  def handle_event("create_lesson", _params, socket) do
    user = socket.assigns.current_scope.current_user
    sections = socket.assigns.extracted_sections
    selected = socket.assigns.selected_section_indices

    selected_sections =
      sections
      |> Enum.with_index()
      |> Enum.filter(fn {_, i} -> MapSet.member?(selected, i) end)
      |> Enum.map(fn {section, _} -> section end)

    if selected_sections == [] do
      {:noreply, put_flash(socket, :error, gettext("Please select at least one section."))}
    else
      extracted_data = %{
        "title" => socket.assigns.lesson_title,
        "sections" => selected_sections
      }

      lesson_attrs = %{
        title: socket.assigns.lesson_title,
        description: socket.assigns.lesson_description
      }

      case GrammarImageBuilder.build_lesson_from_extracted_grammar(
             extracted_data,
             lesson_attrs,
             user.id
           ) do
        {:ok, lesson} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Grammar lesson created! Redirecting to editor..."))
           |> push_navigate(to: ~p"/teacher/grammar-lessons/#{lesson.id}/edit")}

        {:error, msg} when is_binary(msg) ->
          {:noreply, put_flash(socket, :error, msg)}

        {:error, %Ecto.Changeset{} = changeset} ->
          errors =
            Enum.map_join(changeset.errors, ", ", fn {field, {msg, _}} ->
              "#{field}: #{msg}"
            end)

          {:noreply,
           put_flash(
             socket,
             :error,
             gettext("Failed to create lesson: %{errors}", errors: errors)
           )}
      end
    end
  end

  @impl true
  def handle_async(:extract, {:ok, {:ok, data}}, socket) do
    parsed = GrammarParser.parse_extracted_grammar(data)
    sections = parsed["sections"] || []

    selected =
      sections
      |> Enum.with_index()
      |> Enum.map(fn {_, i} -> i end)
      |> MapSet.new()

    # Use AI-extracted title if available
    ai_title = parsed["title"]
    lesson_title = if ai_title && ai_title != "", do: ai_title, else: socket.assigns.lesson_title

    {:noreply,
     socket
     |> assign(:step, :preview)
     |> assign(:extracted_sections, sections)
     |> assign(:selected_section_indices, selected)
     |> assign(:lesson_title, lesson_title)
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
            navigate={~p"/teacher/grammar-lessons"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Grammar Lessons")}
          </.link>
          <h1 class="text-2xl sm:text-3xl font-bold text-base-content">
            {gettext("Create Grammar Lesson from Image")}
          </h1>
          <p class="text-secondary mt-1">
            {gettext("Upload a grammar page and let AI extract the sections")}
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
                      <span class="label-text font-medium">{gettext("Grammar Page Image")}</span>
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
                        <span class="text-sm text-base-content flex-1 truncate">
                          {entry.client_name}
                        </span>
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
                      {gettext("Extract Grammar")}
                    </button>
                  </div>
                </.form>
              </div>
            </div>
          <% :preview -> %>
            <% selected_count = MapSet.size(@selected_section_indices) %>

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
                      <form phx-change="update_title">
                        <input
                          type="text"
                          name="title"
                          class="input input-bordered w-full"
                          value={@lesson_title}
                          phx-debounce="300"
                        />
                      </form>
                    </div>
                    <div>
                      <label class="label">
                        <span class="label-text">{gettext("Description")}</span>
                      </label>
                      <form phx-change="update_description">
                        <input
                          type="text"
                          name="description"
                          class="input input-bordered w-full"
                          value={@lesson_description}
                          phx-debounce="300"
                        />
                      </form>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Sections List --%>
              <div class="space-y-4">
                <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                  <h2 class="text-lg font-bold">
                    {gettext("Extracted Sections")}
                    <span class="badge badge-primary badge-sm">
                      {selected_count}/{length(@extracted_sections)}
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

                <%= for {section, index} <- Enum.with_index(@extracted_sections) do %>
                  <% checked = MapSet.member?(@selected_section_indices, index) %>
                  <div class={[
                    "card bg-base-100 border transition-colors",
                    if(checked, do: "border-primary", else: "border-base-300 opacity-60")
                  ]}>
                    <div class="card-body p-4">
                      <div class="flex items-start gap-3">
                        <input
                          type="checkbox"
                          class="checkbox checkbox-sm checkbox-primary mt-1"
                          checked={checked}
                          phx-click="toggle_section"
                          phx-value-index={index}
                        />
                        <div class="flex-1 min-w-0 space-y-3">
                          <%!-- Section Title --%>
                          <div>
                            <div class="flex items-center gap-2 mb-1">
                              <span class={[
                                "badge badge-sm",
                                section["step_type"] == "grammar" && "badge-primary",
                                section["step_type"] == "text" && "badge-ghost"
                              ]}>
                                {String.capitalize(section["step_type"])}
                              </span>
                              <span class="text-sm text-secondary">#{section["number"]}</span>
                            </div>
                            <form phx-change="update_section" class="contents">
                              <input type="hidden" name="index" value={index} />
                              <input type="hidden" name="field" value="title" />
                              <input
                                type="text"
                                name="value"
                                class="input input-bordered input-sm w-full font-medium"
                                value={section["title"]}
                                phx-debounce="300"
                              />
                            </form>
                          </div>

                          <%!-- Description --%>
                          <div>
                            <label class="label text-xs py-0">
                              <span class="label-text">{gettext("Description")}</span>
                            </label>
                            <form phx-change="update_section" class="contents">
                              <input type="hidden" name="index" value={index} />
                              <input type="hidden" name="field" value="description" />
                              <textarea
                                name="value"
                                class="textarea textarea-bordered textarea-sm w-full"
                                rows={4}
                                phx-debounce="300"
                              ><%= section["description"] %></textarea>
                            </form>
                          </div>

                          <%!-- Examples (grammar steps only) --%>
                          <%= if section["step_type"] == "grammar" and length(section["examples"] || []) > 0 do %>
                            <div>
                              <label class="label text-xs py-0">
                                <span class="label-text">{gettext("Examples")}</span>
                              </label>
                              <div class="space-y-2">
                                <%= for {example, ex_idx} <- Enum.with_index(section["examples"] || []) do %>
                                  <div class="bg-base-200 rounded-lg p-3 space-y-2">
                                    <form phx-change="update_example" class="contents">
                                      <input type="hidden" name="section_index" value={index} />
                                      <input type="hidden" name="example_index" value={ex_idx} />
                                      <input type="hidden" name="field" value="sentence" />
                                      <input
                                        type="text"
                                        name="value"
                                        class="input input-bordered input-sm w-full font-jp"
                                        value={example["sentence"]}
                                        placeholder={gettext("Sentence")}
                                        phx-debounce="300"
                                      />
                                    </form>
                                    <form phx-change="update_example" class="contents">
                                      <input type="hidden" name="section_index" value={index} />
                                      <input type="hidden" name="example_index" value={ex_idx} />
                                      <input type="hidden" name="field" value="reading" />
                                      <input
                                        type="text"
                                        name="value"
                                        class="input input-bordered input-sm w-full"
                                        value={example["reading"]}
                                        placeholder={gettext("Reading")}
                                        phx-debounce="300"
                                      />
                                    </form>
                                    <form phx-change="update_example" class="contents">
                                      <input type="hidden" name="section_index" value={index} />
                                      <input type="hidden" name="example_index" value={ex_idx} />
                                      <input type="hidden" name="field" value="meaning" />
                                      <input
                                        type="text"
                                        name="value"
                                        class="input input-bordered input-sm w-full"
                                        value={example["meaning"]}
                                        placeholder={gettext("Meaning")}
                                        phx-debounce="300"
                                      />
                                    </form>
                                  </div>
                                <% end %>
                              </div>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>

                <div class="flex justify-end gap-3 mt-6">
                  <.link
                    navigate={~p"/teacher/grammar-lessons"}
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
                    {gettext("Create Draft Lesson (%{count} sections)", count: selected_count)}
                  </button>
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
