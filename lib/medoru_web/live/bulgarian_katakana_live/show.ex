defmodule MedoruWeb.BulgarianKatakanaLive.Show do
  @moduledoc """
  Detail page for a single Bulgarian letter and its katakana reading.
  """
  use MedoruWeb, :live_view
  use Gettext, backend: MedoruWeb.Gettext

  alias Medoru.Content
  alias Medoru.Content.BulgarianKatakana

  embed_templates "show.html"

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    {:ok, assign(socket, :locale, locale)}
  end

  @impl true
  def handle_params(%{"letter" => letter}, _url, socket) do
    case BulgarianKatakana.get_by_letter(letter) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Letter not found"))
         |> push_navigate(to: ~p"/katakana/bulgarian")}

      entry ->
        letters = BulgarianKatakana.list_letters()
        current_index = Enum.find_index(letters, &(&1.letter == entry.letter))

        prev_entry =
          if current_index && current_index > 0, do: Enum.at(letters, current_index - 1)

        next_entry =
          if current_index && current_index < length(letters) - 1,
            do: Enum.at(letters, current_index + 1)

        words_with_links =
          Enum.map(entry.words, fn word ->
            Map.put(word, :word_id, find_word_id(word.meaning))
          end)

        {:noreply,
         socket
         |> assign(:entry, %{entry | words: words_with_links})
         |> assign(:prev_entry, prev_entry)
         |> assign(:next_entry, next_entry)
         |> assign(
           :page_title,
           gettext("%{letter} - Bulgarian Katakana", letter: entry.letter)
         )}
    end
  end

  defp find_word_id(meaning) do
    case Content.get_word_by_text_or_meaning_or_conjugation(meaning) do
      nil ->
        case Content.find_words_by_reading(meaning) do
          [] -> nil
          words -> List.first(words).id
        end

      word ->
        word.id
    end
  end

  defp highlight_letter(word, letter) do
    upper = Regex.escape(letter)
    lower = Regex.escape(String.downcase(letter))
    pattern = ~r/(#{upper}|#{lower})/u

    word
    |> String.split(pattern, include_captures: true)
    |> Enum.map(fn part ->
      if Regex.match?(pattern, part) do
        raw(~s(<span class="text-accent font-bold">#{part}</span>))
      else
        part
      end
    end)
  end
end
