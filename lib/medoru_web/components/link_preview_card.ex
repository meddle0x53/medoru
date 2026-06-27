defmodule MedoruWeb.LinkPreviewCard do
  @moduledoc """
  Renders a compact preview card for an external link.
  """
  use Phoenix.Component

  attr :preview, :map, required: true
  attr :class, :string, default: nil

  def link_preview_card(assigns) do
    ~H"""
    <a
      href={@preview.url}
      target="_blank"
      rel="noopener noreferrer"
      class={[
        "block max-w-[320px] border border-base-300 rounded-xl overflow-hidden shadow-sm bg-base-100 hover:shadow-md hover:border-primary/30 transition-all",
        @class
      ]}
    >
      <%= if @preview.image_url do %>
        <img
          src={@preview.image_url}
          alt=""
          class="w-full h-auto max-h-80 object-contain"
          loading="lazy"
          referrerpolicy="no-referrer"
        />
      <% end %>
      <div class="p-3">
        <div class="flex items-center gap-2 mb-1 min-w-0">
          <%= if @preview.favicon_url do %>
            <img
              src={@preview.favicon_url}
              alt=""
              class="w-4 h-4 shrink-0"
              referrerpolicy="no-referrer"
            />
          <% end %>
          <span class="text-xs text-base-content/60 truncate">
            {@preview.site_name || hostname(@preview.url)}
          </span>
        </div>
        <%= if @preview.title do %>
          <h4 class="font-semibold text-sm text-base-content line-clamp-2">
            {@preview.title}
          </h4>
        <% end %>
        <%= if @preview.description do %>
          <p class="text-xs text-secondary mt-1 line-clamp-2">
            {@preview.description}
          </p>
        <% end %>
      </div>
    </a>
    """
  end

  defp hostname(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> url
    end
  end
end
