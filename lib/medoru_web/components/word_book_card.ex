defmodule MedoruWeb.WordBookCard do
  @moduledoc """
  Shared vocabulary-card component for Word Books.

  Renders one flippable vocabulary card (CSS 3D flip, no server round trip)
  with per-side display configuration driven by a word book's
  `front_config` / `back_config` maps.

  Optionally renders per-face "download as PNG" buttons via the
  `ShareAsPicture` hook when `download` is true.
  """
  use MedoruWeb, :html

  alias Medoru.Content
  alias Medoru.Content.Word
  alias Medoru.Learning.WordBooks

  @locales ~w(en bg ja)

  attr :id, :string, required: true
  attr :word, :any, required: true, doc: "a `%Medoru.Content.Word{}`"
  attr :front_config, :map, default: %{}
  attr :back_config, :map, default: %{}
  attr :card_shape, :string, default: "rectangle", values: ~w(square rectangle)
  attr :front_background, :string, default: nil, doc: "background image path or nil"
  attr :back_background, :string, default: nil, doc: "background image path or nil"
  attr :download, :boolean, default: false, doc: "render per-face PNG download buttons"

  @doc """
  Renders one flippable vocabulary card for the given word.
  """
  def card(assigns) do
    ~H"""
    <div class="relative">
      <div class="word-book-card">
        <div
          id={"#{@id}-inner"}
          class={["word-book-card-inner", shape_class(@card_shape)]}
          phx-click={JS.toggle_class("word-book-card-flipped")}
        >
          <div
            id={"#{@id}-front"}
            data-share-picture
            class="word-book-card-face relative bg-base-100 text-base-content border border-base-300 shadow-md"
            style={background_style(@front_background)}
          >
            <.level_badge word={@word} config={@front_config} />
            <.card_face
              word={@word}
              config={@front_config}
              shape={@card_shape}
              background={@front_background}
            />
          </div>
          <div
            id={"#{@id}-back"}
            data-share-picture
            class="word-book-card-face word-book-card-face-back relative bg-base-100 text-base-content border border-base-300 shadow-md"
            style={background_style(@back_background)}
          >
            <.level_badge word={@word} config={@back_config} />
            <.card_face
              word={@word}
              config={@back_config}
              shape={@card_shape}
              background={@back_background}
            />
          </div>
        </div>
      </div>
      <%= if @download do %>
        <button
          id={"#{@id}-download"}
          type="button"
          phx-hook="ShareAsPicture"
          data-share-front={"#{@id}-front"}
          data-share-back={"#{@id}-back"}
          data-filename={"medoru-#{@id}"}
          title={gettext("Download card as PNG")}
          class="absolute top-2 right-2 z-20 btn btn-xs btn-primary shadow-md"
          data-share-exclude
        >
          <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
        </button>
      <% end %>
    </div>
    """
  end

  # JLPT level badge pinned to the top-left corner of the face — the
  # mirror position of the download button (top-right) and roughly the
  # same size. Rendered inside the face so it is part of PNG downloads.
  attr :word, :any, required: true
  attr :config, :map, required: true

  defp level_badge(assigns) do
    ~H"""
    <%= if show?(@config, "show_level") && @word.difficulty do %>
      <span class="absolute top-2 left-2 z-10 inline-flex items-center px-2 py-1 bg-primary text-primary-content text-xs font-bold shadow-sm">
        N{@word.difficulty}
      </span>
    <% end %>
    """
  end

  # Site branding rendered as the final content block of every card
  # face, so it is always part of downloaded card images. The pill has
  # its own background so it stays readable over any card background.
  defp watermark(assigns) do
    ~H"""
    <div class="mt-auto w-full pt-3 flex justify-center">
      <span class="px-3 py-1 bg-base-100 border border-base-300 text-sm font-bold tracking-widest text-base-content shadow-sm">
        medoru.net
      </span>
    </div>
    """
  end

  attr :word, :any, required: true
  attr :config, :map, required: true
  attr :shape, :string, required: true
  attr :background, :string, required: true

  defp card_face(assigns) do
    assigns = assign(assigns, :has_content?, side_config_content?(assigns.config))

    ~H"""
    <div class={[
      "h-full w-full flex flex-col items-center justify-center gap-2 p-4 pt-10 text-center",
      if(@background, do: "bg-base-100/80")
    ]}>
      <%= if @has_content? do %>
        <%= if show?(@config, "show_image") && @word.image_path do %>
          <img
            src={@word.image_path}
            alt={@word.text}
            class="max-h-28 w-auto max-w-full object-contain rounded-lg border border-base-300"
            loading="lazy"
          />
        <% end %>

        <div class={[
          "font-medium text-base-content font-japanese leading-tight",
          text_class(@shape)
        ]}>
          {@word.text}
          <%= if show?(@config, "show_reading") && @word.reading do %>
            <span class="text-lg font-normal text-secondary/80">({@word.reading})</span>
          <% end %>
        </div>

        <%= if show?(@config, "show_sound") && @word.pronunciation_path do %>
          <audio
            controls
            class="h-8 w-full max-w-[220px]"
            src={@word.pronunciation_path}
            onclick="event.stopPropagation()"
            data-share-exclude
          >
            {gettext("Your browser does not support the audio element.")}
          </audio>
        <% end %>

        <%= if show?(@config, "show_frequency") && @word.usage_frequency do %>
          <div class="flex items-center justify-center gap-2 flex-wrap">
            <%= if @word.usage_frequency <= 100 do %>
              <span class="px-2 py-0.5 bg-amber-100/80 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300 rounded-full text-xs">
                {gettext("Common word")}
              </span>
            <% else %>
              <span class="text-xs text-secondary">
                {gettext("Freq: %{frequency}", frequency: @word.usage_frequency)}
              </span>
            <% end %>
          </div>
        <% end %>

        <%= for locale <- config_locales(@config, "meanings") do %>
          <div class="w-full">
            <div class="text-[10px] uppercase tracking-wide text-secondary">
              {locale}
            </div>
            <p class="text-sm text-base-content line-clamp-3">
              {meaning_for(@word, locale)}
            </p>
          </div>
        <% end %>

        <%= for example <- example_blocks(@word, @config) do %>
          <div class="w-full">
            <p class="text-sm text-base-content font-japanese line-clamp-3">
              {example.sentence}
            </p>
            <%= for {locale, translation} <- example.translations do %>
              <p class="text-xs text-secondary line-clamp-2">
                <span class="uppercase">{locale}</span>: {translation}
              </p>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <div class={["font-medium text-base-content font-japanese leading-tight", text_class(@shape)]}>
          {@word.text}
        </div>
      <% end %>
      <.watermark />
    </div>
    """
  end

  defp shape_class("square"), do: "aspect-square"
  defp shape_class(_), do: "[aspect-ratio:5/7]"

  defp text_class("square"), do: "text-4xl"
  defp text_class(_), do: "text-5xl"

  defp background_style(nil), do: nil
  defp background_style(""), do: nil
  defp background_style(path), do: "background-image: url('#{path}');"

  defp show?(config, key), do: Map.get(config || %{}, key, false) == true

  # True when any display flag or locale list is enabled for the side.
  defp side_config_content?(config) do
    config = config || %{}

    Enum.any?(
      ~w(show_image show_sound show_reading show_level show_frequency),
      &show?(config, &1)
    ) or config_locales(config, "meanings") != [] or config_locales(config, "examples") != []
  end

  defp config_locales(config, key) do
    config
    |> Kernel.||(%{})
    |> Map.get(key, [])
    |> List.wrap()
    |> Enum.filter(&(&1 in @locales))
  end

  defp meaning_for(%Word{} = word, "en"), do: word.meaning
  defp meaning_for(%Word{} = word, locale), do: Content.get_localized_meaning(word, locale)

  # Builds the example blocks for a face: the Japanese sentences (limited by
  # "example_count") with per-locale translations aligned by index.
  defp example_blocks(%Word{} = word, config) do
    locales = config_locales(config, "examples")

    sentences =
      word.example_sentence
      |> WordBooks.split_examples()
      |> take_examples(Map.get(config || %{}, "example_count"))

    translations =
      Map.new(locales, fn locale -> {locale, example_translations(word, locale)} end)

    sentences
    |> Enum.with_index()
    |> Enum.map(fn {sentence, index} ->
      %{
        sentence: sentence,
        translations:
          locales
          |> Enum.map(fn locale -> {locale, Enum.at(translations[locale], index)} end)
          |> Enum.reject(fn {_locale, text} -> text in [nil, ""] end)
      }
    end)
  end

  defp take_examples(sentences, count) when count in [1, "1"], do: Enum.take(sentences, 1)
  defp take_examples(sentences, count) when count in [2, "2"], do: Enum.take(sentences, 2)
  defp take_examples(sentences, _count), do: sentences

  defp example_translations(%Word{} = word, "en") do
    WordBooks.split_examples(word.example_meaning)
  end

  defp example_translations(%Word{translations: translations}, locale)
       when is_map(translations) do
    translations
    |> Map.get(locale, %{})
    |> Map.get("example")
    |> WordBooks.split_examples()
  end

  defp example_translations(%Word{}, _locale), do: []
end
