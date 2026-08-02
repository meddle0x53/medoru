defmodule MedoruWeb.WordBookLive.Design do
  @moduledoc """
  LiveView for designing a word book's vocabulary cards.

  Lets the owner pick the card shape, daisyUI theme, per-side (front/back)
  display options and card backgrounds, with a live preview rendered from the
  in-memory configuration. Saving persists everything through
  `Medoru.Learning.WordBooks.update_word_book/2`.
  """
  use MedoruWeb, :live_view

  alias Medoru.Classrooms.Classroom
  alias Medoru.Learning.WordBooks
  alias MedoruWeb.WordBookCard

  @locales ~w(en bg ja)

  # daisyUI themes hidden from the word book theme picker (e.g. themes
  # whose palette makes card text unreadable). Names must match
  # `Medoru.Classrooms.Classroom.allowed_themes/0`.
  @excluded_themes ~w(cyberpunk aqua acid retro coffee night wireframe cupcake pastel luxury black)

  @display_options [
    {"show_image", gettext("Picture")},
    {"show_sound", gettext("Sound")},
    {"show_reading", gettext("Reading")},
    {"show_level", gettext("N Level")},
    {"show_frequency", gettext("Frequency")}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Design Word Book"))
     |> assign(:display_options, @display_options)
     |> assign(:locales, @locales)
     |> assign(:themes, Classroom.allowed_themes() -- @excluded_themes)
     |> assign(:background_options, WordBooks.background_options())
     |> assign(:cover_background_options, WordBooks.cover_background_options())}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    user = socket.assigns.current_scope.current_user
    word_book = WordBooks.get_user_word_book(user.id, id)

    if is_nil(word_book) do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have permission to edit this word book."))
       |> push_navigate(to: ~p"/words/books")}
    else
      preview_word =
        case word_book.word_book_words do
          [first | _] -> first.word
          [] -> nil
        end

      {:noreply,
       socket
       |> assign(:page_title, gettext("Design: %{title}", title: word_book.title))
       |> assign(:word_book, word_book)
       |> assign(:preview_word, preview_word)
       |> assign(:active_side, "front")
       |> assign(:card_shape, word_book.card_shape || "rectangle")
       |> assign(:selected_theme, word_book.theme || "")
       |> assign(:front_background, word_book.front_background || "")
       |> assign(:back_background, word_book.back_background || "")
       |> assign(:front_config, word_book.front_config || %{})
       |> assign(:back_config, word_book.back_config || %{})}
    end
  end

  @impl true
  def handle_event("switch_side", %{"side" => side}, socket) when side in ["front", "back"] do
    {:noreply, assign(socket, :active_side, side)}
  end

  def handle_event("toggle_option", %{"side" => side, "key" => key}, socket) do
    config = side_config(socket, side)
    updated = Map.put(config, key, not show?(config, key))

    {:noreply, assign_side_config(socket, side, updated)}
  end

  def handle_event(
        "toggle_locale",
        %{"side" => side, "group" => group, "locale" => locale},
        socket
      )
      when group in ["meanings", "examples"] and locale in @locales do
    config = side_config(socket, side)

    locales =
      config
      |> Map.get(group, [])
      |> List.wrap()
      |> toggle_locale(locale)

    {:noreply, assign_side_config(socket, side, Map.put(config, group, locales))}
  end

  def handle_event("set_example_count", %{"side" => side, "example_count" => count}, socket) do
    count =
      case count do
        "1" -> 1
        "2" -> 2
        _ -> "all"
      end

    config = side_config(socket, side)
    {:noreply, assign_side_config(socket, side, Map.put(config, "example_count", count))}
  end

  def handle_event("select_background", %{"side" => side, "background" => key}, socket) do
    {:noreply, assign(socket, background_assign(side), key)}
  end

  def handle_event("select_shape", %{"shape" => shape}, socket)
      when shape in ["square", "rectangle"] do
    {:noreply, assign(socket, :card_shape, shape)}
  end

  def handle_event("select_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :selected_theme, theme)}
  end

  def handle_event("save", _params, socket) do
    attrs = %{
      "card_shape" => socket.assigns.card_shape,
      "theme" => nil_if_empty(socket.assigns.selected_theme),
      "front_background" => nil_if_empty(socket.assigns.front_background),
      "back_background" => nil_if_empty(socket.assigns.back_background),
      "front_config" => normalize_side_config(socket.assigns.front_config),
      "back_config" => normalize_side_config(socket.assigns.back_config)
    }

    case WordBooks.update_word_book(socket.assigns.word_book, attrs) do
      {:ok, word_book} ->
        {:noreply,
         socket
         |> assign(:word_book, word_book)
         |> put_flash(:info, gettext("Design saved."))}

      {:error, %Ecto.Changeset{} = changeset} ->
        message =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
          |> Enum.join(", ")

        {:noreply,
         put_flash(socket, :error, gettext("Could not save design: %{errors}", errors: message))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <.link
              navigate={~p"/words/books"}
              class="inline-flex items-center gap-1 text-secondary hover:text-primary text-sm mb-2 transition-colors"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4" /> {gettext("Back to Word Books")}
            </.link>
            <h1 class="text-2xl font-bold text-base-content">{@page_title}</h1>
            <p class="text-secondary mt-1">
              {gettext("Customize how the vocabulary cards in this book look.")}
            </p>
          </div>
          <button type="button" phx-click="save" class="btn btn-primary shrink-0">
            <.icon name="hero-check" class="w-4 h-4" /> {gettext("Save design")}
          </button>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <%!-- Controls --%>
          <div class="space-y-6">
            <%!-- Book-level: shape & theme --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-base">{gettext("Card Style")}</h2>

                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Card Shape")}
                  </label>
                  <div class="flex gap-2">
                    <button
                      type="button"
                      phx-click="select_shape"
                      phx-value-shape="square"
                      class={[
                        "btn btn-sm",
                        if(@card_shape == "square", do: "btn-primary", else: "btn-ghost")
                      ]}
                    >
                      {gettext("Square")}
                    </button>
                    <button
                      type="button"
                      phx-click="select_shape"
                      phx-value-shape="rectangle"
                      class={[
                        "btn btn-sm",
                        if(@card_shape == "rectangle", do: "btn-primary", else: "btn-ghost")
                      ]}
                    >
                      {gettext("Rectangle")}
                    </button>
                  </div>
                </div>

                <div class="pt-2">
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Theme")}
                  </label>
                  <div class="grid grid-cols-4 sm:grid-cols-6 gap-2">
                    <button
                      type="button"
                      phx-click="select_theme"
                      phx-value-theme=""
                      class={[
                        "btn btn-xs btn-outline",
                        if(@selected_theme == "", do: "btn-primary", else: "")
                      ]}
                    >
                      {gettext("Default")}
                    </button>
                    <%= for theme <- @themes do %>
                      <button
                        type="button"
                        phx-click="select_theme"
                        phx-value-theme={theme}
                        class={[
                          "btn btn-xs",
                          if(@selected_theme == theme, do: "btn-primary", else: "btn-ghost")
                        ]}
                      >
                        {theme}
                      </button>
                    <% end %>
                  </div>
                  <p class="text-xs text-secondary mt-1">
                    {gettext("Choose a visual theme for the cards. Default uses the site colors.")}
                  </p>
                </div>
              </div>
            </div>

            <%!-- Front/Back tabs --%>
            <div role="tablist" class="tabs tabs-boxed">
              <button
                type="button"
                role="tab"
                phx-click="switch_side"
                phx-value-side="front"
                class={["tab", if(@active_side == "front", do: "tab-active", else: "")]}
              >
                {gettext("Front")}
              </button>
              <button
                type="button"
                role="tab"
                phx-click="switch_side"
                phx-value-side="back"
                class={["tab", if(@active_side == "back", do: "tab-active", else: "")]}
              >
                {gettext("Back")}
              </button>
            </div>

            <% current_config = side_config(assigns) %>
            <% current_background = current_background(assigns) %>

            <%!-- Per-side display options --%>
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-base">
                  <%= if @active_side == "front" do %>
                    {gettext("Front Side")}
                  <% else %>
                    {gettext("Back Side")}
                  <% end %>
                </h2>

                <%!-- Display checkboxes --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Show on Card")}
                  </label>
                  <div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
                    <%= for {key, label} <- @display_options do %>
                      <label class="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={show?(current_config, key)}
                          phx-click="toggle_option"
                          phx-value-side={@active_side}
                          phx-value-key={key}
                          class="checkbox checkbox-primary checkbox-sm"
                        />
                        <span class="text-sm text-base-content">{label}</span>
                      </label>
                    <% end %>
                  </div>
                </div>

                <%!-- Meanings locale group --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Meanings")}
                  </label>
                  <div class="flex gap-4">
                    <%= for locale <- @locales do %>
                      <label class="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={locale in config_locales(current_config, "meanings")}
                          phx-click="toggle_locale"
                          phx-value-side={@active_side}
                          phx-value-group="meanings"
                          phx-value-locale={locale}
                          class="checkbox checkbox-primary checkbox-sm"
                        />
                        <span class="text-sm text-base-content uppercase">{locale}</span>
                      </label>
                    <% end %>
                  </div>
                </div>

                <%!-- Examples locale group + count --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Examples")}
                  </label>
                  <div class="flex flex-wrap items-center gap-4">
                    <%= for locale <- @locales do %>
                      <label class="flex items-center gap-2 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={locale in config_locales(current_config, "examples")}
                          phx-click="toggle_locale"
                          phx-value-side={@active_side}
                          phx-value-group="examples"
                          phx-value-locale={locale}
                          class="checkbox checkbox-primary checkbox-sm"
                        />
                        <span class="text-sm text-base-content uppercase">{locale}</span>
                      </label>
                    <% end %>
                    <select
                      phx-change="set_example_count"
                      phx-value-side={@active_side}
                      name="example_count"
                      class="select select-bordered select-sm"
                    >
                      <option value="1" selected={example_count_value(current_config) == "1"}>
                        {gettext("1 example")}
                      </option>
                      <option value="2" selected={example_count_value(current_config) == "2"}>
                        {gettext("2 examples")}
                      </option>
                      <option value="all" selected={example_count_value(current_config) == "all"}>
                        {gettext("All examples")}
                      </option>
                    </select>
                  </div>
                </div>

                <%!-- Background picker --%>
                <div>
                  <label class="block text-sm font-medium text-base-content mb-2">
                    {gettext("Card Background")}
                  </label>
                  <div class="grid grid-cols-3 sm:grid-cols-4 gap-2">
                    <button
                      type="button"
                      phx-click="select_background"
                      phx-value-side={@active_side}
                      phx-value-background=""
                      class={[
                        "flex flex-col items-center gap-1 p-2 rounded-lg border-2 transition-colors",
                        if(current_background == "",
                          do: "border-primary bg-primary/5",
                          else: "border-base-300 hover:border-primary/50"
                        )
                      ]}
                    >
                      <div class="w-full h-12 bg-base-200 rounded flex items-center justify-center">
                        <.icon name="hero-x-mark" class="w-5 h-5 text-secondary" />
                      </div>
                      <span class="text-xs text-secondary text-center">{gettext("None")}</span>
                    </button>
                    <button
                      type="button"
                      phx-click="select_background"
                      phx-value-side={@active_side}
                      phx-value-background="word_image"
                      class={[
                        "flex flex-col items-center gap-1 p-2 rounded-lg border-2 transition-colors",
                        if(current_background == "word_image",
                          do: "border-primary bg-primary/5",
                          else: "border-base-300 hover:border-primary/50"
                        )
                      ]}
                    >
                      <%= if @preview_word && @preview_word.image_path do %>
                        <img
                          src={@preview_word.image_path}
                          alt={gettext("Word image")}
                          class="w-full h-12 object-cover rounded"
                        />
                      <% else %>
                        <div class="w-full h-12 bg-base-200 rounded flex items-center justify-center">
                          <.icon name="hero-photo" class="w-5 h-5 text-secondary" />
                        </div>
                      <% end %>
                      <span class="text-xs text-secondary text-center">{gettext("Word image")}</span>
                    </button>
                    <%= for {key, label, path} <- @background_options do %>
                      <button
                        type="button"
                        phx-click="select_background"
                        phx-value-side={@active_side}
                        phx-value-background={key}
                        class={[
                          "flex flex-col items-center gap-1 p-2 rounded-lg border-2 transition-colors",
                          if(current_background == key,
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
                  <p class="text-xs text-secondary mt-3 mb-2">{gettext("Book covers")}</p>
                  <div class="grid grid-cols-3 sm:grid-cols-4 gap-2">
                    <%= for {key, label, path} <- @cover_background_options do %>
                      <button
                        type="button"
                        phx-click="select_background"
                        phx-value-side={@active_side}
                        phx-value-background={key}
                        class={[
                          "flex flex-col items-center gap-1 p-2 rounded-lg border-2 transition-colors",
                          if(current_background == key,
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
              </div>
            </div>
          </div>

          <%!-- Live preview --%>
          <div>
            <div
              data-theme={if @selected_theme == "", do: nil, else: @selected_theme}
              class="bg-base-200 border border-base-300 rounded-2xl p-6 sm:p-10"
            >
              <p class="text-xs uppercase tracking-wide text-secondary mb-4 text-center">
                {gettext("Preview — click the card to flip it")}
              </p>
              <%= if @preview_word do %>
                <div
                  id="word-book-design-preview-container"
                  phx-hook="WordBookCards"
                  data-card-shape={@card_shape}
                  class={
                    if(@card_shape == "square", do: "max-w-md mx-auto", else: "max-w-xs mx-auto")
                  }
                >
                  <WordBookCard.card
                    id="word-book-design-preview"
                    word={@preview_word}
                    front_config={@front_config}
                    back_config={@back_config}
                    card_shape={@card_shape}
                    front_background={@front_background}
                    back_background={@back_background}
                  />
                </div>
              <% else %>
                <div class="text-center py-12">
                  <.icon name="hero-rectangle-stack" class="w-12 h-12 text-secondary mx-auto mb-3" />
                  <p class="text-base-content font-medium mb-1">
                    {gettext("This book has no words yet.")}
                  </p>
                  <p class="text-secondary text-sm mb-4">
                    {gettext("Add words to see a live preview of your design.")}
                  </p>
                  <.link
                    navigate={~p"/words/books/#{@word_book.id}/edit-words"}
                    class="btn btn-primary btn-sm"
                  >
                    {gettext("Add Words")}
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- Event helpers ---

  defp side_config(socket, "front"), do: socket.assigns.front_config
  defp side_config(socket, "back"), do: socket.assigns.back_config

  defp assign_side_config(socket, "front", config), do: assign(socket, :front_config, config)
  defp assign_side_config(socket, "back", config), do: assign(socket, :back_config, config)

  defp background_assign("front"), do: :front_background
  defp background_assign("back"), do: :back_background

  # --- Template helpers ---

  defp side_config(assigns) do
    if assigns.active_side == "front", do: assigns.front_config, else: assigns.back_config
  end

  defp current_background(assigns) do
    if assigns.active_side == "front",
      do: assigns.front_background,
      else: assigns.back_background
  end

  defp show?(config, key), do: Map.get(config || %{}, key, false) == true

  defp config_locales(config, key) do
    config
    |> Kernel.||(%{})
    |> Map.get(key, [])
    |> List.wrap()
  end

  defp example_count_value(config) do
    case Map.get(config || %{}, "example_count") do
      1 -> "1"
      "1" -> "1"
      2 -> "2"
      "2" -> "2"
      _ -> "all"
    end
  end

  # --- Save helpers ---

  defp nil_if_empty(nil), do: nil
  defp nil_if_empty(""), do: nil
  defp nil_if_empty(value), do: value

  defp toggle_locale(locales, locale) do
    locales =
      if locale in locales do
        List.delete(locales, locale)
      else
        [locale | locales]
      end

    Enum.sort_by(locales, &Enum.find_index(@locales, fn l -> l == &1 end))
  end

  # Builds a config map with exactly the keys the schema validates.
  defp normalize_side_config(config) do
    config = config || %{}

    %{
      "show_image" => show?(config, "show_image"),
      "show_sound" => show?(config, "show_sound"),
      "show_reading" => show?(config, "show_reading"),
      "show_level" => show?(config, "show_level"),
      "show_frequency" => show?(config, "show_frequency"),
      "meanings" => config |> config_locales("meanings") |> Enum.filter(&(&1 in @locales)),
      "examples" => config |> config_locales("examples") |> Enum.filter(&(&1 in @locales)),
      "example_count" => normalize_example_count(Map.get(config, "example_count"))
    }
  end

  defp normalize_example_count(1), do: 1
  defp normalize_example_count("1"), do: 1
  defp normalize_example_count(2), do: 2
  defp normalize_example_count("2"), do: 2
  defp normalize_example_count(_), do: "all"
end
