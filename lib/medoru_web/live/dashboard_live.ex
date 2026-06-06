defmodule MedoruWeb.DashboardLive do
  @moduledoc """
  Main learning dashboard for authenticated users.
  Includes the Board Stream - a feed of posts from followed users.
  """
  use MedoruWeb, :live_view

  import Ecto.Query, warn: false

  alias Medoru.{Accounts, Learning, Repo, Social, WhiteBoard}
  alias Medoru.WhiteBoard.BoardComment
  alias MedoruWeb.{Components.Helpers, WhiteBoardPostRenderer}

  import Helpers, only: [format_localized_date: 1, format_localized_datetime: 1]

  embed_templates "*.html"

  defp all_emojis do
    ~w(😀 😁 😂 🤣 😃 😄 😅 😆 😉 😊 😋 😎 😍 😘 😗 😙 😚 ☺️ 🙂 🤗 🤩 🤔 🤨 😐 😑 😶 🙄 😏 😣 😥 😮 🤐 😯 😪 😫 😴 😌 😛 😜 😝 🤤 😒 😓 😔 😕 🙃 🤑 😲 ☹️ 🙁 😖 😞 😟 😤 😢 😭 😦 😧
😨 😩 🤯 😬 😰 😱 😳 🤪 😵 😡 😠 🤬 😷 🤒 🤕 🤢 🤮 🤧 😇 🤠 🤡 🤥 🤫 🤭 🧐 🤓 😈 👿 👹 👺 💀 👻 👽 🤖 💩 😺 😸 😹 😻 😼 😽 🙀 😿 😾 🥰 🥳 🫡 ❤️ 💕 💔 👍 👎 🙏 🎉 🎊 🎵 🎮 🎲
🎯 🔥 ✨ 💯 ⭐ 🌈 🌙 🌸 🍀 🎌 🗾 🐱 🐶 🦊 🐼 🍜 🍱 🍡 🍣 🍙 🍥 🍘 🍮 🗡️ 🏴‍☠️ 🇧🇬 🇯🇵 🐭 🐹 🐰 🐻 🐨 🐯 🦁 🐮 🐷 🐽 🐸 🐵 🙈 🙉 🙊 🐒 🐔 🐧 🐦 🐤 🐣 🐥 🦆 🦅 🦉 🦇 🐺 🐗 🐴
🦄 🐝 🐛 🦋 🐌 🐚 🐞 🐜 🦗 🕷 🕸 🦂 🐢 🐍 🦎 🦖 🦕 🐙 🦑 🦐 🦀 🐡 🐠 🐟 🐬 🐳 🐋 🦈 🐊 🐅 🐆 🦓 🦍 🐘 🦏 🐪 🐫 🦒 🐃 🐂 🐄 🐎 🐖 🐏 🐑 🐐 🦌 🐕 🐩 🐈 🐓 🦃 🕊 🐇 🐁 🐀 🐿 🦔 🐾
🐉 🐲 🌵 🎄 🌲 🌳 🌴 🌱 🌿 ☘️ 🍃 🍂 🍁 🍄 🌾 💐 🌷 🌹 🥀 🌺 🌼 🌻 🌞 🌝 🌛 🌜 🌚 🌕 🌖 🌗 🌘 🌑 🌒 🌓 🌔 🌎 🌍 🌏 💫 ⭐️ 🌟 ⚡️ ☄️ 💥 🌪 ☀️ 🌤 ⛅️ 🌥 ☁️ 🌦 🌧 ⛈ 🌩 🌨
❄️ ☃️ ⛄️ 🌬 💨 💧 💦 ☔️ ☂️ 🌊 🌫 🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🍈 🍒 🍑 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥒 🌶 🌽 🥕 🥔 🍠 🥐 🍞 🥖 🥨 🧀 🥚 🍳 🥞 🥓 🥩 🍗 🍖 🌭 🍔 🍟 🍕 🥪 🥙 🌮 🌯
🥗 🥘 🥫 🍝 🍲 🍛 🥟 🍤 🍚 🥠 🍢 🍧 🍨 🍦 🥧 🍰 🎂 🍭 🍬 🍫 🍿 🍩 🍪 🌰 🥜 🍯 🥛 🍼 ☕️ 🍵 🥤 🍶 🍺 🍻 🥂 🍷 🥃 🍸 🍹 🍾 🥄 🍴 🍽 🥣 🥡 🥢) ++ [":ouroboros:", ":medoru:"]
  end

  @impl true
  def mount(_params, _session, socket) do
    %{current_user: user} = socket.assigns.current_scope

    # Load fresh user data with profile
    user = Accounts.get_user_with_profile!(user.id)

    # Calculate stats dynamically from learning progress
    learning_stats = Learning.get_user_stats(user.id)

    # Get daily review stats
    daily_stats = Learning.get_daily_review_stats(user.id)

    # Get daily challenge stats for completion count
    challenge_stats = Learning.get_daily_challenge_stats(user.id)

    # Merge learning stats with user stats (level, xp from gamification)
    user_stats = Accounts.get_or_create_user_stats(user.id)
    xp_progress = Accounts.xp_progress(user_stats)

    stats = %{
      total_kanji_learned: learning_stats.total_kanji_learned,
      total_words_learned: learning_stats.total_words_learned,
      total_grammar_learned: learning_stats.total_grammar_learned,
      current_streak: daily_stats.current_streak,
      longest_streak: daily_stats.longest_streak
    }

    # Load Board Stream
    viewer_id = user.id
    stream_posts = WhiteBoard.list_following_posts(viewer_id, page: 1)
    stream_count = WhiteBoard.count_following_posts(viewer_id)
    stream_has_more = length(stream_posts) < stream_count

    stream_post_ids = Enum.map(stream_posts, & &1.id)
    stream_reactions = WhiteBoard.list_reactions_for_posts(stream_post_ids, viewer_id)
    stream_comments = load_stream_comments(stream_posts, viewer_id)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:user, user)
     |> assign(:stats, stats)
     |> assign(:profile, user.profile)
     |> assign(:daily_stats, daily_stats)
     |> assign(:challenge_stats, challenge_stats)
     |> assign(:xp_progress, xp_progress)
     |> assign(:user_stats, user_stats)
     # Board Stream assigns
     |> assign(:stream_posts, stream_posts)
     |> assign(:stream_count, stream_count)
     |> assign(:stream_has_more, stream_has_more)
     |> assign(:stream_page, 1)
     |> assign(:stream_reactions, stream_reactions)
     |> assign(:stream_comments, stream_comments)
     |> assign(:stream_replying_to, %{})}
  end

  # ============================================================================
  # Board Stream Events
  # ============================================================================

  @impl true
  def handle_event("stream_toggle_reaction", %{"post-id" => post_id, "emoji" => emoji}, socket) do
    user_id = socket.assigns.current_scope.current_user.id
    post_id = String.trim(post_id)

    case WhiteBoard.toggle_reaction(post_id, user_id, emoji) do
      {:ok, added, removed} ->
        added_emoji = added && added.emoji
        removed_emoji = removed && removed.emoji

        reactions =
          update_reaction_map(
            socket.assigns.stream_reactions,
            post_id,
            added_emoji,
            removed_emoji
          )

        {:noreply, assign(socket, :stream_reactions, reactions)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stream_add_comment", params, socket) do
    user_id = socket.assigns.current_scope.current_user.id
    post_id = String.trim(params["post_id"])
    content = String.trim(params["content"] || "")
    parent_id = params["parent_id"] && String.trim(params["parent_id"])

    if content == "" do
      {:noreply, socket}
    else
      attrs = %{
        post_id: post_id,
        user_id: user_id,
        parent_id: parent_id,
        content: content
      }

      case WhiteBoard.create_comment(attrs) do
        {:ok, comment} ->
          comment = Repo.preload(comment, [user: [:profile], parent_comment: [user: [:profile]]])

          comments =
            Map.update(socket.assigns.stream_comments, post_id, [comment], fn existing ->
              existing ++ [comment]
            end)

          {:noreply,
           socket
           |> assign(:stream_comments, comments)
           |> assign(:stream_replying_to, Map.delete(socket.assigns.stream_replying_to, post_id))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not add comment."))}
      end
    end
  end

  @impl true
  def handle_event("stream_delete_comment", %{"id" => id}, socket) do
    comment = Repo.get(BoardComment, id)

    if comment && comment.user_id == socket.assigns.current_scope.current_user.id do
      WhiteBoard.delete_comment(comment)

      comments =
        Map.new(socket.assigns.stream_comments, fn {post_id, list} ->
          {post_id, Enum.reject(list, &(&1.id == id))}
        end)

      {:noreply, assign(socket, :stream_comments, comments)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stream_reply_to_comment", %{"post-id" => post_id, "comment-id" => comment_id}, socket) do
    replying_to = Map.put(socket.assigns.stream_replying_to, post_id, comment_id)
    {:noreply, assign(socket, :stream_replying_to, replying_to)}
  end

  @impl true
  def handle_event("stream_cancel_reply", %{"post-id" => post_id}, socket) do
    replying_to = Map.delete(socket.assigns.stream_replying_to, post_id)
    {:noreply, assign(socket, :stream_replying_to, replying_to)}
  end

  @impl true
  def handle_event("stream_load_more", _params, socket) do
    page = socket.assigns.stream_page + 1
    viewer_id = socket.assigns.current_scope.current_user.id

    new_posts = WhiteBoard.list_following_posts(viewer_id, page: page)
    stream_count = WhiteBoard.count_following_posts(viewer_id)
    all_posts = socket.assigns.stream_posts ++ new_posts
    has_more = length(all_posts) < stream_count

    post_ids = Enum.map(new_posts, & &1.id)
    new_reactions = WhiteBoard.list_reactions_for_posts(post_ids, viewer_id)
    new_comments = load_stream_comments(new_posts, viewer_id)

    reactions = Map.merge(socket.assigns.stream_reactions, new_reactions)
    comments = Map.merge(socket.assigns.stream_comments, new_comments)

    {:noreply,
     socket
     |> assign(:stream_posts, all_posts)
     |> assign(:stream_page, page)
     |> assign(:stream_has_more, has_more)
     |> assign(:stream_reactions, reactions)
     |> assign(:stream_comments, comments)}
  end

  # ============================================================================
  # Board Stream Helpers
  # ============================================================================

  defp load_stream_comments(posts, viewer_id) do
    post_ids = Enum.map(posts, & &1.id)

    if post_ids == [] do
      %{}
    else
      comments =
        BoardComment
        |> where([c], c.post_id in ^post_ids)
        |> order_by(asc: :inserted_at)
        |> preload([user: [:profile], parent_comment: [user: [:profile]]])
        |> Repo.all()

      comments =
        if viewer_id do
          blocked_ids =
            Social.UserBlock
            |> where([ub], ub.blocker_id == ^viewer_id)
            |> select([ub], ub.blocked_id)
            |> Repo.all()

          blocked_by_ids =
            Social.UserBlock
            |> where([ub], ub.blocked_id == ^viewer_id)
            |> select([ub], ub.blocker_id)
            |> Repo.all()

          excluded_ids = Enum.uniq(blocked_ids ++ blocked_by_ids)

          if excluded_ids == [] do
            comments
          else
            Enum.reject(comments, fn c -> c.user_id in excluded_ids end)
          end
        else
          comments
        end

      Enum.group_by(comments, & &1.post_id)
    end
  end

  defp update_reaction_map(reactions, post_id, added_emoji, removed_emoji) do
    post_reactions = Map.get(reactions, post_id, %{})

    # Step 1: remove old reaction (if replacing)
    post_reactions =
      if removed_emoji && removed_emoji != added_emoji do
        current = Map.get(post_reactions, removed_emoji, %{count: 0, me?: false})
        new_count = max(current.count - 1, 0)

        if new_count == 0 do
          Map.delete(post_reactions, removed_emoji)
        else
          Map.put(post_reactions, removed_emoji, %{count: new_count, me?: false})
        end
      else
        post_reactions
      end

    # Step 2: add new reaction (or remove if toggling off same emoji)
    post_reactions =
      cond do
        is_nil(added_emoji) && removed_emoji ->
          # Removed reaction - already handled above
          post_reactions

        added_emoji && added_emoji == removed_emoji ->
          # Shouldn't happen, but handle gracefully
          post_reactions

        added_emoji ->
          # Added or replaced reaction
          current = Map.get(post_reactions, added_emoji, %{count: 0, me?: false})
          new_count = current.count + 1
          Map.put(post_reactions, added_emoji, %{count: new_count, me?: true})

        true ->
          post_reactions
      end

    Map.put(reactions, post_id, post_reactions)
  end

  # ============================================================================
  # Components
  # ============================================================================

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl shadow-sm border border-base-300 p-4 hover:shadow-md hover:border-primary/30 hover:-translate-y-0.5 transition-all duration-200 cursor-pointer group">
      <div class="flex items-center">
        <div class={[
          "flex-shrink-0 p-2 rounded-lg transition-colors",
          stat_card_icon_bg(@color),
          "group-hover:bg-opacity-80"
        ]}>
          <.icon name={"hero-#{@icon}"} class={["h-5 w-5", stat_card_icon_color(@color)]} />
        </div>
        <div class="ml-3">
          <p class="text-xs font-medium text-secondary/70 group-hover:text-secondary transition-colors">
            {@label}
          </p>
          <p class="text-xl font-bold text-base-content group-hover:text-primary transition-colors">
            {@value}
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card_icon_bg("orange"), do: "bg-orange-100/80 dark:bg-orange-900/30"
  defp stat_card_icon_bg("yellow"), do: "bg-yellow-100/80 dark:bg-yellow-900/30"
  defp stat_card_icon_bg("purple"), do: "bg-purple-100/80 dark:bg-purple-900/30"
  defp stat_card_icon_bg("blue"), do: "bg-blue-100/80 dark:bg-blue-900/30"
  defp stat_card_icon_bg("green"), do: "bg-emerald-100/80 dark:bg-emerald-900/30"
  defp stat_card_icon_bg("red"), do: "bg-red-100/80 dark:bg-red-900/30"
  defp stat_card_icon_bg(_), do: "bg-base-200"

  defp stat_card_icon_color("orange"), do: "text-orange-600 dark:text-orange-400"
  defp stat_card_icon_color("yellow"), do: "text-yellow-600 dark:text-yellow-400"
  defp stat_card_icon_color("purple"), do: "text-purple-600 dark:text-purple-400"
  defp stat_card_icon_color("blue"), do: "text-blue-600 dark:text-blue-400"
  defp stat_card_icon_color("green"), do: "text-emerald-600 dark:text-emerald-400"
  defp stat_card_icon_color("red"), do: "text-red-600 dark:text-red-400"
  defp stat_card_icon_color(_), do: "text-secondary"

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :button_text, :string, required: true
  attr :button_link, :string, required: true
  attr :icon, :string, required: true

  defp action_card(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl shadow-sm border border-base-300 p-4 hover:shadow-md hover:border-primary/20 transition-all duration-200 group">
      <div class="flex items-start">
        <div class="flex-shrink-0 p-2 bg-primary/10 rounded-lg text-primary group-hover:bg-primary/20 transition-colors">
          <.icon name={"hero-#{@icon}"} class="h-5 w-5" />
        </div>
        <div class="ml-3 flex-1 min-w-0">
          <h3 class="text-sm font-semibold text-base-content">{@title}</h3>
          <p class="mt-0.5 text-xs text-secondary">{@description}</p>
          <.link
            navigate={@button_link}
            class="mt-2 inline-flex items-center px-3 py-1.5 text-xs font-medium rounded-lg text-primary-content bg-primary hover:bg-primary/90 active:scale-[0.98] transition-all shadow-sm hover:shadow"
          >
            {@button_text}
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
