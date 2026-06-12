defmodule MedoruWeb.UserWhiteBoardPostLive do
  @moduledoc """
  LiveView for viewing a single white board post.
  Used by notification links to ensure the post is always visible
  regardless of pagination on the main white board.
  """
  use MedoruWeb, :live_view

  alias Medoru.{Repo, WhiteBoard}
  alias MedoruWeb.{Components.Helpers, WhiteBoardPostRenderer}

  import Helpers, only: [format_localized_date: 1, format_localized_datetime: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Back link --%>
        <div class="mb-6">
          <.link navigate={~p"/users/#{@post.user_id}/white-board"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> {gettext("Back to White Board")}
          </.link>
        </div>

        <%!-- Single Post --%>
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body p-4 sm:p-6">
            <%!-- Post Header --%>
            <div class="flex items-start justify-between">
              <div class="flex items-center gap-3 min-w-0">
                <.link navigate={~p"/users/#{@post.user_id}"}>
                  <% avatar_src =
                    (@post.user.profile && @post.user.profile.avatar) || @post.user.avatar_url %>
                  <%= if avatar_src do %>
                    <img src={avatar_src} class="w-10 h-10 rounded-full object-cover shrink-0" />
                  <% else %>
                    <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                      <.icon name="hero-user" class="w-5 h-5 text-primary/50" />
                    </div>
                  <% end %>
                </.link>
                <div class="min-w-0">
                  <p class="font-semibold text-base-content truncate">
                    {(@post.user.profile && @post.user.profile.display_name) || @post.user.name}
                  </p>
                  <p class="text-xs text-base-content/50 truncate">
                    {format_localized_date(@post.inserted_at)}
                    <%= if @post.visibility == "followers" do %>
                      <span class="badge badge-xs badge-ghost ml-1">{gettext("Followers")}</span>
                    <% end %>
                  </p>
                </div>
              </div>
              <button
                type="button"
                id={"share-btn-#{@post.id}"}
                phx-hook="CopyToClipboard"
                data-text={url(~p"/users/#{@post.user_id}/white-board/posts/#{@post.id}")}
                class="btn btn-ghost btn-xs shrink-0"
                title={gettext("Copy link to post")}
              >
                <.icon name="hero-share" class="w-4 h-4" />
              </button>
            </div>

            <%!-- Post Content --%>
            <%= if @post.title do %>
              <h3 class="text-lg font-bold text-base-content mt-2">{@post.title}</h3>
            <% end %>

            <%= if @post.post_type == "canvas" && @post.canvas_data do %>
              <div
                id={"canvas-wrapper-#{@post.id}"}
                class="mt-3 rounded-xl border border-base-300 overflow-hidden"
                style="width: 100%; height: min(400px, 60vw); max-height: 400px;"
                phx-hook="CanvasPlayer"
                data-strokes={Jason.encode!(@post.canvas_data["strokes"] || [])}
                data-grid={Jason.encode!(@post.canvas_data["grid"] || %{})}
                data-background={@post.canvas_data["background"]}
              >
                <div
                  id={"canvas-player-#{@post.id}"}
                  class="canvas-player-container w-full h-full"
                  phx-update="ignore"
                >
                </div>
              </div>
            <% end %>

            <%= if @post.content do %>
              <%= if WhiteBoardPostRenderer.emoji_only?(@post.content) do %>
                <div class="mt-2 text-center text-5xl leading-none py-2">
                  {raw(
                    WhiteBoardPostRenderer.render_post_content(
                      @post.content,
                      @post.id,
                      @current_scope.current_user
                    )
                  )}
                </div>
              <% else %>
                <%= if WhiteBoardPostRenderer.command_only?(@post.content) do %>
                  <div class="mt-2 flex justify-center">
                    {raw(
                      WhiteBoardPostRenderer.render_post_content(
                        @post.content,
                        @post.id,
                        @current_scope.current_user
                      )
                    )}
                  </div>
                <% else %>
                  <%= if WhiteBoardPostRenderer.photo_only?(@post.content) do %>
                    <div class="mt-2">
                      {raw(
                        WhiteBoardPostRenderer.render_post_content(
                          @post.content,
                          @post.id,
                          @current_scope.current_user
                        )
                      )}
                    </div>
                  <% else %>
                    <div class="mt-2 prose prose-sm dark:prose-invert max-w-none">
                      {raw(
                        WhiteBoardPostRenderer.render_post_content(
                          @post.content,
                          @post.id,
                          @current_scope.current_user
                        )
                      )}
                    </div>
                  <% end %>
                <% end %>
              <% end %>
            <% end %>

            <%!-- Reactions --%>
            <div class="mt-4 flex items-center gap-2 flex-wrap">
              <%= for {emoji, data} <- Map.get(@reactions, @post.id, %{}) do %>
                <button
                  phx-click="toggle_reaction"
                  phx-value-post-id={@post.id}
                  phx-value-emoji={emoji}
                  class={[
                    "badge badge-sm gap-1 cursor-pointer transition-all",
                    (data.me? && "badge-primary") || "badge-ghost"
                  ]}
                >
                  <span>{emoji}</span>
                  <span class="text-xs">{data.count}</span>
                </button>
              <% end %>
              <div class="dropdown dropdown-top">
                <button tabindex="0" class="btn btn-ghost btn-xs">
                  <.icon name="hero-face-smile" class="w-4 h-4" />
                </button>
                <div
                  tabindex="0"
                  class="dropdown-content bg-base-100 rounded-xl shadow-lg border border-base-300 p-2 z-[1] max-w-[90vw]"
                >
                  <div class="grid grid-cols-5 gap-1 w-48 max-w-full max-h-60 overflow-y-auto">
                    <%= for emoji <- Enum.take(all_emojis(), 30) do %>
                      <button
                        phx-click="toggle_reaction"
                        phx-value-post-id={@post.id}
                        phx-value-emoji={emoji}
                        class="btn btn-ghost btn-xs sm:btn-sm text-lg min-w-[36px] min-h-[36px] sm:min-w-0 sm:min-h-0"
                      >
                        {emoji}
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Comments --%>
            <%= if length(@comments) > 0 || @current_scope.current_user do %>
              <div class="mt-4 pt-4 border-t border-base-300">
                <%!-- Comments List --%>
                <div class="space-y-3 mb-3">
                  <%= for comment <- @comments do %>
                    <div class="flex gap-2">
                      <.link navigate={~p"/users/#{comment.user_id}"}>
                        <% avatar_src =
                          (comment.user.profile && comment.user.profile.avatar) ||
                            comment.user.avatar_url %>
                        <%= if avatar_src do %>
                          <img
                            src={avatar_src}
                            class="w-6 h-6 rounded-full object-cover flex-shrink-0"
                          />
                        <% else %>
                          <div class="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                            <.icon name="hero-user" class="w-3 h-3 text-primary/50" />
                          </div>
                        <% end %>
                      </.link>
                      <div class="flex-1 min-w-0">
                        <div class="bg-base-200 rounded-lg px-3 py-2">
                          <p class="text-xs font-semibold text-base-content">
                            {(comment.user.profile && comment.user.profile.display_name) ||
                              comment.user.name}
                          </p>
                          <p class="text-sm text-base-content mt-0.5">
                            {raw(
                              WhiteBoardPostRenderer.render_comment_content(
                                comment.content,
                                @current_scope.current_user
                              )
                            )}
                          </p>
                        </div>
                        <p class="text-xs text-base-content/50 mt-0.5 ml-1">
                          {format_localized_datetime(comment.inserted_at)}
                        </p>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%!-- Add Comment --%>
                <%= if @current_scope.current_user do %>
                  <form
                    id="comment-form-post"
                    phx-submit="add_comment"
                    phx-hook="CommentInput"
                    class="flex gap-2 flex-wrap sm:flex-nowrap"
                    data-can-upload-video={
                      if @current_scope && @current_scope.current_user &&
                           Medoru.Accounts.User.teacher?(@current_scope.current_user),
                         do: "true",
                         else: "false"
                    }
                  >
                    <input type="hidden" name="post_id" value={@post.id} />
                    <input
                      type="text"
                      name="content"
                      placeholder={gettext("Write a comment...")}
                      class="input input-bordered input-sm flex-1 text-base"
                      autocomplete="off"
                    />
                    <input type="file" data-comment-file-input class="hidden" />
                    <button
                      type="button"
                      data-comment-attachment-btn
                      class="btn btn-ghost btn-sm btn-circle shrink-0"
                      title={gettext("Attach file")}
                    >
                      <.icon name="hero-paper-clip" class="w-4 h-4" />
                    </button>
                    <button type="submit" class="btn btn-primary btn-sm shrink-0">
                      <.icon name="hero-paper-airplane" class="w-4 h-4" />
                    </button>
                  </form>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"user_id" => _user_id, "post_id" => post_id}, _session, socket) do
    case Ecto.UUID.cast(post_id) do
      {:ok, uuid} ->
        current_user = socket.assigns.current_scope[:current_user]
        viewer_id = current_user && current_user.id

        try do
          post = WhiteBoard.get_post!(uuid, viewer_id)
          post = Repo.preload(post, user: [:profile])

          comments = WhiteBoard.list_comments_for_post(uuid, viewer_id)
          reactions = WhiteBoard.list_reactions_for_posts([post.id], viewer_id)

          if connected?(socket) do
            WhiteBoard.subscribe_to_board(post.user_id)
          end

          {:ok,
           socket
           |> assign(:page_title, gettext("Post"))
           |> assign(:post, post)
           |> assign(:comments, comments)
           |> assign(:reactions, reactions)}
        rescue
          Ecto.NoResultsError ->
            {:ok,
             socket
             |> put_flash(:error, gettext("Post not found."))
             |> push_navigate(to: ~p"/")}
        end

      :error ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Invalid post ID."))
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("toggle_reaction", %{"post-id" => post_id, "emoji" => emoji}, socket) do
    user_id = socket.assigns.current_scope.current_user.id

    case WhiteBoard.toggle_reaction(post_id, user_id, emoji) do
      {:ok, added, removed} ->
        reactions =
          update_reaction_map(
            socket.assigns.reactions,
            post_id,
            added && emoji,
            removed && removed.emoji
          )

        WhiteBoard.broadcast_reaction(
          socket.assigns.post.user_id,
          post_id,
          user_id,
          added && emoji,
          removed && removed.emoji,
          self()
        )

        {:noreply, assign(socket, :reactions, reactions)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_comment", params, socket) do
    user_id = socket.assigns.current_scope.current_user.id
    post_id = String.trim(params["post_id"] || "")
    content = String.trim(params["content"] || "")

    if content == "" do
      {:noreply, socket}
    else
      attrs = %{
        post_id: post_id,
        user_id: user_id,
        parent_id: nil,
        content: content
      }

      case WhiteBoard.create_comment(attrs) do
        {:ok, comment} ->
          comment = Repo.preload(comment, user: [:profile])
          WhiteBoard.broadcast_comment(socket.assigns.post.user_id, comment, self())

          comments = socket.assigns.comments ++ [comment]
          {:noreply, assign(socket, :comments, comments)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not add comment."))}
      end
    end
  end

  @impl true
  def handle_info({:reaction, post_id, _user_id_reacting, added_emoji, removed_emoji}, socket) do
    if post_id == socket.assigns.post.id do
      reactions =
        update_reaction_map_from_broadcast(
          socket.assigns.reactions,
          post_id,
          added_emoji,
          removed_emoji,
          false
        )

      {:noreply, assign(socket, :reactions, reactions)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:comment, comment}, socket) do
    current_user_id = socket.assigns.current_scope.current_user.id

    unless Medoru.Social.blocked_by?(current_user_id, comment.user_id) do
      comments = socket.assigns.comments ++ [comment]
      {:noreply, assign(socket, :comments, comments)}
    else
      {:noreply, socket}
    end
  end

  defp all_emojis do
    ~w(😀 😁 😂 🤣 😃 😄 😅 😆 😉 😊 😋 😎 😍 😘 😗 😙 😚 ☺️ 🙂 🤗 🤩 🤔 🤨 😐 😑 😶 🙄 😏 😣 😥 😮 🤐 😯 😪 😫 😴 😌 😛 😜 😝 🤤 😒 😓 😔 😕 🙃 🤑 😲 ☹️ 🙁 😖 😞 😟 😤 😢 😭 😦 😧
😨 😩 🤯 😬 😰 😱 😳 🤪 😵 😡 😠 🤬 😷 🤒 🤕 🤢 🤮 🤧 😇 🤠 🤡 🤥 🤫 🤭 🧐 🤓 😈 👿 👹 👺 💀 👻 👽 🤖 💩 😺 😸 😹 😻 😼 😽 🙀 😿 😾 🥰 🥳 🫡 ❤️ 💕 💔 👍 👎 🙏 🎉 🎊 🎵 🎮 🎲
🎯 🔥 ✨ 💯 ⭐ 🌈 🌙 🌸 🍀 🎌 🗾 🐱 🐶 🦊 🐼 🍜 🍱 🍡 🍣 🍙 🍥 🍘 🍮 🗡️ 🏴‍☠️ 🇧🇬 🇯🇵 🐭 🐹 🐰 🐻 🐨 🐯 🦁 🐮 🐷 🐽 🐸 🐵 🙈 🙉 🙊 🐒 🐔 🐧 🐦 🐤 🐣 🐥 🦆 🦅 🦉 🦇 🐺 🐗 🐴
🦄 🐝 🐛 🦋 🐌 🐚 🐞 🐜 🦗 🕷 🕸 🦂 🐢 🐍 🦎 🦖 🦕 🐙 🦑 🦐 🦀 🐡 🐠 🐟 🐬 🐳 🐋 🦈 🐊 🐅 🐆 🦓 🦍 🐘 🦏 🐪 🐫 🦒 🐃 🐂 🐄 🐎 🐖 🐏 🐑 🐐 🦌 🐕 🐩 🐈 🐓 🦃 🕊 🐇 🐁 🐀 🐿 🦔 🐾
🐉 🐲 🌵 🎄 🌲 🌳 🌴 🌱 🌿 ☘️ 🍃 🍂 🍁 🍄 🌾 💐 🌷 🌹 🥀 🌺 🌼 🌻 🌞 🌝 🌛 🌜 🌚 🌕 🌖 🌗 🌘 🌑 🌒 🌓 🌔 🌎 🌍 🌏 💫 ⭐️ 🌟 ⚡️ ☄️ 💥 🌪 ☀️ 🌤 ⛅️ 🌥 ☁️ 🌦 🌧 ⛈ 🌩 🌨
❄️ ☃️ ⛄️ 🌬 💨 💧 💦 ☔️ ☂️ 🌊 🌫 🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🍈 🍒 🍑 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥒 🌶 🌽 🥕 🥔 🍠 🥐 🍞 🥖 🥨 🧀 🥚 🍳 🥞 🥓 🥩 🍗 🍖 🌭 🍔 🍟 🍕 🥪 🥙 🌮 🌯
🥗 🥘 🥫 🍝 🍲 🍛 🥟 🍤 🍚 🥠 🍢 🍧 🍨 🍦 🥧 🍰 🎂 🍭 🍬 🍫 🍿 🍩 🍪 🌰 🥜 🍯 🥛 🍼 ☕️ 🍵 🥤 🍶 🍺 🍻 🥂 🍷 🥃 🍸 🍹 🍾 🥄 🍴 🍽 🥣 🥡 🥢) ++
      [":ouroboros:", ":medoru:"]
  end

  defp update_reaction_map(reactions, post_id, added_emoji, removed_emoji) do
    post_reactions = Map.get(reactions, post_id, %{})

    post_reactions =
      if removed_emoji && removed_emoji != added_emoji do
        current = Map.get(post_reactions, removed_emoji, %{count: 0, me?: false})
        new_count = max(current.count - 1, 0)

        if new_count == 0,
          do: Map.delete(post_reactions, removed_emoji),
          else: Map.put(post_reactions, removed_emoji, %{count: new_count, me?: false})
      else
        post_reactions
      end

    post_reactions =
      cond do
        is_nil(added_emoji) && removed_emoji ->
          post_reactions

        added_emoji && added_emoji == removed_emoji ->
          post_reactions

        added_emoji ->
          current = Map.get(post_reactions, added_emoji, %{count: 0, me?: false})
          Map.put(post_reactions, added_emoji, %{count: current.count + 1, me?: true})

        true ->
          post_reactions
      end

    Map.put(reactions, post_id, post_reactions)
  end

  defp update_reaction_map_from_broadcast(reactions, post_id, added_emoji, removed_emoji, me?) do
    post_reactions = Map.get(reactions, post_id, %{})

    post_reactions =
      if removed_emoji && removed_emoji != added_emoji do
        current = Map.get(post_reactions, removed_emoji, %{count: 0, me?: false})
        new_count = max(current.count - 1, 0)

        if new_count == 0,
          do: Map.delete(post_reactions, removed_emoji),
          else: Map.put(post_reactions, removed_emoji, %{count: new_count, me?: me?})
      else
        post_reactions
      end

    post_reactions =
      cond do
        is_nil(added_emoji) && removed_emoji ->
          post_reactions

        added_emoji && added_emoji == removed_emoji ->
          current = Map.get(post_reactions, added_emoji, %{count: 0, me?: false})
          new_count = max(current.count - 1, 0)

          if new_count == 0,
            do: Map.delete(post_reactions, added_emoji),
            else: Map.put(post_reactions, added_emoji, %{count: new_count, me?: me?})

        added_emoji ->
          current = Map.get(post_reactions, added_emoji, %{count: 0, me?: false})
          Map.put(post_reactions, added_emoji, %{count: current.count + 1, me?: me?})

        true ->
          post_reactions
      end

    Map.put(reactions, post_id, post_reactions)
  end
end
