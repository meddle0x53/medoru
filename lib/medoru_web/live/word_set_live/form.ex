defmodule MedoruWeb.WordSetLive.Form do
  @moduledoc """
  LiveView for creating and editing word sets.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Learning.{WordSets, WordSet}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("New Word Set"))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case socket.assigns.live_action do
      :new ->
        changeset = WordSet.changeset(%WordSet{}, %{})

        {:noreply,
         socket
         |> assign(:page_title, gettext("New Word Set"))
         |> assign(:word_set, nil)
         |> assign(:form, to_form(changeset))}

      :edit ->
        user = socket.assigns.current_scope.current_user
        word_set = WordSets.get_word_set!(params["id"])

        # Ensure user owns this word set
        if word_set.user_id != user.id do
          {:noreply,
           socket
           |> put_flash(:error, gettext("You don't have permission to edit this word set."))
           |> push_navigate(to: ~p"/words/sets")}
        else
          changeset = WordSet.changeset(word_set, %{})

          {:noreply,
           socket
           |> assign(:page_title, gettext("Edit Word Set"))
           |> assign(:word_set, word_set)
           |> assign(:form, to_form(changeset))}
        end
    end
  end

  @impl true
  def handle_event("validate", %{"word_set" => word_set_params}, socket) do
    # For validation, we need to include user_id to avoid "can't be blank" errors
    # but we don't actually validate the user_id, just silence the error
    user = socket.assigns.current_scope.current_user

    changeset =
      case socket.assigns.word_set do
        nil ->
          WordSet.changeset(%WordSet{}, Map.put(word_set_params, "user_id", user.id))

        word_set ->
          WordSet.changeset(word_set, word_set_params)
      end

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"word_set" => word_set_params}, socket) do
    user = socket.assigns.current_scope.current_user

    case socket.assigns.word_set do
      nil ->
        # Create new
        attrs = Map.put(word_set_params, "user_id", user.id)

        case WordSets.create_word_set(attrs) do
          {:ok, word_set} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Word set created successfully."))
             |> push_navigate(to: ~p"/words/sets/#{word_set.id}/edit-words")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      word_set ->
        # Update existing
        case WordSets.update_word_set(word_set, word_set_params) do
          {:ok, word_set} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Word set updated successfully."))
             |> push_navigate(to: ~p"/words/sets/#{word_set.id}")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-base-content">{@page_title}</h1>
          <p class="text-secondary mt-2">
            <%= if @word_set do %>
              {gettext("Update your word set details.")}
            <% else %>
              {gettext("Create a new collection of words for focused study.")}
            <% end %>
          </p>
        </div>

        <%!-- Form --%>
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
              <%!-- Name Field --%>
              <div>
                <label class="block text-sm font-medium text-base-content mb-2">
                  {gettext("Name")} <span class="text-error">*</span>
                </label>
                <input
                  type="text"
                  name={@form[:name].name}
                  value={@form[:name].value}
                  placeholder={gettext("e.g., JLPT N3 Verbs")}
                  maxlength="100"
                  class={[
                    "w-full px-4 py-2 bg-base-100 border rounded-lg text-base-content placeholder-secondary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent",
                    if(@form[:name].errors != [], do: "border-error", else: "border-base-300")
                  ]}
                />
                <div class="flex justify-between mt-1">
                  <%= if @form[:name].errors != [] do %>
                    <% {error_msg, _} = hd(@form[:name].errors) %>
                    <span class="text-error text-sm">{error_msg}</span>
                  <% else %>
                    <span></span>
                  <% end %>
                  <span class="text-secondary text-sm">
                    {String.length(@form[:name].value || "")}/100
                  </span>
                </div>
              </div>

              <%!-- Description Field --%>
              <div>
                <label class="block text-sm font-medium text-base-content mb-2">
                  {gettext("Description")}
                </label>
                <textarea
                  name={@form[:description].name}
                  value={@form[:description].value}
                  placeholder={gettext("Optional description of this word set...")}
                  maxlength="500"
                  rows="3"
                  class={[
                    "w-full px-4 py-2 bg-base-100 border rounded-lg text-base-content placeholder-secondary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent resize-none",
                    if(@form[:description].errors != [], do: "border-error", else: "border-base-300")
                  ]}
                >{(@form[:description].value || "")}</textarea>
                <div class="flex justify-between mt-1">
                  <%= if @form[:description].errors != [] do %>
                    <% {error_msg, _} = hd(@form[:description].errors) %>
                    <span class="text-error text-sm">{error_msg}</span>
                  <% else %>
                    <span></span>
                  <% end %>
                  <span class="text-secondary text-sm">
                    {String.length(@form[:description].value || "")}/500
                  </span>
                </div>
              </div>

              <%!-- Actions --%>
              <div class="flex flex-col sm:flex-row gap-3 pt-4">
                <button
                  type="submit"
                  class="flex-1 px-6 py-3 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors"
                >
                  <%= if @word_set do %>
                    {gettext("Save Changes")}
                  <% else %>
                    {gettext("Create & Add Words")}
                  <% end %>
                </button>
                <.link
                  navigate={if @word_set, do: ~p"/words/sets/#{@word_set.id}", else: ~p"/words/sets"}
                  class="px-6 py-3 bg-base-200 hover:bg-base-300 text-base-content rounded-lg font-medium text-center transition-colors"
                >
                  {gettext("Cancel")}
                </.link>
              </div>
            </.form>
          </div>
        </div>

        <%!-- Info Box --%>
        <%= if !@word_set do %>
          <div class="mt-6 p-4 bg-info/10 rounded-lg">
            <div class="flex items-start gap-3">
              <.icon name="hero-information-circle" class="w-5 h-5 text-info mt-0.5" />
              <div class="text-sm text-info-content">
                <p class="font-medium mb-1">{gettext("What's next?")}</p>
                <p>
                  {gettext(
                    "After creating your word set, you'll be able to add up to 100 words from our vocabulary database. You can then create a practice test with customizable question types."
                  )}
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
