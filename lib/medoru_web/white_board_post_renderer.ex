defmodule MedoruWeb.WhiteBoardPostRenderer do
  @moduledoc """
  Shared rendering helpers for white board post content.
  Used by both UserWhiteBoardLive and UserWhiteBoardPostLive.
  """

  alias Medoru.Content
  alias Medoru.Content.MatureContent
  alias MedoruWeb.{GrammarChatPreview, KanjiChatPreview, WordChatPreview}

  def render_post_content(text_or_nil, post_id, viewer \\ nil)

  def render_post_content(text, post_id, viewer) when is_binary(text) do
    lines = String.split(text, "\n")

    {segments, last_group} =
      Enum.reduce(lines, {[], []}, fn line, {segments, group} ->
        trimmed = String.trim(line)

        cond do
          trimmed == "" ->
            {segments, group ++ [line]}

          match_word_command?(trimmed) or match_kanji_command?(trimmed) or
              match_grammar_command?(trimmed) ->
            segments =
              if group != [], do: [{:text, Enum.join(group, "\n")} | segments], else: segments

            segments = [{:command, trimmed} | segments]
            {segments, []}

          true ->
            {segments, group ++ [line]}
        end
      end)

    segments =
      if last_group != [], do: [{:text, Enum.join(last_group, "\n")} | segments], else: segments

    segments
    |> Enum.reverse()
    |> Enum.map(fn
      {:text, txt} -> render_post_body(txt, post_id, viewer)
      {:command, cmd} -> render_command(cmd, viewer)
    end)
    |> Enum.join("\n")
  end

  def render_post_content(nil, _post_id, _viewer), do: ""

  @doc """
  Renders comment content with command support (grammar, word, kanji),
  inline word links, URL autolinking, and markdown.
  """
  def render_comment_content(text_or_nil, viewer \\ nil)

  def render_comment_content(text, viewer) when is_binary(text) do
    lines = String.split(text, "\n")

    {segments, last_group} =
      Enum.reduce(lines, {[], []}, fn line, {segments, group} ->
        trimmed = String.trim(line)

        cond do
          trimmed == "" ->
            {segments, group ++ [line]}

          match_word_command?(trimmed) or match_kanji_command?(trimmed) or
              match_grammar_command?(trimmed) ->
            segments =
              if group != [], do: [{:text, Enum.join(group, "\n")} | segments], else: segments

            segments = [{:command, trimmed} | segments]
            {segments, []}

          true ->
            {segments, group ++ [line]}
        end
      end)

    segments =
      if last_group != [], do: [{:text, Enum.join(last_group, "\n")} | segments], else: segments

    segments
    |> Enum.reverse()
    |> Enum.map(fn
      {:text, txt} -> render_comment_body(txt, viewer)
      {:command, cmd} -> render_command(cmd, viewer)
    end)
    |> Enum.join("\n")
  end

  def render_comment_content(nil, _viewer), do: ""

  defp render_post_body(text, post_id, viewer) do
    text
    |> render_inline_word_links(viewer)
    |> autolink_urls()
    |> render_markdown()
    |> unwrap_photo_only_html()
    |> render_audio_players(post_id)
    |> render_video_players(post_id)
    |> render_images(post_id)
  end

  defp render_comment_body(text, viewer) do
    text
    |> render_inline_word_links(viewer)
    |> autolink_urls()
    |> render_markdown()
    |> render_video_players("comment")
  end

  defp match_word_command?(text) do
    String.starts_with?(text, "/word ") or
      String.starts_with?(text, "/w ") or
      String.starts_with?(text, "\\word ") or
      String.starts_with?(text, "\\w ")
  end

  defp match_grammar_command?(text) do
    String.starts_with?(text, "/grammar ") or
      String.starts_with?(text, "/g ") or
      String.starts_with?(text, "\\grammar ") or
      String.starts_with?(text, "\\g ")
  end

  defp match_kanji_command?(text) do
    String.starts_with?(text, "/kanji ") or
      String.starts_with?(text, "/k ") or
      String.starts_with?(text, "\\kanji ") or
      String.starts_with?(text, "\\k ")
  end

  defp render_command(text, viewer) do
    case parse_grammar_command(text) do
      {:ok, grammar_text} ->
        case Content.get_grammar_definition_by_title(grammar_text) do
          nil -> text
          grammar -> GrammarChatPreview.render_html(%{grammar: grammar}) |> elem(1)
        end

      :error ->
        case parse_word_command(text) do
          {:ok, word_text} ->
            case Content.get_word_by_text_or_meaning_or_conjugation(word_text) do
              nil ->
                text

              word ->
                if MatureContent.mature_word_visible_to_user?(word, viewer) do
                  WordChatPreview.render_html(%{word: word}) |> elem(1)
                else
                  WordChatPreview.render_html(%{blocked: true}) |> elem(1)
                end
            end

          :error ->
            case parse_kanji_command(text) do
              {:ok, character} ->
                case Content.get_kanji_by_character(character) do
                  nil ->
                    text

                  kanji ->
                    locale = Gettext.get_locale(MedoruWeb.Gettext)
                    assigns = KanjiChatPreview.build_preview_assigns(kanji, locale)
                    KanjiChatPreview.render_html(assigns) |> elem(1)
                end

              :error ->
                text
            end
        end
    end
  end

  defp render_inline_word_links(text, viewer) do
    pipe_matches = Regex.scan(~r/\|([^|]+)\|/, text, return: :index)
    bracket_matches = Regex.scan(~r/\[\[([^\]]+)\]\]/, text, return: :index)
    corner_matches = Regex.scan(~r/「([^」]+)」/u, text, return: :index)
    grammar_matches = Regex.scan(~r/\\([^\/]+)\//, text, return: :index)

    matches =
      (Enum.map(pipe_matches, &{:word, &1}) ++
         Enum.map(bracket_matches, &{:word, &1}) ++
         Enum.map(corner_matches, &{:word, &1}) ++
         Enum.map(grammar_matches, &{:grammar, &1}))
      |> Enum.sort_by(fn {_, [{match_start, _}, _]} -> match_start end)

    if matches == [] do
      text
    else
      segments = build_word_link_segments(text, matches, 0, [])

      segments
      |> Enum.map(fn
        {:text, segment_text} ->
          segment_text

        {:word, word_text} ->
          case Content.get_word_by_text_or_meaning_or_conjugation(word_text) do
            nil ->
              word_text

            word ->
              if MatureContent.mature_word_visible_to_user?(word, viewer) do
                ~s|<a href="/words/#{word.id}" target="_blank" rel="noopener noreferrer" class="link link-primary hover:opacity-80">#{word_text}</a>|
              else
                ~s|<span class="text-error text-sm">unsafe content detected</span>|
              end
          end

        {:grammar, grammar_text} ->
          case Content.get_grammar_definition_by_title(grammar_text) do
            nil ->
              "\\#{grammar_text}/"

            grammar ->
              ~s|<a href="/grammars/#{grammar.slug}" target="_blank" rel="noopener noreferrer" class="link link-primary hover:opacity-80">#{grammar_text}</a>|
          end
      end)
      |> Enum.join("")
    end
  end

  defp build_word_link_segments(text, [], pos, acc) do
    remaining =
      if pos < byte_size(text), do: binary_part(text, pos, byte_size(text) - pos), else: ""

    acc = if remaining != "", do: [{:text, remaining} | acc], else: acc
    Enum.reverse(acc)
  end

  defp build_word_link_segments(
         text,
         [{tag, [{match_start, match_len}, {cap_start, cap_len}]} | rest],
         pos,
         acc
       ) do
    before_len = match_start - pos
    before_text = if before_len > 0, do: binary_part(text, pos, before_len), else: ""
    captured_text = binary_part(text, cap_start, cap_len)

    acc = if before_text != "", do: [{:text, before_text} | acc], else: acc
    acc = [{tag, captured_text} | acc]

    build_word_link_segments(text, rest, match_start + match_len, acc)
  end

  defp parse_grammar_command(text) do
    case text do
      "/grammar " <> rest -> parse_command_rest(rest)
      "/g " <> rest -> parse_command_rest(rest)
      "\\grammar " <> rest -> parse_command_rest(rest)
      "\\g " <> rest -> parse_command_rest(rest)
      _ -> :error
    end
  end

  defp parse_word_command(text) do
    case text do
      "/word " <> rest -> parse_command_rest(rest)
      "/w " <> rest -> parse_command_rest(rest)
      "\\word " <> rest -> parse_command_rest(rest)
      "\\w " <> rest -> parse_command_rest(rest)
      _ -> :error
    end
  end

  defp parse_kanji_command(text) do
    case text do
      "/kanji " <> rest -> parse_kanji_rest(rest)
      "/k " <> rest -> parse_kanji_rest(rest)
      "\\kanji " <> rest -> parse_kanji_rest(rest)
      "\\k " <> rest -> parse_kanji_rest(rest)
      _ -> :error
    end
  end

  defp parse_command_rest(rest) do
    rest = String.trim(rest)
    if rest != "", do: {:ok, rest}, else: :error
  end

  defp parse_kanji_rest(rest) do
    rest = String.trim(rest)
    if valid_kanji_command?(rest), do: {:ok, rest}, else: :error
  end

  defp valid_kanji_command?(<<char::utf8>>) when char in 0x4E00..0x9FFF, do: true
  defp valid_kanji_command?(<<char::utf8>>) when char in 0x3400..0x4DBF, do: true
  defp valid_kanji_command?(_), do: false

  defp autolink_urls(text) do
    url_regex = ~r/https?:\/\/[^\s<>"{}|\\^`\[\]]+/

    Regex.split(url_regex, text, include_captures: true)
    |> Enum.map(fn segment ->
      cond do
        Regex.match?(url_regex, segment) ->
          case MedoruWeb.YoutubeEmbed.video_id(segment) do
            {:ok, video_id} ->
              MedoruWeb.YoutubeEmbed.embed_html(video_id)

            :error ->
              "<a href=\"#{segment}\" target=\"_blank\" rel=\"noopener noreferrer\" class=\"link link-primary\">#{segment}</a>"
          end

        true ->
          segment
      end
    end)
    |> Enum.join("")
  end

  defp render_markdown(text) when is_binary(text) do
    {:ok, html, _} = Earmark.as_html(text, escape: false, smartypants: false)
    html
  end

  defp render_audio_players(html, post_id) when is_binary(html) do
    regex = ~r/<a href="([^"]+\.(?:webm|ogg|mp3|wav|m4a|oga)[^"]*)"[^>]*>([^<]*)<\/a>/

    Regex.replace(regex, html, fn _full_match, href, _text ->
      audio_id = "board-audio-#{post_id}-#{:erlang.phash2(href)}"

      {clean_href, duration} =
        case Regex.run(~r/#duration=(\d+)/, href) do
          [_, d] -> {String.replace(href, ~r/#duration=\d+/, ""), String.to_integer(d)}
          _ -> {href, 0}
        end

      """
      <div
        id="#{audio_id}"
        class="flex items-center gap-2 mt-2"
        phx-hook="ChatAudioPlayer"
        data-src="#{clean_href}"
        data-duration="#{duration}"
      >
        <button
          type="button"
          class="chat-audio-play w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center hover:bg-primary/30 transition-colors shrink-0"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4 chat-audio-play-icon"><path d="M4.5 5.653c0-1.427 1.529-2.33 2.779-1.643l11.54 6.347c1.295.712 1.295 2.573 0 3.286L7.28 19.99c-1.25.687-2.779-.217-2.779-1.643V5.653Z" /></svg>
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4 chat-audio-pause-icon hidden"><path fill-rule="evenodd" d="M6.75 5.25a.75.75 0 0 1 .75-.75H9a.75.75 0 0 1 .75.75v13.5a.75.75 0 0 1-.75.75H7.5a.75.75 0 0 1-.75-.75V5.25Zm7.5 0A.75.75 0 0 1 15 4.5h1.5a.75.75 0 0 1 .75.75v13.5a.75.75 0 0 1-.75.75H15a.75.75 0 0 1-.75-.75V5.25Z" clip-rule="evenodd" /></svg>
        </button>
        <div class="flex-1 min-w-0">
          <div class="chat-audio-progress h-1.5 bg-base-300/50 rounded-full overflow-hidden cursor-pointer">
            <div
              class="chat-audio-progress-bar h-full bg-primary rounded-full transition-all duration-100"
              style="width: 0%"
            >
            </div>
          </div>
          <div class="flex justify-between mt-0.5">
            <span class="chat-audio-current text-[10px] opacity-70 tabular-nums">0:00</span>
            <span class="chat-audio-duration text-[10px] opacity-70 tabular-nums">0:00</span>
          </div>
        </div>
        <audio
          class="chat-audio-el absolute w-0 h-0 opacity-0"
          src="#{href}"
          preload="auto"
        >
        </audio>
      </div>
      """
    end)
  end

  def photo_only?(nil), do: false

  def photo_only?(text) do
    trimmed = String.trim(text)
    trimmed != "" and Regex.match?(~r/^\s*!\[[^\]]*\]\([^\)]+\)\s*$/, trimmed)
  end

  defp unwrap_photo_only_html(html) when is_binary(html) do
    Regex.replace(~r/^<p>\s*(<img[^>]*>)\s*<\/p>$/i, html, "\\1")
  end

  defp render_video_players(html, _post_id) when is_binary(html) do
    regex = ~r/<a href="([^"]+\.(?:mp4|webm|ogv|mov))"[^>]*>([^<]*)<\/a>/i

    Regex.replace(regex, html, fn _full_match, href, text ->
      mime = video_mime_type(href)

      ~s|<span class="block my-2"><video class="rounded-lg w-full max-w-[560px] aspect-video" controls preload="metadata"><source src="#{href}" type="#{mime}" /><a href="#{href}" class="text-primary underline" download>#{text}</a></video></span>|
    end)
  end

  defp video_mime_type(path) do
    case Path.extname(path) |> String.downcase() do
      ".mp4" -> "video/mp4"
      ".mov" -> "video/quicktime"
      ".webm" -> "video/webm"
      ".ogv" -> "video/ogg"
      _ -> "video/mp4"
    end
  end

  defp render_images(html, _post_id) when is_binary(html) do
    Regex.replace(
      ~r/<img\b([^>]*)>/i,
      html,
      fn _full, attrs ->
        if String.contains?(attrs, "class=") do
          ~s|<img#{attrs} />|
        else
          ~s|<img#{attrs} class="max-w-full h-auto rounded-lg mx-auto block" loading="lazy" />|
        end
      end
    )
  end

  def command_only?(nil), do: false

  def command_only?(text) do
    trimmed = String.trim(text)

    match_word_command?(trimmed) or match_kanji_command?(trimmed) or
      match_grammar_command?(trimmed)
  end

  def emoji_only?(nil), do: false

  def emoji_only?(text) do
    trimmed = String.trim(text)

    trimmed != "" and
      String.replace(
        trimmed,
        ~r/[\s\x{1F600}-\x{1F64F}\x{1F300}-\x{1F5FF}\x{1F680}-\x{1F6FF}\x{1F1E0}-\x{1F1FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{1F900}-\x{1F9FF}\x{1F004}\x{1F0CF}\x{1F170}-\x{1F251}\x{238C}\x{2B50}\x{2B55}\x{2764}\x{2795}-\x{2797}\x{27A1}\x{27B0}\x{27BF}\x{2B05}-\x{2B07}\x{3030}\x{303D}\x{3297}\x{3299}\x{23F0}-\x{23F3}\x{23E9}-\x{23EF}\x{1F18E}\x{00A9}\x{00AE}\x{FE0F}\x{200D}\x{1F3FB}-\x{1F3FF}]/u,
        ""
      )
      |> String.replace(":medoru:", "")
      |> String.replace(":ouroboros:", "")
      |> String.trim() == ""
  end
end
