defmodule MedoruWeb.Teacher.TestLive.New do
  @moduledoc """
  LiveView for creating a new teacher test.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Tests
  alias Medoru.Tests.Test

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.current_user

    # Only teachers and admins can access
    if user.type not in ["teacher", "admin"] do
      {:ok,
       socket
       |> put_flash(:error, gettext("Only teachers can create tests."))
       |> push_navigate(to: ~p"/")}
    else
      changeset = Tests.change_teacher_test(%Test{})

      {:ok,
       socket
       |> assign(:page_title, gettext("Create Test"))
       |> assign(:form, to_form(changeset))
       |> assign(:current_user, user)}
    end
  end

  @impl true
  def handle_event("validate", %{"test" => test_params}, socket) do
    changeset =
      %Test{}
      |> Tests.change_teacher_test(test_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"test" => test_params}, socket) do
    user = socket.assigns.current_user

    case Tests.create_teacher_test(test_params, user.id) do
      {:ok, test} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Test created! Now let's add some steps."))
         |> push_navigate(to: ~p"/teacher/tests/#{test.id}/edit")}

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
            navigate={~p"/teacher/tests"}
            class="text-secondary hover:text-primary text-sm flex items-center gap-1 mb-4 transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to My Tests")}
          </.link>

          <h1 class="text-3xl font-bold text-base-content">{gettext("Create New Test")}</h1>
          <p class="text-secondary mt-1">{gettext("Set up the basic test information")}</p>
        </div>

        <%!-- Form --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <.form
              for={@form}
              id="test-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-6"
            >
              <%!-- Title --%>
              <div>
                <label class="label" for={@form[:title].id}>
                  <span class="label-text">{gettext("Test Title")}</span>
                </label>
                <.input
                  field={@form[:title]}
                  type="text"
                  placeholder={gettext("e.g., N5 Vocabulary Quiz")}
                  class="w-full"
                  phx-debounce="300"
                />
              </div>

              <%!-- Description --%>
              <div>
                <label class="label" for={@form[:description].id}>
                  <span class="label-text">
                    {gettext("Description")} <span class="text-secondary text-sm font-normal">({gettext("optional")})</span>
                  </span>
                </label>
                <.input
                  field={@form[:description]}
                  type="textarea"
                  placeholder={gettext("Describe what this test covers...")}
                  rows="3"
                  class="w-full"
                  phx-debounce="300"
                />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <%!-- Time Limit --%>
                <div>
                  <label class="label" for={@form[:time_limit_seconds].id}>
                    <span class="label-text">
                      {gettext("Time Limit")} <span class="text-secondary text-sm font-normal">({gettext("optional")})</span>
                    </span>
                  </label>
                  <.input
                    field={@form[:time_limit_seconds]}
                    type="select"
                    options={time_limit_options()}
                    prompt={gettext("No time limit")}
                    class="w-full"
                  />
                  <p class="text-xs text-secondary mt-1">
                    {gettext("Students must complete within this time")}
                  </p>
                </div>

                <%!-- Max Attempts --%>
                <div>
                  <label class="label" for={@form[:max_attempts].id}>
                    <span class="label-text">
                      {gettext("Max Attempts")} <span class="text-secondary text-sm font-normal">({gettext("optional")})</span>
                    </span>
                  </label>
                  <.input
                    field={@form[:max_attempts]}
                    type="select"
                    options={max_attempts_options()}
                    prompt={gettext("Unlimited")}
                    class="w-full"
                  />
                  <p class="text-xs text-secondary mt-1">
                    {gettext("How many times each student can take it")}
                  </p>
                </div>
              </div>

              <%!-- Info Box --%>
              <div class="bg-info/10 border border-info/30 rounded-xl p-4 flex gap-3">
                <.icon name="hero-information-circle" class="w-5 h-5 text-info flex-shrink-0 mt-0.5" />
                <div class="text-sm text-base-content">
                  <p class="font-medium mb-1">{gettext("What's next?")}</p>
                  <p class="text-secondary">
                    {gettext("After creating the test, you'll add steps (questions). Each step can be multiple choice, typing, or kanji writing.")}
                  </p>
                </div>
              </div>

              <%!-- Submit Buttons --%>
              <div class="flex justify-end gap-3 pt-4 border-t border-base-200">
                <.link navigate={~p"/teacher/tests"}>
                  <button type="button" class="btn btn-ghost">
                    {gettext("Cancel")}
                  </button>
                </.link>
                <button type="submit" class="btn btn-primary" disabled={!@form.source.valid?}>
                  <.icon name="hero-plus" class="w-4 h-4 mr-2" /> {gettext("Create Test")}
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp time_limit_options do
    [
      {"1 minute", 60},
      {"5 minutes", 300},
      {"10 minutes", 600},
      {"15 minutes", 900},
      {"20 minutes", 1200},
      {"30 minutes", 1800},
      {"45 minutes", 2700},
      {"1 hour", 3600},
      {"1.5 hours", 5400},
      {"2 hours", 7200}
    ]
  end

  defp max_attempts_options do
    [
      {"1 attempt", 1},
      {"2 attempts", 2},
      {"3 attempts", 3},
      {"5 attempts", 5},
      {"10 attempts", 10}
    ]
  end
end
