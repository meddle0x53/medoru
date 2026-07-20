defmodule MedoruWeb.ChatMediaFolderComponent do
  @moduledoc """
  Shared function component for the chat media folder overlay.
  Used by both direct/group chats (MessagesLive.Show) and classroom chats
  (ClassroomLive.Show).
  """

  use Phoenix.Component
  use Gettext, backend: MedoruWeb.Gettext

  import MedoruWeb.CoreComponents, only: [icon: 1]

  attr :open, :boolean, required: true
  attr :filter, :string, required: true
  attr :items, :list, required: true
  attr :has_more, :boolean, required: true
  attr :loading, :boolean, default: false
  attr :current_user_id, :string, required: true
  attr :sender_name_fn, :any, required: true
  attr :time_formatter_fn, :any, required: true

  def chat_media_folder(assigns) do
    ~H"""
    <%= if @open do %>
      <div class="absolute inset-0 z-30 bg-base-100 flex flex-col">
        <%!-- Media Folder Header --%>
        <div class="flex items-center gap-3 px-4 py-3 border-b border-base-300 bg-base-100 shrink-0">
          <button
            type="button"
            phx-click="close_media_folder"
            class="text-secondary hover:text-primary transition-colors"
            title={gettext("Back to chat")}
          >
            <.icon name="hero-arrow-left" class="w-5 h-5" />
          </button>
          <h2 class="font-medium text-base-content flex-1 min-w-0 truncate">
            {gettext("Media")}
          </h2>
        </div>

        <%!-- Filter Tabs --%>
        <div class="shrink-0 px-4 py-2 border-b border-base-300 overflow-x-auto">
          <div class="flex items-center gap-2 min-w-max">
            <%= for {filter, label} <- [
              {"all", gettext("All")},
              {"image", gettext("Images")},
              {"video", gettext("Video")},
              {"audio", gettext("Audio")},
              {"voice", gettext("Voice")},
              {"document", gettext("Files")}
            ] do %>
              <button
                type="button"
                phx-click="set_media_filter"
                phx-value-type={filter}
                class={[
                  "px-3 py-1.5 rounded-full text-sm font-medium transition-colors whitespace-nowrap",
                  @filter == filter && "bg-primary text-primary-content",
                  @filter != filter && "bg-base-200 text-base-content hover:bg-base-300"
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Media Grid --%>
        <div
          id="chat-media-folder-grid"
          class="flex-1 overflow-y-auto p-4"
          phx-viewport-bottom={if @has_more && !@loading, do: "load_more_media"}
        >
          <%= if @items == [] do %>
            <div class="h-full flex flex-col items-center justify-center text-secondary">
              <.icon name="hero-folder-open" class="w-16 h-16 mb-4 opacity-40" />
              <p class="text-lg font-medium">{gettext("No media found")}</p>
            </div>
          <% else %>
            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
              <%= for message <- @items do %>
                <% sender_name = @sender_name_fn.(message, @current_user_id) %>
                <% sent_at = @time_formatter_fn.(message.inserted_at) %>

                <%= cond do %>
                  <% message.attachment_type == "image" -> %>
                    <div class="group relative aspect-square bg-base-200 rounded-xl overflow-hidden border border-base-300">
                      <a href={message.attachment_path} target="_blank" class="block w-full h-full">
                        <img
                          src={message.attachment_path}
                          alt={gettext("Image")}
                          class="w-full h-full object-cover"
                          loading="lazy"
                        />
                      </a>
                      <a
                        href={message.attachment_path}
                        download
                        class="absolute bottom-2 right-2 p-1.5 rounded-lg bg-black/60 text-white opacity-0 group-hover:opacity-100 transition-opacity"
                        title={gettext("Download")}
                      >
                        <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
                      </a>
                      <div class="absolute bottom-0 left-0 right-0 p-2 bg-gradient-to-t from-black/70 to-transparent opacity-0 group-hover:opacity-100 transition-opacity">
                        <p class="text-xs text-white truncate">{sender_name} · {sent_at}</p>
                      </div>
                    </div>
                  <% message.attachment_type in ["voice", "audio"] -> %>
                    <div class="flex flex-col gap-2 p-3 bg-base-200 rounded-xl border border-base-300">
                      <div class="flex items-center gap-2 text-secondary">
                        <.icon
                          name={
                            if(message.attachment_type == "voice",
                              do: "hero-microphone",
                              else: "hero-speaker-wave"
                            )
                          }
                          class="w-5 h-5"
                        />
                        <span class="text-sm font-medium">
                          {if(message.attachment_type == "voice",
                            do: gettext("Voice message"),
                            else: gettext("Audio")
                          )}
                        </span>
                      </div>
                      <div
                        id={"chat-audio-media-#{message.id}"}
                        class="flex items-center gap-2"
                        phx-hook="ChatAudioPlayer"
                        data-src={message.attachment_path}
                        data-duration={message.duration_seconds || 0}
                      >
                        <button
                          type="button"
                          class="chat-audio-play w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center hover:bg-primary/30 transition-colors shrink-0"
                        >
                          <.icon name="hero-play" class="w-4 h-4 chat-audio-play-icon" />
                          <.icon name="hero-pause" class="w-4 h-4 chat-audio-pause-icon hidden" />
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
                            <span class="chat-audio-current text-[10px] opacity-70 tabular-nums">
                              0:00
                            </span>
                            <span class="chat-audio-duration text-[10px] opacity-70 tabular-nums">
                              {format_audio_duration(message.duration_seconds)}
                            </span>
                          </div>
                        </div>
                        <audio
                          class="chat-audio-el absolute w-0 h-0 opacity-0"
                          src={message.attachment_path}
                          preload="auto"
                        >
                        </audio>
                      </div>
                      <p class="text-xs text-secondary truncate">{sender_name} · {sent_at}</p>
                    </div>
                  <% message.attachment_type == "video" -> %>
                    <div class="group relative aspect-video bg-base-200 rounded-xl overflow-hidden border border-base-300 sm:col-span-2 md:col-span-2">
                      <video controls class="w-full h-full object-cover" preload="metadata">
                        <source
                          src={message.attachment_path}
                          type={video_mime_type(message.attachment_path)}
                        />
                      </video>
                      <a
                        href={message.attachment_path}
                        download
                        class="absolute bottom-2 right-2 p-1.5 rounded-lg bg-black/60 text-white opacity-0 group-hover:opacity-100 transition-opacity"
                        title={gettext("Download")}
                      >
                        <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
                      </a>
                      <div class="absolute bottom-0 left-0 right-0 p-2 bg-gradient-to-t from-black/70 to-transparent opacity-0 group-hover:opacity-100 transition-opacity">
                        <p class="text-xs text-white truncate">{sender_name} · {sent_at}</p>
                      </div>
                    </div>
                  <% true -> %>
                    <% file_size = attachment_file_size(message.attachment_path) %>
                    <a
                      href={message.attachment_path}
                      download
                      class="flex flex-col gap-2 p-3 bg-base-200 hover:bg-base-300 rounded-xl border border-base-300 transition-colors"
                    >
                      <div class="flex items-center gap-2 text-secondary">
                        <.icon name="hero-document" class="w-8 h-8" />
                        <span class="text-sm font-medium truncate flex-1">
                          {attachment_filename(message.attachment_path)}
                        </span>
                      </div>
                      <%= if file_size do %>
                        <p class="text-xs text-secondary">{format_file_size(file_size)}</p>
                      <% end %>
                      <p class="text-xs text-secondary truncate">{sender_name} · {sent_at}</p>
                    </a>
                <% end %>
              <% end %>
            </div>

            <%= if @has_more do %>
              <div id="chat-media-folder-load-more" class="flex justify-center py-6">
                <button
                  type="button"
                  phx-click="load_more_media"
                  disabled={@loading}
                  class={[
                    "btn btn-sm",
                    @loading && "btn-ghost opacity-60 cursor-not-allowed",
                    !@loading && "btn-outline btn-primary"
                  ]}
                >
                  <%= if @loading do %>
                    <span class="loading loading-spinner loading-sm mr-1"></span>
                    {gettext("Loading...")}
                  <% else %>
                    <.icon name="hero-arrow-down" class="w-4 h-4 mr-1" />
                    {gettext("Load more media")}
                  <% end %>
                </button>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Formats a file size in bytes to a human-readable string.
  """
  def format_file_size(nil), do: nil

  def format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"

  def format_file_size(bytes) when bytes < 1_048_576 do
    "#{Float.round(bytes / 1024, 1)} KB"
  end

  def format_file_size(bytes) when bytes < 1_073_741_824 do
    "#{Float.round(bytes / 1_048_576, 1)} MB"
  end

  def format_file_size(bytes) do
    "#{Float.round(bytes / 1_073_741_824, 1)} GB"
  end

  @doc """
  Extracts a display filename from an attachment path.
  """
  def attachment_filename(path) do
    path
    |> Path.basename()
    |> URI.decode()
  end

  @doc """
  Returns the file size of an uploaded attachment if the file exists on disk.
  """
  def attachment_file_size(path) do
    uploads_dir = Application.get_env(:medoru, :uploads_dir)
    full_path = Path.join(uploads_dir, String.trim_leading(path, "/uploads/"))

    case File.stat(full_path) do
      {:ok, %{size: size}} -> size
      _ -> nil
    end
  end

  @doc """
  Formats audio duration as M:SS.
  """
  def format_audio_duration(nil), do: "0:00"

  def format_audio_duration(seconds) when seconds < 60,
    do: "0:#{String.pad_leading("#{seconds}", 2, "0")}"

  def format_audio_duration(seconds) do
    m = div(seconds, 60)
    s = rem(seconds, 60)
    "#{m}:#{String.pad_leading("#{s}", 2, "0")}"
  end

  @doc """
  Returns a MIME type for a video file based on its extension.
  """
  def video_mime_type(path) do
    case Path.extname(path) |> String.downcase() do
      ".mp4" -> "video/mp4"
      ".mov" -> "video/quicktime"
      ".webm" -> "video/webm"
      ".ogv" -> "video/ogg"
      _ -> "video/mp4"
    end
  end
end
