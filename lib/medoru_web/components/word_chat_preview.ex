defmodule MedoruWeb.WordChatPreview do
  @moduledoc """
  Compact word preview for chat messages.
  Shows image, audio, word text, reading, and type in a clickable card.
  """
  use MedoruWeb, :html

  attr :word, :map, required: true
  attr :blocked, :boolean, default: false

  def word_chat_preview(%{blocked: true} = assigns) do
    ~H"""
    <span class="text-error text-sm">{gettext("unsafe content detected")}</span>
    """
  end

  def word_chat_preview(assigns) do
    meaning =
      Medoru.Content.get_localized_meaning(assigns.word, Gettext.get_locale(MedoruWeb.Gettext))

    assigns = assign(assigns, :meaning, meaning)

    ~H"""
    <a
      href={~p"/words/#{@word.id}"}
      target="_blank"
      rel="noopener noreferrer"
      class="block max-w-[200px] word-chat-preview -mt-1 -mb-1"
    >
      <div class="bg-base-100 border border-base-300 rounded-xl p-2 shadow-sm hover:shadow-md hover:border-primary/30 transition-all">
        <%!-- Word Image --%>
        <%= if @word.image_path do %>
          <div class="mb-1.5">
            <img
              src={@word.image_path}
              alt={@word.text}
              class="w-full max-h-24 object-cover object-top rounded-lg border border-base-300"
              loading="lazy"
            />
          </div>
        <% end %>

        <%!-- Audio --%>
        <%= if @word.pronunciation_path do %>
          <div class="mb-1.5">
            <audio controls class="w-full h-7">
              <source src={@word.pronunciation_path} />
            </audio>
          </div>
        <% end %>

        <%!-- Word Text (kanji/kana variant) --%>
        <div class="text-center">
          <div class="text-2xl font-medium text-base-content leading-tight">
            {@word.text}
          </div>
          <div class="text-sm text-secondary mt-0.5">
            {@word.reading}
          </div>
          <div class="text-xs text-base-content/70 mt-1 truncate px-1">
            {@meaning}
          </div>
          <div class="mt-1">
            <span class={[
              "inline-block px-2 py-0.5 rounded-full text-[10px] font-medium capitalize",
              word_type_classes(@word.word_type)
            ]}>
              {@word.word_type}
            </span>
          </div>
        </div>
      </div>
    </a>
    """
  end

  @doc """
  Renders the word preview as a safe HTML string for use outside of HEEx templates.
  """
  def render_html(%{blocked: true}) do
    {:safe, ~s|<span class="text-error text-sm">unsafe content detected</span>|}
  end

  def render_html(%{word: word}) do
    locale = Gettext.get_locale(MedoruWeb.Gettext)
    meaning = Medoru.Content.get_localized_meaning(word, locale)

    image_html =
      if word.image_path do
        ~s|<div class="mb-1.5"><img src="#{word.image_path}" alt="#{escape(word.text)}" class="w-full max-h-24 object-cover object-top rounded-lg border border-base-300" loading="lazy" /></div>|
      else
        ""
      end

    audio_html =
      if word.pronunciation_path do
        ~s|<div class="mb-1.5"><audio controls class="w-full h-7"><source src="#{word.pronunciation_path}" /></audio></div>|
      else
        ""
      end

    type_class = word_type_classes(word.word_type)
    word_path = ~p"/words/#{word.id}"

    meaning_html =
      if meaning,
        do:
          ~s|<div class="text-xs text-base-content/70 mt-1 truncate px-1">#{escape(meaning)}</div>|,
        else: ""

    html =
      ~s|<a href="#{word_path}" target="_blank" rel="noopener noreferrer" class="block max-w-[200px] word-chat-preview -mt-1 -mb-1">| <>
        ~s|<div class="bg-base-100 border border-base-300 rounded-xl p-2 shadow-sm hover:shadow-md hover:border-primary/30 transition-all">| <>
        image_html <>
        audio_html <>
        ~s|<div class="text-center">| <>
        ~s|<div class="text-2xl font-medium text-base-content leading-tight">#{escape(word.text)}</div>| <>
        ~s|<div class="text-sm text-secondary mt-0.5">#{escape(word.reading)}</div>| <>
        meaning_html <>
        ~s|<div class="mt-1"><span class="inline-block px-2 py-0.5 rounded-full text-[10px] font-medium capitalize #{type_class}">#{word.word_type}</span></div>| <>
        ~s|</div></div></a>|

    {:safe, html}
  end

  defp word_type_classes(type) do
    case type do
      :noun -> "bg-blue-100/80 text-blue-700"
      :verb -> "bg-red-100/80 text-red-700"
      :adjective -> "bg-green-100/80 text-green-700"
      :adverb -> "bg-purple-100/80 text-purple-700"
      :particle -> "bg-orange-100/80 text-orange-700"
      :pronoun -> "bg-pink-100/80 text-pink-700"
      :counter -> "bg-teal-100/80 text-teal-700"
      :expression -> "bg-indigo-100/80 text-indigo-700"
      _ -> "bg-gray-100/80 text-gray-700"
    end
  end

  defp escape(text) do
    Phoenix.HTML.html_escape(text) |> elem(1)
  end
end
