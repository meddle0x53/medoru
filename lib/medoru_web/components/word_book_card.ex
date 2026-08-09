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
  alias Medoru.WhiteBoard

  @locales ~w(en bg ja)

  attr :id, :string, required: true
  attr :word, :any, required: true, doc: "a `%Medoru.Content.Word{}`"
  attr :front_config, :map, default: %{}
  attr :back_config, :map, default: %{}
  attr :card_shape, :string, default: "rectangle", values: ~w(square rectangle)

  attr :front_background, :string,
    default: nil,
    doc: ~s(background key see \(`WordBooks.background_path/1`\) or "word_image")

  attr :back_background, :string,
    default: nil,
    doc: ~s(background key \(see `WordBooks.background_path/1`\) or "word_image")

  attr :download, :boolean, default: false, doc: "render per-face PNG download buttons"

  attr :post, :boolean,
    default: false,
    doc: "render a button posting the card to the current user's white board"

  attr :custom_text, :string,
    default: nil,
    doc: "optional book-level text shown above the word on every card face"

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
            style={background_style(face_background(@front_background, @word))}
          >
            <.level_badge word={@word} config={@front_config} />
            <.card_face
              word={@word}
              config={@front_config}
              shape={@card_shape}
              background={face_background(@front_background, @word)}
              custom_text={@custom_text}
            />
          </div>
          <div
            id={"#{@id}-back"}
            data-share-picture
            class="word-book-card-face word-book-card-face-back relative bg-base-100 text-base-content border border-base-300 shadow-md"
            style={background_style(face_background(@back_background, @word))}
          >
            <.level_badge word={@word} config={@back_config} />
            <.card_face
              word={@word}
              config={@back_config}
              shape={@card_shape}
              background={face_background(@back_background, @word)}
              custom_text={@custom_text}
            />
          </div>
        </div>
      </div>
      <%= if @post do %>
        <%!-- Same explicit fixed-size style as the download button (see
             below); sits just left of it. --%>
        <button
          id={"#{@id}-post"}
          type="button"
          phx-click="post_card_to_board"
          phx-value-word_id={@word.id}
          title={gettext("Post to White Board")}
          class="absolute top-2 right-14 z-20 w-10 h-10 flex items-center justify-center rounded-full bg-secondary text-secondary-content shadow-md hover:bg-secondary/90 transition-colors"
          data-share-exclude
        >
          <.icon name="hero-share" class="w-5 h-5" />
        </button>
      <% end %>
      <%= if @download do %>
        <%!-- Explicit fixed-size icon button instead of .btn: the global
             mobile rules (min 44px, .btn-primary full-width) would stretch
             this overlay across the card. --%>
        <button
          id={"#{@id}-download"}
          type="button"
          phx-hook="ShareAsPicture"
          data-share-front={"#{@id}-front"}
          data-share-back={"#{@id}-back"}
          data-filename={"medoru-#{@id}"}
          title={gettext("Download card as PNG")}
          class="absolute top-2 right-2 z-20 w-10 h-10 flex items-center justify-center rounded-full bg-primary text-primary-content shadow-md hover:bg-primary/90 transition-colors"
          data-share-exclude
        >
          <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
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
      <span class="absolute top-2 left-2 z-10 inline-flex items-center px-2 py-1 bg-primary text-primary-content text-xs font-bold shadow-sm [backface-visibility:hidden]">
        N{@word.difficulty}
      </span>
    <% end %>
    """
  end

  # Site branding rendered on every card face, so it is always part of
  # downloaded card images. The pill has its own background so it stays
  # readable over any card background. For rectangle cards it is the
  # final content block; square cards use square_watermark/1 (see
  # card_face/1) so it stays at the bottom edge of the fixed-height face.
  defp watermark(assigns) do
    ~H"""
    <div class="mt-auto w-full pt-3 flex justify-center">
      <span class="px-3 py-1 bg-base-100 border border-base-300 text-sm font-bold tracking-widest text-base-content shadow-sm">
        medoru.net
      </span>
    </div>
    """
  end

  # Square faces have a fixed height and overflowing content, so the
  # branding is the in-flow footer of a flex column filling the face —
  # always at the bottom edge, never overflowing, never absolutely
  # positioned (absolute elements escape the 3D plane and render
  # mirrored on the back face).
  defp square_watermark(assigns) do
    ~H"""
    <div class="w-full px-4 pb-1.5 pt-3 flex justify-center">
      <span class="px-3 py-1 bg-base-100 border border-base-300 text-sm font-bold tracking-widest text-base-content shadow-sm">
        medoru.net
      </span>
    </div>
    """
  end

  attr :post, :any, required: true, doc: "a `%BoardPost{}` with post_type \"word_card\""

  @doc """
  Renders a white board word-card post from its `card_data` snapshot.
  The flip animation is pure CSS + `JS.toggle_class`, so it works in any
  LiveView without hooks.
  """
  def board_card(assigns) do
    assigns = assign(assigns, :card_word, WhiteBoard.card_word(assigns.post.card_data))

    ~H"""
    <%= if @card_word do %>
      <div class="mt-3 w-full">
        <.card
          id={"board-card-#{@post.id}"}
          word={@card_word}
          front_config={@post.card_data["front_config"] || %{}}
          back_config={@post.card_data["back_config"] || %{}}
          card_shape={@post.card_data["card_shape"] || "rectangle"}
          front_background={@post.card_data["front_background"]}
          back_background={@post.card_data["back_background"]}
          custom_text={@post.card_data["custom_text"]}
          download={true}
        />
        <%= if @post.card_data["book_title"] do %>
          <p class="mt-2 text-center text-xs text-base-content/60">
            {gettext("From word book: %{title}", title: @post.card_data["book_title"])}
          </p>
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :word, :any, required: true
  attr :config, :map, required: true
  attr :shape, :string, required: true
  attr :background, :string, required: true
  attr :custom_text, :string, default: nil

  defp card_face(assigns) do
    assigns = assign(assigns, :has_content?, side_config_content?(assigns.config))

    ~H"""
    <%= if @shape == "square" do %>
      <div class={["h-full w-full flex flex-col text-center", if(@background, do: "bg-base-100/60")]}>
        <div class="flex-1 min-h-0 w-full flex flex-col items-center justify-start gap-2 p-4 pt-10">
          <%!-- my-auto centers the content vertically when it fits; when it
               is taller than the square the auto margins collapse to 0 and
               the content top-aligns, clipping only at the bottom. --%>
          <div class="my-auto w-full flex flex-col items-center gap-2">
            <.card_content
              word={@word}
              config={@config}
              shape={@shape}
              has_content?={@has_content?}
              custom_text={@custom_text}
            />
          </div>
        </div>
        <.square_watermark />
      </div>
    <% else %>
      <div class={[
        "min-h-full w-full flex flex-col items-center justify-center gap-2 p-4 pt-10 text-center",
        if(@background, do: "bg-base-100/60")
      ]}>
        <.card_content
          word={@word}
          config={@config}
          shape={@shape}
          has_content?={@has_content?}
          custom_text={@custom_text}
        />
        <.watermark />
      </div>
    <% end %>
    """
  end

  # Optional book-level header shown above the Japanese word on every
  # face; clamped to one line so it can't distort square cards.
  attr :text, :string, default: nil

  defp custom_header(assigns) do
    ~H"""
    <%= if @text not in [nil, ""] do %>
      <div class="w-full text-xs font-bold uppercase tracking-widest text-base-content/70 line-clamp-1">
        {@text}
      </div>
    <% end %>
    """
  end

  attr :word, :any, required: true
  attr :config, :map, required: true
  attr :shape, :string, required: true
  attr :has_content?, :boolean, required: true
  attr :custom_text, :string, default: nil

  defp card_content(assigns) do
    ~H"""
    <%= if @has_content? do %>
      <%= if show?(@config, "show_image") && @word.image_path do %>
        <img
          src={@word.image_path}
          alt={@word.text}
          class="max-h-28 w-auto max-w-full object-contain rounded-lg border border-base-300"
          loading="lazy"
        />
      <% end %>

      <.custom_header text={@custom_text} />

      <div>
        <%= if show_word?(@config) do %>
          <div class={[
            "font-medium text-base-content font-japanese leading-tight",
            text_class(@shape)
          ]}>
            {@word.text}
          </div>
        <% end %>
        <%= if show?(@config, "show_reading") && @word.reading do %>
          <div class="mt-1">
            <span class="inline-flex items-center px-2 py-1 bg-secondary text-secondary-content text-xs font-bold shadow-sm font-japanese">
              {@word.reading} ({Medoru.Content.KanaRomaji.to_romaji(@word.reading)})
            </span>
          </div>
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
            <span class="text-xs text-base-content/70">
              {gettext("Freq: %{frequency}", frequency: @word.usage_frequency)}
            </span>
          <% end %>
        </div>
      <% end %>

      <%= for locale <- config_locales(@config, "meanings") do %>
        <div class="w-full flex justify-center">
          <span class="inline-flex items-baseline gap-1.5 px-2 py-1 bg-primary text-primary-content text-xs shadow-sm">
            <span class="font-bold uppercase">[{locale}]</span>
            <span class="line-clamp-3">{meaning_for(@word, locale)}</span>
          </span>
        </div>
      <% end %>

      <%= for example <- example_blocks(@word, @config) do %>
        <div class="w-full">
          <%= if example.sentence do %>
            <p class="text-sm text-base-content font-japanese line-clamp-3">
              {example.sentence}
            </p>
          <% end %>
          <%= for {locale, translation} <- example.translations do %>
            <p class="text-xs text-base-content/70 line-clamp-2">
              <span class="uppercase">{locale}</span>: {translation}
            </p>
          <% end %>
        </div>
      <% end %>
    <% else %>
      <.custom_header text={@custom_text} />
      <%= if show_word?(@config) do %>
        <div class={["font-medium text-base-content font-japanese leading-tight", text_class(@shape)]}>
          {@word.text}
        </div>
      <% end %>
    <% end %>
    """
  end

  defp shape_class("square"), do: "aspect-square"
  defp shape_class(_), do: "[aspect-ratio:5/7]"

  defp text_class("square"), do: "text-4xl"
  defp text_class(_), do: "text-5xl"

  defp background_style(nil), do: nil
  defp background_style(""), do: nil
  defp background_style(path), do: "background-image: url('#{path}');"

  # Resolves a face background: "word_image" uses the word's own image
  # (when available); anything else is a preset gallery key.
  defp face_background("word_image", %Word{image_path: path}), do: path
  defp face_background(key, _word), do: WordBooks.background_path(key)

  defp show?(config, key), do: Map.get(config || %{}, key, false) == true

  # The word text is shown unless explicitly disabled (back faces can
  # hide it via the "show_word" option; absent key means show).
  defp show_word?(config), do: Map.get(config || %{}, "show_word", true) != false

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

  # Builds the example blocks for a face. Each selected locale renders
  # the example in ITS language: "ja" is the word's Japanese
  # example_sentence, "en"/"bg" are the translated examples, aligned by
  # index and limited by "example_count". Nothing renders when no
  # example locale is selected.
  defp example_blocks(%Word{} = word, config) do
    locales = config_locales(config, "examples")

    if locales == [] do
      []
    else
      count = Map.get(config || %{}, "example_count")

      sentences =
        if "ja" in locales do
          word.example_sentence |> WordBooks.split_examples() |> take_examples(count)
        else
          []
        end

      translation_locales = locales -- ["ja"]

      translations =
        Map.new(translation_locales, fn locale ->
          {locale, word |> example_translations(locale) |> take_examples(count)}
        end)

      block_count =
        max(
          length(sentences),
          translations |> Enum.map(fn {_l, list} -> length(list) end) |> Enum.max(fn -> 0 end)
        )

      if block_count == 0 do
        []
      else
        Enum.map(0..(block_count - 1), fn index ->
          %{
            sentence: Enum.at(sentences, index),
            translations:
              translation_locales
              |> Enum.map(fn locale -> {locale, Enum.at(translations[locale], index)} end)
              |> Enum.reject(fn {_locale, text} -> text in [nil, ""] end)
          }
        end)
        |> Enum.reject(fn block -> is_nil(block.sentence) and block.translations == [] end)
      end
    end
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
