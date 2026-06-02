defmodule MedoruWeb.UserWhiteBoardLive do
  @moduledoc """
  User white board - personal wall for posts, drawings, reactions, and comments.
  """
  use MedoruWeb, :live_view

  import Ecto.Query, warn: false

  alias Medoru.{Accounts, Content, Repo, WhiteBoard}
  alias Medoru.WhiteBoard.BoardComment
  alias MedoruWeb.{KanjiChatPreview, WordChatPreview}

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
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} socket={@socket}>
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Header --%>
        <div class="mb-6">
          <div class="flex items-center gap-3 mb-2">
            <.link navigate={~p"/users/#{@user.id}"} class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> {gettext("Profile")}
            </.link>
            <h1 class="text-2xl font-bold text-base-content">
              {gettext("%{name}'s White Board", name: (@profile && @profile.display_name) || @user.name)}
            </h1>
          </div>
          <p class="text-secondary text-sm">
            {@post_count} {gettext("posts")}
          </p>
        </div>

        <%!-- Create Post Form (owner only) --%>
        <%= if @is_owner do %>
          <div class="card bg-base-100 border border-base-300 mb-6">
            <div class="card-body p-4 sm:p-6">
              <%= if @show_canvas_modal do %>
                <%!-- Canvas Drawing Modal --%>
                <div
                  id="free-draw-container"
                  phx-hook="FreeDraw"
                  class="space-y-4"
                >
                  <div class="flex flex-nowrap sm:flex-wrap items-center gap-2 overflow-x-auto pb-1 sm:pb-0 -mx-1 px-1">
                    <button data-draw-tool="pencil" class="active-tool btn btn-sm btn-ghost">
                      <.icon name="hero-pencil" class="w-4 h-4" />
                    </button>
                    <button data-draw-tool="eraser" class="btn btn-sm btn-ghost">
                      <.icon name="hero-backspace" class="w-4 h-4" />
                    </button>
                    <div class="flex gap-1">
                      <%= for color <- ["#000000", "#ef4444", "#f97316", "#eab308", "#22c55e", "#3b82f6", "#a855f7", "#ec4899"] do %>
                        <button
                          data-draw-color={color}
                          class="w-6 h-6 rounded-full ring-offset-1"
                          style={"background-color: #{color}"}
                        >
                        </button>
                      <% end %>
                    </div>
                    <div class="flex gap-1">
                      <%= for {grid, icon, label} <- [
                        {"none", "hero-x-mark", gettext("No grid")},
                        {"line-small", "hero-squares-plus", gettext("Small grid")},
                        {"line", "hero-table-cells", gettext("Medium grid")},
                        {"line-large", "hero-view-columns", gettext("Large grid")}
                      ] do %>
                        <button
                          type="button"
                          data-draw-grid={grid}
                          class={["btn btn-xs btn-ghost", grid == "none" && "btn-active"]}
                          title={label}
                        >
                          <.icon name={icon} class="w-4 h-4" />
                        </button>
                      <% end %>
                    </div>
                    <input
                      data-draw-width
                      type="range"
                      min="1"
                      max="10"
                      value="3"
                      class="w-24"
                    />
                    <button data-draw-action="undo" class="btn btn-sm btn-ghost">
                      <.icon name="hero-arrow-uturn-left" class="w-4 h-4" />
                    </button>
                    <button data-draw-action="clear" class="btn btn-sm btn-ghost">
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </button>
                    <label class="btn btn-sm btn-ghost cursor-pointer" title={gettext("Background image")}>
                      <.icon name="hero-photo" class="w-4 h-4" />
                      <input
                        type="file"
                        data-draw-background-input
                        class="hidden"
                        accept="image/*"
                      />
                    </label>
                    <button data-draw-action="clear-background" class="btn btn-sm btn-ghost" title={gettext("Clear background")}>
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>

                  <div
                    id="free-draw-canvas"
                    class="free-draw-canvas-container bg-white rounded-xl border border-base-300"
                    style="width: 100%; height: min(400px, 60vw); max-height: 400px;"
                    phx-update="ignore"
                  >
                  </div>

                  <form class="space-y-3">
                    <input
                      type="text"
                      name="title"
                      value={@canvas_title}
                      phx-change="update_canvas_title"
                      class="input input-bordered w-full"
                      placeholder={gettext("Title (optional)...")}
                    />
                    <textarea
                      name="content"
                      phx-change="update_canvas_description"
                      class="textarea textarea-bordered w-full"
                      rows="2"
                      placeholder={gettext("Description...")}
                    >{@canvas_description}</textarea>
                    <label class="flex items-center gap-2 text-sm cursor-pointer">
                      <input type="checkbox" data-draw-keep-grid class="checkbox checkbox-sm" />
                      {gettext("Keep grid in final image")}
                    </label>
                    <div class="flex gap-2 justify-end">
                      <button type="button" phx-click="close_canvas" class="btn btn-ghost btn-sm">
                        {gettext("Cancel")}
                      </button>
                      <button type="button" data-draw-action="post" class="btn btn-primary btn-sm">
                        <.icon name="hero-paper-airplane" class="w-4 h-4 mr-1" /> {gettext("Post")}
                      </button>
                    </div>
                  </form>
                </div>
              <% else %>
                <%!-- Text Post Form --%>
                <div phx-hook="BoardInput" id="board-input-form">
                  <form phx-submit="create_post" class="space-y-3">
                    <input
                      type="text"
                      name="title"
                      value={@post_form[:title]}
                      class="input input-bordered w-full"
                      placeholder={gettext("Title (optional)...")}
                    />
                    <textarea
                      name="content"
                      class="textarea textarea-bordered w-full"
                      rows="3"
                      placeholder={gettext("Write something on your board...")}
                    ></textarea>
                    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                      <div class="flex items-center gap-2 flex-wrap">
                        <label class="flex items-center gap-2 text-sm cursor-pointer">
                          <input
                            type="checkbox"
                            name="public"
                            class="checkbox checkbox-sm"
                          />
                          {gettext("Public")}
                        </label>
                        <%!-- Voice recording --%>
                        <div class="relative">
                          <button
                            type="button"
                            data-board-voice-btn
                            class="btn btn-ghost btn-xs text-base-content/60"
                            title={gettext("Voice message")}
                          >
                            <.icon name="hero-microphone" class="w-4 h-4" />
                          </button>
                          <span
                            data-board-voice-status
                            class="hidden absolute -top-2 -right-2 bg-error text-error-content text-xs font-bold px-1.5 py-0.5 rounded-full"
                          >
                            0s
                          </span>
                        </div>
                        <%!-- Emoji picker --%>
                        <div class="relative">
                          <button
                            type="button"
                            data-board-emoji-btn
                            class="btn btn-ghost btn-xs"
                            title={gettext("Emoji")}
                          >
                            <.icon name="hero-face-smile" class="w-4 h-4" />
                          </button>
                          <div
                            data-board-emoji-panel
                            class="hidden absolute bottom-full right-0 sm:left-0 mb-1 bg-base-100 rounded-xl shadow-lg border border-base-300 p-3 z-10 w-72 max-w-[90vw]"
                          >
                            <% all_emojis = all_emojis() %>
                            <% pages = Enum.chunk_every(all_emojis, 48) %>
                            <div class="emoji-pages">
                              <%= for {page_emojis, page_idx} <- Enum.with_index(pages) do %>
                                <div class={["emoji-page grid grid-cols-8 gap-2", page_idx != 0 && "hidden"]} data-page={page_idx}>
                                  <%= for emoji <- page_emojis do %>
                                    <%= if emoji in [":medoru:", ":ouroboros:"] do %>
                                      <button
                                        type="button"
                                        data-emoji={emoji}
                                        class="hover:bg-base-200 rounded-lg p-1 transition-colors flex items-center justify-center"
                                      >
                                        <img src={if emoji == ":medoru:", do: "/favicon.png", else: "/images/ouroboros.png"} class="w-6 h-6 object-contain pointer-events-none" />
                                      </button>
                                    <% else %>
                                      <button
                                        type="button"
                                        data-emoji={emoji}
                                        class="text-2xl hover:bg-base-200 rounded-lg p-1 transition-colors"
                                      >
                                        {emoji}
                                      </button>
                                    <% end %>
                                  <% end %>
                                </div>
                              <% end %>
                            </div>
                            <div class="flex justify-between items-center mt-2 pt-2 border-t border-base-300">
                              <button type="button" class="emoji-page-prev btn btn-ghost btn-xs" disabled>
                                <.icon name="hero-chevron-left" class="w-4 h-4" />
                              </button>
                              <span class="emoji-page-info text-xs text-base-content/60">1 / <%= length(pages) %></span>
                              <button type="button" class="emoji-page-next btn btn-ghost btn-xs">
                                <.icon name="hero-chevron-right" class="w-4 h-4" />
                              </button>
                            </div>
                          </div>
                        </div>
                        <%!-- File upload --%>
                        <button
                          type="button"
                          data-board-attachment-btn
                          class="btn btn-ghost btn-xs"
                          title={gettext("Attach file")}
                        >
                          <.icon name="hero-paper-clip" class="w-4 h-4" />
                        </button>
                        <input
                          type="file"
                          data-board-file-input
                          class="hidden"
                          accept="image/*,audio/*"
                        />
                      </div>
                      <div class="flex gap-2">
                        <button type="button" phx-click="open_canvas" class="btn btn-secondary btn-sm">
                          <.icon name="hero-paint-brush" class="w-4 h-4 mr-1" /> {gettext("Draw")}
                        </button>
                        <button type="submit" class="btn btn-primary btn-sm">
                          <.icon name="hero-paper-airplane" class="w-4 h-4 mr-1" /> {gettext("Post")}
                        </button>
                      </div>
                    </div>
                  </form>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Posts Feed --%>
        <div class="space-y-6">
          <%= for post <- @posts do %>
            <div class="card bg-base-100 border border-base-300" id={"post-#{post.id}"}>
              <div class="card-body p-4 sm:p-6">
                <%!-- Post Header --%>
                <div class="flex items-start justify-between">
                  <div class="flex items-center gap-3 min-w-0">
                    <%= if post.user.profile && post.user.profile.avatar do %>
                      <img src={post.user.profile.avatar} class="w-10 h-10 rounded-full object-cover shrink-0" />
                    <% else %>
                      <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                        <.icon name="hero-user" class="w-5 h-5 text-primary/50" />
                      </div>
                    <% end %>
                    <div class="min-w-0">
                      <p class="font-semibold text-base-content truncate">
                        {(post.user.profile && post.user.profile.display_name) || post.user.name}
                      </p>
                      <p class="text-xs text-base-content/50 truncate">
                        {Calendar.strftime(post.inserted_at, "%B %d, %Y")}
                        <%= if post.visibility == "followers" do %>
                          <span class="badge badge-xs badge-ghost ml-1">{gettext("Followers")}</span>
                        <% end %>
                      </p>
                    </div>
                  </div>
                  <%= if @is_owner do %>
                    <div class="flex items-center gap-1 shrink-0">
                      <button
                        type="button"
                        phx-click="toggle_visibility"
                        phx-value-id={post.id}
                        class="btn btn-ghost btn-xs"
                        title={if(post.visibility == "public", do: gettext("Public"), else: gettext("Followers only"))}
                      >
                        <%= if post.visibility == "public" do %>
                          <.icon name="hero-globe-alt" class="w-4 h-4 text-success" />
                        <% else %>
                          <.icon name="hero-lock-closed" class="w-4 h-4 text-warning" />
                        <% end %>
                      </button>
                      <div class="dropdown dropdown-end">
                        <button tabindex="0" class="btn btn-ghost btn-xs">
                          <.icon name="hero-ellipsis-vertical" class="w-4 h-4" />
                        </button>
                      <ul tabindex="0" class="dropdown-content menu menu-sm bg-base-100 rounded-box z-[1] w-32 p-2 shadow border border-base-300">
                        <li>
                          <button phx-click="edit_post" phx-value-id={post.id}>
                            <.icon name="hero-pencil" class="w-4 h-4" /> {gettext("Edit")}
                          </button>
                        </li>
                        <li>
                          <button
                            phx-click="delete_post"
                            phx-value-id={post.id}
                            data-confirm={gettext("Delete this post?")}
                            class="text-error"
                          >
                            <.icon name="hero-trash" class="w-4 h-4" /> {gettext("Delete")}
                          </button>
                        </li>
                      </ul>
                    </div>
                    </div>
                  <% end %>
                </div>

                <%!-- Post Content --%>
                <%= if @editing_post_id == post.id do %>
                  <form phx-submit="update_post" class="mt-3 space-y-2">
                    <input type="hidden" name="post_id" value={post.id} />
                    <input
                      type="text"
                      name="title"
                      value={post.title}
                      class="input input-bordered w-full input-sm"
                    />
                    <textarea
                      name="content"
                      class="textarea textarea-bordered w-full textarea-sm"
                      rows="3"
                    >{post.content}</textarea>
                    <div class="flex gap-2 justify-end">
                      <button type="button" phx-click="cancel_edit_post" class="btn btn-ghost btn-sm">
                        {gettext("Cancel")}
                      </button>
                      <button type="submit" class="btn btn-primary btn-sm">
                        {gettext("Save")}
                      </button>
                    </div>
                  </form>
                <% else %>
                  <%= if post.title do %>
                    <h3 class="text-lg font-bold text-base-content mt-2">{post.title}</h3>
                  <% end %>

                  <%= if post.post_type == "canvas" && post.canvas_data do %>
                    <div
                      id={"canvas-wrapper-#{post.id}"}
                      class="mt-3 rounded-xl border border-base-300 overflow-hidden"
                      style="width: 100%; height: min(400px, 60vw); max-height: 400px;"
                      phx-hook="CanvasPlayer"
                      data-strokes={Jason.encode!(post.canvas_data["strokes"] || [])}
                      data-grid={Jason.encode!(post.canvas_data["grid"] || %{})}
                      data-background={post.canvas_data["background"]}
                    >
                      <div id={"canvas-player-#{post.id}"} class="canvas-player-container w-full h-full" phx-update="ignore"></div>
                    </div>
                  <% end %>

                  <%= if post.content do %>
                    <%= if emoji_only?(post.content) do %>
                      <div class="mt-2 text-center text-5xl leading-none py-2">
                        {raw(render_post_content(post.content, post.id))}
                      </div>
                    <% else %>
                      <%= if command_only?(post.content) do %>
                        <div class="mt-2 flex justify-center">
                          {raw(render_post_content(post.content, post.id))}
                        </div>
                      <% else %>
                        <%= if photo_only?(post.content) do %>
                          <div class="mt-2">
                            {raw(render_post_content(post.content, post.id))}
                          </div>
                        <% else %>
                          <div class="mt-2 prose prose-sm dark:prose-invert max-w-none">
                            {raw(render_post_content(post.content, post.id))}
                          </div>
                        <% end %>
                      <% end %>
                    <% end %>
                  <% end %>
                <% end %>

                <%!-- Reactions --%>
                <div class="mt-4 flex items-center gap-2 flex-wrap">
                  <% reactions = Map.get(@reactions, post.id, %{}) %>
                  <%= for {emoji, data} <- reactions do %>
                    <button
                      phx-click="toggle_reaction"
                      phx-value-post-id={post.id}
                      phx-value-emoji={emoji}
                      class={[
                        "badge badge-sm gap-1 cursor-pointer transition-all",
                        data.me? && "badge-primary" || "badge-ghost"
                      ]}
                    >
                      <span>{emoji}</span>
                      <span class={data.me? && "text-primary-content" || "text-base-content/60"}>
                        {data.count}
                      </span>
                    </button>
                  <% end %>

                  <%!-- Emoji Picker --%>
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
                            phx-value-post-id={post.id}
                            phx-value-emoji={emoji}
                            class="btn btn-ghost btn-xs text-lg"
                          >
                            {emoji}
                          </button>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>

                <%!-- Comments Section --%>
                <% comments = Map.get(@comments, post.id, []) %>
                <%= if length(comments) > 0 || @is_owner || @current_scope.current_user do %>
                  <div class="mt-4 pt-4 border-t border-base-300">
                    <%!-- Comments List --%>
                    <div class="space-y-3 mb-3">
                      <%= for comment <- comments do %>
                        <div class="flex gap-2">
                          <%= if comment.user.profile && comment.user.profile.avatar do %>
                            <img src={comment.user.profile.avatar} class="w-6 h-6 rounded-full object-cover flex-shrink-0" />
                          <% else %>
                            <div class="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                              <.icon name="hero-user" class="w-3 h-3 text-primary/50" />
                            </div>
                          <% end %>
                          <div class="flex-1 min-w-0">
                            <%= if comment.parent_comment do %>
                              <div class="mb-1 pl-2 border-l-2 border-base-300">
                                <p class="text-[10px] text-base-content/40">
                                  {gettext("Replying to %{name}", name: (comment.parent_comment.user.profile && comment.parent_comment.user.profile.display_name) || comment.parent_comment.user.name)}
                                </p>
                                <p class="text-xs text-base-content/50 truncate">
                                  {comment.parent_comment.content}
                                </p>
                              </div>
                            <% end %>
                            <div class="bg-base-200 rounded-lg px-3 py-2">
                              <p class="text-xs font-semibold text-base-content">
                                {(comment.user.profile && comment.user.profile.display_name) || comment.user.name}
                              </p>
                              <p class="text-sm text-base-content/80">{comment.content}</p>
                            </div>
                            <div class="flex items-center gap-3 mt-1 ml-1">
                              <button
                                phx-click="reply_to_comment"
                                phx-value-post-id={post.id}
                                phx-value-comment-id={comment.id}
                                class="text-xs text-base-content/50 hover:text-primary"
                              >
                                {gettext("Reply")}
                              </button>
                              <%= if comment.user_id == @current_scope.current_user.id do %>
                                <button
                                  phx-click="delete_comment"
                                  phx-value-id={comment.id}
                                  data-confirm={gettext("Delete this comment?")}
                                  class="text-xs text-error/70 hover:text-error"
                                >
                                  {gettext("Delete")}
                                </button>
                              <% end %>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>

                    <%!-- Comment Input --%>
                    <%= if @current_scope.current_user do %>
                      <% reply_target = Map.get(@replying_to, post.id) %>
                      <form phx-submit="add_comment" class="flex gap-2 flex-wrap sm:flex-nowrap">
                        <input type="hidden" name="post_id" value={post.id} />
                        <%= if reply_target do %>
                          <input type="hidden" name="parent_id" value={reply_target} />
                        <% end %>
                        <input
                          type="text"
                          name="content"
                          class="input input-bordered input-sm flex-1"
                          placeholder={
                            if reply_target,
                              do: gettext("Write a reply..."),
                              else: gettext("Write a comment...")
                          }
                          required
                        />
                        <%= if reply_target do %>
                          <button type="button" phx-click="cancel_reply" phx-value-post-id={post.id} class="btn btn-ghost btn-sm">
                            {gettext("Cancel")}
                          </button>
                        <% end %>
                        <button type="submit" class="btn btn-primary btn-sm shrink-0">
                          <.icon name="hero-paper-airplane" class="w-4 h-4" />
                        </button>
                      </form>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Load More --%>
        <%= if @has_more do %>
          <div class="mt-6 text-center">
            <button phx-click="load_more" class="btn btn-outline btn-wide">
              {gettext("Load more")}
            </button>
          </div>
        <% end %>

        <%= if @posts == [] do %>
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body text-center py-12">
              <.icon name="hero-document-text" class="w-16 h-16 text-base-content/20 mx-auto mb-4" />
              <h2 class="text-xl font-bold text-base-content">
                {gettext("No posts yet")}
              </h2>
              <p class="text-secondary">
                <%= if @is_owner do %>
                  {gettext("Write something on your board or draw!")}
                <% else %>
                  {gettext("This user hasn't posted anything yet.")}
                <% end %>
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        user = Accounts.get_user_with_profile!(uuid)
        current_user = socket.assigns.current_scope[:current_user]
        is_owner = current_user && current_user.id == user.id

        viewer_id = current_user && current_user.id

        posts = WhiteBoard.list_posts(user.id, viewer_id, page: 1)
        post_count = WhiteBoard.count_posts(user.id, viewer_id)
        has_more = length(posts) < post_count

        post_ids = Enum.map(posts, & &1.id)
        reactions = WhiteBoard.list_reactions_for_posts(post_ids, viewer_id)
        comments = load_comments_for_posts(posts)

        if connected?(socket) do
          WhiteBoard.subscribe_to_board(user.id)
        end

        {:ok,
         socket
         |> assign(:page_title, gettext("%{name}'s White Board", name: (user.profile && user.profile.display_name) || user.name))
         |> assign(:user, user)
         |> assign(:profile, user.profile)
         |> assign(:is_owner, is_owner)
         |> assign(:posts, posts)
         |> assign(:post_count, post_count)
         |> assign(:reactions, reactions)
         |> assign(:comments, comments)
         |> assign(:page, 1)
         |> assign(:has_more, has_more)
         |> assign(:post_form, %{title: nil, content: nil})
         |> assign(:show_canvas_modal, false)
         |> assign(:canvas_title, "")
         |> assign(:canvas_description, "")
         |> assign(:editing_post_id, nil)
         |> assign(:replying_to, %{})}

      :error ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Invalid user ID."))
         |> push_navigate(to: ~p"/")}
    end
  end

  # ============================================================================
  # Post Events
  # ============================================================================

  @impl true
  def handle_event("create_post", params, socket) do
    user = socket.assigns.current_scope.current_user

    attrs = %{
      user_id: user.id,
      title: clean_string(params["title"]),
      content: clean_string(params["content"]),
      visibility: if(params["public"] == "on", do: "public", else: "followers"),
      post_type: "text"
    }

    case WhiteBoard.create_post(attrs) do
      {:ok, post} ->
        post = Repo.preload(post, user: [:profile])
        WhiteBoard.broadcast_post_created(socket.assigns.user.id, post)

        {:noreply,
         socket
         |> assign(:post_form, %{title: nil, content: nil})
         |> put_flash(:info, gettext("Post created!"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not create post."))}
    end
  end

  @impl true
  def handle_event("save_canvas", params, socket) do
    strokes = params["strokes"] || []
    grid = params["grid"]
    background = params["background"]
    user = socket.assigns.current_scope.current_user

    canvas_data = %{"strokes" => strokes}
    canvas_data = if grid, do: Map.put(canvas_data, "grid", grid), else: canvas_data
    canvas_data = if background, do: Map.put(canvas_data, "background", background), else: canvas_data

    attrs = %{
      user_id: user.id,
      title: clean_string(socket.assigns.canvas_title),
      content: clean_string(socket.assigns.canvas_description),
      visibility: "followers",
      post_type: "canvas",
      canvas_data: canvas_data
    }

    case WhiteBoard.create_post(attrs) do
      {:ok, post} ->
        post = Repo.preload(post, user: [:profile])
        WhiteBoard.broadcast_post_created(socket.assigns.user.id, post)

        {:noreply,
         socket
         |> assign(:show_canvas_modal, false)
         |> assign(:canvas_title, "")
         |> assign(:canvas_description, "")
         |> put_flash(:info, gettext("Drawing posted!"))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not post drawing."))}
    end
  end

  @impl true
  def handle_event("edit_post", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_post_id, id)}
  end

  @impl true
  def handle_event("cancel_edit_post", _params, socket) do
    {:noreply, assign(socket, :editing_post_id, nil)}
  end

  @impl true
  def handle_event("update_post", params, socket) do
    post = Enum.find(socket.assigns.posts, &(&1.id == params["post_id"]))

    if post && socket.assigns.is_owner do
      attrs = %{
        title: clean_string(params["title"]),
        content: clean_string(params["content"])
      }

      case WhiteBoard.update_post(post, attrs) do
        {:ok, updated} ->
          updated = Repo.preload(updated, user: [:profile])
          WhiteBoard.broadcast_post_updated(socket.assigns.user.id, updated)
          {:noreply, assign(socket, :editing_post_id, nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not update post."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_post", %{"id" => id}, socket) do
    post = Enum.find(socket.assigns.posts, &(&1.id == id))

    if post && socket.assigns.is_owner do
      WhiteBoard.delete_post(post)
      WhiteBoard.broadcast_post_deleted(socket.assigns.user.id, id)
      {:noreply, put_flash(socket, :info, gettext("Post deleted."))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_visibility", %{"id" => id}, socket) do
    post = Enum.find(socket.assigns.posts, &(&1.id == id))

    if post && socket.assigns.is_owner do
      new_visibility = if post.visibility == "public", do: "followers", else: "public"

      case WhiteBoard.update_post(post, %{visibility: new_visibility}) do
        {:ok, updated} ->
          updated = Repo.preload(updated, user: [:profile])
          WhiteBoard.broadcast_post_updated(socket.assigns.user.id, updated)
          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not update visibility."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_canvas", _params, socket) do
    {:noreply, assign(socket, :show_canvas_modal, true)}
  end

  @impl true
  def handle_event("close_canvas", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_canvas_modal, false)
     |> assign(:canvas_title, "")
     |> assign(:canvas_description, "")}
  end

  @impl true
  def handle_event("update_canvas_title", params, socket) do
    value = params["title"] || params["value"] || ""
    {:noreply, assign(socket, :canvas_title, value)}
  end

  @impl true
  def handle_event("update_canvas_description", params, socket) do
    value = params["content"] || params["value"] || ""
    {:noreply, assign(socket, :canvas_description, value)}
  end

  # ============================================================================
  # Reaction Events
  # ============================================================================

  @impl true
  def handle_event("toggle_reaction", %{"post-id" => post_id, "emoji" => emoji}, socket) do
    user_id = socket.assigns.current_scope.current_user.id
    post_id = String.trim(post_id)

    case WhiteBoard.toggle_reaction(post_id, user_id, emoji) do
      {:ok, added, removed} ->
        added_emoji = added && added.emoji
        removed_emoji = removed && removed.emoji

        WhiteBoard.broadcast_reaction(
          socket.assigns.user.id,
          post_id,
          user_id,
          added_emoji,
          removed_emoji,
          self()
        )

        # Optimistic update
        reactions =
          update_reaction_map(socket.assigns.reactions, post_id, added_emoji, removed_emoji)

        {:noreply, assign(socket, :reactions, reactions)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  # ============================================================================
  # Comment Events
  # ============================================================================

  @impl true
  def handle_event("add_comment", params, socket) do
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
          WhiteBoard.broadcast_comment(socket.assigns.user.id, comment, self())

          comments =
            Map.update(socket.assigns.comments, post_id, [comment], fn existing ->
              existing ++ [comment]
            end)

          {:noreply,
           socket
           |> assign(:comments, comments)
           |> assign(:replying_to, Map.delete(socket.assigns.replying_to, post_id))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Could not add comment."))}
      end
    end
  end

  @impl true
  def handle_event("delete_comment", %{"id" => id}, socket) do
    comment = Repo.get(BoardComment, id)

    if comment && comment.user_id == socket.assigns.current_scope.current_user.id do
      WhiteBoard.delete_comment(comment)

      comments =
        Map.new(socket.assigns.comments, fn {post_id, list} ->
          {post_id, Enum.reject(list, &(&1.id == id))}
        end)

      {:noreply, assign(socket, :comments, comments)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reply_to_comment", %{"post-id" => post_id, "comment-id" => comment_id}, socket) do
    replying_to = Map.put(socket.assigns.replying_to, post_id, comment_id)
    {:noreply, assign(socket, :replying_to, replying_to)}
  end

  @impl true
  def handle_event("cancel_reply", %{"post-id" => post_id}, socket) do
    replying_to = Map.delete(socket.assigns.replying_to, post_id)
    {:noreply, assign(socket, :replying_to, replying_to)}
  end

  # ============================================================================
  # Pagination
  # ============================================================================

  @impl true
  def handle_event("load_more", _params, socket) do
    page = socket.assigns.page + 1
    user = socket.assigns.user
    viewer_id = socket.assigns.current_scope[:current_user] && socket.assigns.current_scope.current_user.id

    new_posts = WhiteBoard.list_posts(user.id, viewer_id, page: page)
    post_count = WhiteBoard.count_posts(user.id, viewer_id)
    all_posts = socket.assigns.posts ++ new_posts
    has_more = length(all_posts) < post_count

    post_ids = Enum.map(new_posts, & &1.id)
    new_reactions = WhiteBoard.list_reactions_for_posts(post_ids, viewer_id)
    new_comments = load_comments_for_posts(new_posts)

    reactions = Map.merge(socket.assigns.reactions, new_reactions)
    comments = Map.merge(socket.assigns.comments, new_comments)

    {:noreply,
     socket
     |> assign(:posts, all_posts)
     |> assign(:page, page)
     |> assign(:has_more, has_more)
     |> assign(:reactions, reactions)
     |> assign(:comments, comments)}
  end

  # ============================================================================
  # PubSub Handlers
  # ============================================================================

  @impl true
  def handle_info({:post_created, post}, socket) do
    if post.user_id == socket.assigns.user.id do
      posts = [post | socket.assigns.posts]
      post_count = socket.assigns.post_count + 1
      {:noreply, assign(socket, posts: posts, post_count: post_count)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_updated, post}, socket) do
    posts =
      Enum.map(socket.assigns.posts, fn p ->
        if p.id == post.id, do: post, else: p
      end)

    {:noreply, assign(socket, :posts, posts)}
  end

  @impl true
  def handle_info({:post_deleted, post_id}, socket) do
    posts = Enum.reject(socket.assigns.posts, &(&1.id == post_id))
    post_count = socket.assigns.post_count - 1
    {:noreply, assign(socket, posts: posts, post_count: max(post_count, 0))}
  end

  @impl true
  def handle_info({:reaction, post_id, user_id_reacting, added_emoji, removed_emoji}, socket) do
    current_user_id = socket.assigns.current_scope[:current_user] && socket.assigns.current_scope.current_user.id
    me? = user_id_reacting == current_user_id

    reactions =
      update_reaction_map_from_broadcast(
        socket.assigns.reactions,
        post_id,
        added_emoji,
        removed_emoji,
        me?
      )

    {:noreply, assign(socket, :reactions, reactions)}
  end

  @impl true
  def handle_info({:comment, comment}, socket) do
    comments =
      Map.update(socket.assigns.comments, comment.post_id, [comment], fn existing ->
        existing ++ [comment]
      end)

    {:noreply, assign(socket, :comments, comments)}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp load_comments_for_posts(posts) do
    post_ids = Enum.map(posts, & &1.id)

    if post_ids == [] do
      %{}
    else
      BoardComment
      |> where([c], c.post_id in ^post_ids)
      |> order_by(asc: :inserted_at)
      |> preload([user: [:profile], parent_comment: [user: [:profile]]])
      |> Repo.all()
      |> Enum.group_by(& &1.post_id)
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

  defp update_reaction_map_from_broadcast(reactions, post_id, added_emoji, removed_emoji, me?) do
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
          # Toggled off same emoji
          current = Map.get(post_reactions, added_emoji, %{count: 0, me?: false})
          new_count = max(current.count - 1, 0)

          if new_count == 0 do
            Map.delete(post_reactions, added_emoji)
          else
            Map.put(post_reactions, added_emoji, %{count: new_count, me?: false})
          end

        added_emoji ->
          # Added or replaced reaction
          current = Map.get(post_reactions, added_emoji, %{count: 0, me?: false})
          new_count = current.count + 1
          Map.put(post_reactions, added_emoji, %{count: new_count, me?: me?})

        true ->
          post_reactions
      end

    Map.put(reactions, post_id, post_reactions)
  end

  defp clean_string(nil), do: nil
  defp clean_string(str) do
    str = String.trim(str)
    if str == "", do: nil, else: str
  end

  defp render_post_content(text, post_id) when is_binary(text) do
    lines = String.split(text, "\n")

    {segments, last_group} =
      Enum.reduce(lines, {[], []}, fn line, {segments, group} ->
        trimmed = String.trim(line)

        cond do
          trimmed == "" ->
            {segments, group ++ [line]}

          match_word_command?(trimmed) or match_kanji_command?(trimmed) ->
            segments = if group != [], do: [{:text, Enum.join(group, "\n")} | segments], else: segments
            segments = [{:command, trimmed} | segments]
            {segments, []}

          true ->
            {segments, group ++ [line]}
        end
      end)

    segments = if last_group != [], do: [{:text, Enum.join(last_group, "\n")} | segments], else: segments

    segments
    |> Enum.reverse()
    |> Enum.map(fn
      {:text, txt} -> render_post_body(txt, post_id)
      {:command, cmd} -> render_command(cmd)
    end)
    |> Enum.join("\n")
  end

  defp render_post_content(nil, _post_id), do: ""

  defp render_post_body(text, post_id) do
    text
    |> render_inline_word_links()
    |> autolink_urls()
    |> render_markdown()
    |> unwrap_photo_only_html()
    |> render_audio_players(post_id)
    |> render_images(post_id)
  end

  defp match_word_command?(text) do
    String.starts_with?(text, "/word ") or
      String.starts_with?(text, "/w ") or
      String.starts_with?(text, "\\word ") or
      String.starts_with?(text, "\\w ")
  end

  defp match_kanji_command?(text) do
    String.starts_with?(text, "/kanji ") or
      String.starts_with?(text, "/k ") or
      String.starts_with?(text, "\\kanji ") or
      String.starts_with?(text, "\\k ")
  end

  defp render_command(text) do
    case parse_word_command(text) do
      {:ok, word_text} ->
        case Content.get_word_by_text_or_meaning_or_conjugation(word_text) do
          nil -> text
          word -> WordChatPreview.render_html(%{word: word}) |> elem(1)
        end

      :error ->
        case parse_kanji_command(text) do
          {:ok, character} ->
            case Content.get_kanji_by_character(character) do
              nil -> text
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

  defp render_inline_word_links(text) do
    pipe_matches = Regex.scan(~r/\|([^|]+)\|/, text, return: :index)
    bracket_matches = Regex.scan(~r/\[\[([^\]]+)\]\]/, text, return: :index)
    corner_matches = Regex.scan(~r/「([^」]+)」/u, text, return: :index)

    matches =
      (pipe_matches ++ bracket_matches ++ corner_matches)
      |> Enum.sort_by(fn [{match_start, _}, _] -> match_start end)

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
            nil -> word_text
            word -> "[#{word_text}](/words/#{word.id})"
          end
      end)
      |> Enum.join("")
    end
  end

  defp build_word_link_segments(text, [], pos, acc) do
    remaining = if pos < byte_size(text), do: binary_part(text, pos, byte_size(text) - pos), else: ""
    acc = if remaining != "", do: [{:text, remaining} | acc], else: acc
    Enum.reverse(acc)
  end

  defp build_word_link_segments(text, [[{match_start, match_len}, {cap_start, cap_len}] | rest], pos, acc) do
    before_len = match_start - pos
    before_text = if before_len > 0, do: binary_part(text, pos, before_len), else: ""
    word_text = binary_part(text, cap_start, cap_len)

    acc = if before_text != "", do: [{:text, before_text} | acc], else: acc
    acc = [{:word, word_text} | acc]

    build_word_link_segments(text, rest, match_start + match_len, acc)
  end

  defp parse_word_command(text) do
    case text do
      "/word " <> rest -> if rest != "", do: {:ok, rest}, else: :error
      "/w " <> rest -> if rest != "", do: {:ok, rest}, else: :error
      "\\word " <> rest -> if rest != "", do: {:ok, rest}, else: :error
      "\\w " <> rest -> if rest != "", do: {:ok, rest}, else: :error
      _ -> :error
    end
  end

  defp parse_kanji_command(text) do
    case text do
      "/kanji " <> rest -> if valid_kanji_command?(rest), do: {:ok, rest}, else: :error
      "/k " <> rest -> if valid_kanji_command?(rest), do: {:ok, rest}, else: :error
      "\\kanji " <> rest -> if valid_kanji_command?(rest), do: {:ok, rest}, else: :error
      "\\k " <> rest -> if valid_kanji_command?(rest), do: {:ok, rest}, else: :error
      _ -> :error
    end
  end

  defp valid_kanji_command?(<<char::utf8>>) when char in 0x4E00..0x9FFF, do: true
  defp valid_kanji_command?(<<char::utf8>>) when char in 0x3400..0x4DBF, do: true
  defp valid_kanji_command?(_), do: false

  defp autolink_urls(text) do
    url_regex = ~r/https?:\/\/[^\s<>"{}|\\^`\[\]]+/

    Regex.split(url_regex, text, include_captures: true)
    |> Enum.map(fn segment ->
      if Regex.match?(url_regex, segment) do
        "<a href=\"#{segment}\" target=\"_blank\" rel=\"noopener noreferrer\" class=\"link link-primary\">#{segment}</a>"
      else
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
    # Find markdown links to audio files and replace with chat-style audio player
    # Supports duration in URL fragment: #duration=42
    regex = ~r/<a href="([^"]+\.(?:webm|ogg|mp3|wav|m4a|oga)[^"]*)"[^>]*>([^<]*)<\/a>/

    Regex.replace(regex, html, fn _full_match, href, _text ->
      audio_id = "board-audio-#{post_id}-#{:erlang.phash2(href)}"

      # Extract duration from fragment
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

  defp photo_only?(nil), do: false

  defp photo_only?(text) do
    trimmed = String.trim(text)
    trimmed != "" and Regex.match?(~r/^\s*!\[[^\]]*\]\([^\)]+\)\s*$/, trimmed)
  end

  defp unwrap_photo_only_html(html) when is_binary(html) do
    # If the entire content is <p><img ... /></p>, unwrap to just the img
    Regex.replace(~r/^<p>\s*(<img[^>]*>)\s*<\/p>$/i, html, "\\1")
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

  defp command_only?(nil), do: false

  defp command_only?(text) do
    trimmed = String.trim(text)
    match_word_command?(trimmed) or match_kanji_command?(trimmed)
  end

  defp emoji_only?(nil), do: false

  defp emoji_only?(text) do
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
