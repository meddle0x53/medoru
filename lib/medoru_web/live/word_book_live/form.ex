defmodule MedoruWeb.WordBookLive.Form do
  @moduledoc """
  LiveView for creating and editing word books.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Learning.{WordBooks, WordBook}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("New Word Book"))
     |> assign(:cover_options, WordBooks.cover_options())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case socket.assigns.live_action do
      :new ->
        changeset = WordBooks.change_word_book(%WordBook{}, %{})

        {:noreply,
         socket
         |> assign(:page_title, gettext("New Word Book"))
         |> assign(:word_book, nil)
         |> assign(:selected_cover, "")
         |> assign(:form, to_form(changeset))}

      :edit ->
        user = socket.assigns.current_scope.current_user
        word_book = WordBooks.get_user_word_book(user.id, params["id"])

        if is_nil(word_book) do
          {:noreply,
           socket
           |> put_flash(:error, gettext("You don't have permission to edit this word book."))
           |> push_navigate(to: ~p"/words/books")}
        else
          changeset = WordBooks.change_word_book(word_book, %{})

          {:noreply,
           socket
           |> assign(:page_title, gettext("Edit Word Book"))
           |> assign(:word_book, word_book)
           |> assign(:selected_cover, word_book.cover_image || "")
           |> assign(:form, to_form(changeset))}
        end
    end
  end

  @impl true
  def handle_event("validate", %{"word_book" => word_book_params}, socket) do
    # For validation, we need to include user_id to avoid "can't be blank" errors
    # but we don't actually validate the user_id, just silence the error
    user = socket.assigns.current_scope.current_user

    changeset =
      case socket.assigns.word_book do
        nil ->
          WordBook.changeset(%WordBook{}, Map.put(word_book_params, "user_id", user.id))

        word_book ->
          WordBook.changeset(word_book, word_book_params)
      end

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("select_cover", %{"cover" => cover}, socket) do
    {:noreply, assign(socket, :selected_cover, cover)}
  end

  @impl true
  def handle_event("save", %{"word_book" => word_book_params}, socket) do
    user = socket.assigns.current_scope.current_user

    case socket.assigns.word_book do
      nil ->
        # Create new
        attrs = Map.put(word_book_params, "user_id", user.id)

        case WordBooks.create_word_book(attrs) do
          {:ok, word_book} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Word book created successfully."))
             |> push_navigate(to: ~p"/words/books/#{word_book.id}/edit-words")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      word_book ->
        # Update existing
        case WordBooks.update_word_book(word_book, word_book_params) do
          {:ok, _word_book} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Word book updated successfully."))
             |> push_navigate(to: ~p"/words/books")}

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
            <%= if @word_book do %>
              {gettext("Update your word book details.")}
            <% else %>
              {gettext("Create a new vocabulary card collection.")}
            <% end %>
          </p>
        </div>

        <%!-- Form --%>
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
              <%!-- Title Field --%>
              <div>
                <label class="block text-sm font-medium text-base-content mb-2">
                  {gettext("Title")} <span class="text-error">*</span>
                </label>
                <input
                  type="text"
                  name={@form[:title].name}
                  value={@form[:title].value}
                  placeholder={gettext("e.g., JLPT N3 Verbs")}
                  maxlength="100"
                  class={[
                    "w-full px-4 py-2 bg-base-100 border rounded-lg text-base-content placeholder-secondary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent",
                    if(@form[:title].errors != [], do: "border-error", else: "border-base-300")
                  ]}
                />
                <div class="flex justify-between mt-1">
                  <%= if @form[:title].errors != [] do %>
                    <% {error_msg, _} = hd(@form[:title].errors) %>
                    <span class="text-error text-sm">{error_msg}</span>
                  <% else %>
                    <span></span>
                  <% end %>
                  <span class="text-secondary text-sm">
                    {String.length(@form[:title].value || "")}/100
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
                  placeholder={gettext("Optional description of this word book...")}
                  maxlength="500"
                  rows="3"
                  class={[
                    "w-full px-4 py-2 bg-base-100 border rounded-lg text-base-content placeholder-secondary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent resize-none",
                    if(@form[:description].errors != [],
                      do: "border-error",
                      else: "border-base-300"
                    )
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

              <%!-- Cover Image Picker --%>
              <div>
                <label class="block text-sm font-medium text-base-content mb-2">
                  {gettext("Cover Image")}
                </label>
                <input type="hidden" name={@form[:cover_image].name} value={@selected_cover} />
                <div class="grid grid-cols-3 sm:grid-cols-4 gap-2">
                  <%!-- Default (first card) option --%>
                  <button
                    type="button"
                    phx-click="select_cover"
                    phx-value-cover=""
                    class={[
                      "flex flex-col items-center gap-1 p-2 rounded-lg border-2 transition-colors",
                      if(@selected_cover == "",
                        do: "border-primary bg-primary/5",
                        else: "border-base-300 hover:border-primary/50"
                      )
                    ]}
                  >
                    <div class="w-full h-12 bg-base-200 rounded flex items-center justify-center">
                      <.icon name="hero-rectangle-stack" class="w-6 h-6 text-secondary" />
                    </div>
                    <span class="text-xs text-secondary text-center">
                      {gettext("Default (first card)")}
                    </span>
                  </button>
                  <%= for {key, label, path} <- @cover_options do %>
                    <button
                      type="button"
                      phx-click="select_cover"
                      phx-value-cover={key}
                      class={[
                        "flex flex-col items-center gap-1 p-2 rounded-lg border-2 transition-colors",
                        if(@selected_cover == key,
                          do: "border-primary bg-primary/5",
                          else: "border-base-300 hover:border-primary/50"
                        )
                      ]}
                    >
                      <img src={path} alt={label} class="w-full h-12 object-cover rounded" />
                      <span class="text-xs text-secondary text-center">{label}</span>
                    </button>
                  <% end %>
                </div>
              </div>

              <%!-- Actions --%>
              <div class="flex flex-col sm:flex-row gap-3 pt-4">
                <button
                  type="submit"
                  class="flex-1 px-6 py-3 bg-primary hover:bg-primary/90 text-primary-content rounded-lg font-medium transition-colors"
                >
                  <%= if @word_book do %>
                    {gettext("Save Changes")}
                  <% else %>
                    {gettext("Create & Add Words")}
                  <% end %>
                </button>
                <.link
                  navigate={~p"/words/books"}
                  class="px-6 py-3 bg-base-200 hover:bg-base-300 text-base-content rounded-lg font-medium text-center transition-colors"
                >
                  {gettext("Cancel")}
                </.link>
              </div>
            </.form>
          </div>
        </div>

        <%!-- Info Box --%>
        <%= if !@word_book do %>
          <div class="mt-6 p-4 bg-info/10 rounded-lg">
            <div class="flex items-start gap-3">
              <.icon name="hero-information-circle" class="w-5 h-5 text-info mt-0.5" />
              <div class="text-sm text-info-content">
                <p class="font-medium mb-1">{gettext("What's next?")}</p>
                <p>
                  {gettext(
                    "After creating your word book, you'll be able to add up to 100 words from our vocabulary database and design how the cards look."
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
