defmodule MedoruWeb.Teacher.ClassroomLive.New do
  @moduledoc """
  LiveView for teachers to create a new classroom.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Classrooms
  alias Medoru.Classrooms.Classroom

  @impl true
  def mount(_params, _session, socket) do
    changeset = Classrooms.change_classroom(%Classroom{})

    {:ok,
     socket
     |> assign(:page_title, gettext("Create Classroom"))
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"classroom" => classroom_params}, socket) do
    changeset =
      %Classroom{}
      |> Classrooms.change_classroom(classroom_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"classroom" => classroom_params}, socket) do
    user = socket.assigns.current_scope.current_user

    params =
      classroom_params
      |> Map.put("teacher_id", user.id)

    case Classrooms.create_classroom(params) do
      {:ok, classroom} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Classroom created successfully!"))
         |> push_navigate(to: ~p"/teacher/classrooms/#{classroom.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-2xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/teacher/classrooms"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Classrooms")}
          </.link>
          <h1 class="text-3xl font-bold text-base-content">{gettext("Create Classroom")}</h1>
          <p class="text-secondary mt-1">{gettext("Set up a new classroom for your students")}</p>
        </div>

        <%!-- Form --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <.form for={@form} id="classroom-form" phx-change="validate" phx-submit="save">
              <div class="space-y-6">
                <%!-- Name --%>
                <div class="form-control">
                  <.input
                    field={@form[:name]}
                    type="text"
                    label={gettext("Classroom Name")}
                    placeholder={gettext("e.g., N5 Vocabulary Class")}
                    required
                  />
                  <p class="text-sm text-secondary mt-1">
                    {gettext("Choose a descriptive name for your classroom")}
                  </p>
                </div>

                <%!-- Slug (auto-generated from name) --%>
                <div class="form-control">
                  <.input
                    field={@form[:slug]}
                    type="text"
                    label={gettext("URL Slug (optional)")}
                    placeholder={gettext("auto-generated-from-name")}
                  />
                  <p class="text-sm text-secondary mt-1">
                    {gettext("Used in the URL. Leave blank to auto-generate from the name.")}
                  </p>
                </div>

                <%!-- Description --%>
                <div class="form-control">
                  <.input
                    field={@form[:description]}
                    type="textarea"
                    label={gettext("Description")}
                    rows="4"
                    placeholder={gettext("Describe what students will learn in this classroom...")}
                  />
                </div>

                <%!-- Actions --%>
                <div class="flex items-center gap-4 pt-4 border-t border-base-200">
                  <button type="submit" class="btn btn-primary">
                    {gettext("Create Classroom")}
                  </button>
                  <.link navigate={~p"/teacher/classrooms"} class="btn btn-ghost">
                    {gettext("Cancel")}
                  </.link>
                </div>
              </div>
            </.form>
          </div>
        </div>

        <%!-- Tips --%>
        <div class="mt-8 bg-info/10 rounded-xl p-6 border border-info/20">
          <h3 class="text-sm font-semibold text-info mb-3 flex items-center gap-2">
            <.icon name="hero-light-bulb" class="w-4 h-4" /> {gettext("Tips for a great classroom")}
          </h3>
          <ul class="text-sm text-info/80 space-y-2">
            <li>• {gettext("Use a clear, descriptive name that students will recognize")}</li>
            <li>• {gettext("Write a detailed description explaining the learning goals")}</li>
            <li>• {gettext("You'll get an invite code to share with students after creation")}</li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
