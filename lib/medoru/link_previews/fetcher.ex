defmodule Medoru.LinkPreviews.Fetcher do
  @moduledoc """
  Fetches and parses Open Graph metadata from external URLs.
  """

  alias Medoru.LinkPreviews.LinkPreview

  @max_body_size 2_000_000
  @request_timeout 5_000
  @max_redirects 3
  @user_agent "MedoruBot/1.0 (+https://medoru.net/bot)"

  @doc """
  Fetches a URL and returns a map of preview attributes.
  """
  def fetch(url) when is_binary(url) do
    with :ok <- validate_url(url),
         {:ok, body, final_url} <- fetch_body(url) do
      {:ok, parse(body, final_url)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Normalizes a URL for deduplication.
  """
  def normalize_url(url) when is_binary(url) do
    url
    |> String.trim()
    |> strip_trailing_punctuation()
    |> case do
      "" ->
        ""

      trimmed ->
        case URI.parse(trimmed) do
          %URI{scheme: scheme, host: host} = uri
          when scheme in ["http", "https"] and is_binary(host) ->
            host = String.downcase(host)
            port = standard_port(uri)

            %URI{uri | host: host, port: port, fragment: nil}
            |> URI.to_string()

          _ ->
            trimmed
        end
    end
  end

  @doc """
  Decodes percent-encoded UTF-8 octets so a URL can be shown to users with
  Japanese (or other non-ASCII) characters intact. ASCII percent-encodings such
  as `%20` or `%2F` are left alone.
  """
  def display_url(url) when is_binary(url) do
    Regex.replace(~r/%([0-9A-Fa-f]{2})/, url, fn full, hex ->
      byte = String.to_integer(hex, 16)

      if byte >= 0x80 do
        <<byte>>
      else
        full
      end
    end)
  end

  defp strip_trailing_punctuation(url) do
    url
    |> String.trim_trailing(".")
    |> String.trim_trailing(",")
    |> String.trim_trailing("!")
    |> String.trim_trailing("?")
    |> String.trim_trailing(")")
    |> String.trim_trailing("]")
    |> String.trim_trailing("}")
    |> String.trim_trailing("'")
    |> String.trim_trailing("\"")
  end

  defp standard_port(%URI{scheme: "http", port: 80}), do: nil
  defp standard_port(%URI{scheme: "https", port: 443}), do: nil
  defp standard_port(%URI{port: port}), do: port

  @doc """
  Validates that a URL is safe to fetch.
  """
  def validate_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        host = String.downcase(host)

        cond do
          host in ["localhost", "127.0.0.1", "::1", "0.0.0.0"] ->
            {:error, :private_url}

          String.ends_with?(host, ".local") or String.ends_with?(host, ".internal") ->
            {:error, :private_url}

          private_ip?(host) ->
            {:error, :private_url}

          true ->
            :ok
        end

      _ ->
        {:error, :invalid_url}
    end
  end

  defp private_ip?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, addr} ->
        case addr do
          {10, _, _, _} -> true
          {172, n, _, _} when n >= 16 and n <= 31 -> true
          {192, 168, _, _} -> true
          {127, _, _, _} -> true
          {169, 254, _, _} -> true
          {0, _, _, _} -> true
          {_, _, _, _, _, _, _, _} -> false
          _ -> false
        end

      _ ->
        false
    end
  end

  defp fetch_body(url) do
    req =
      Req.new(
        url: url,
        connect_options: [timeout: @request_timeout],
        receive_timeout: @request_timeout,
        max_redirects: @max_redirects,
        headers: [
          {"user-agent", @user_agent},
          {"accept", "text/html,application/xhtml+xml"}
        ]
      )

    case Req.get(req) do
      {:ok, %{status: status, headers: headers, body: body}} when status in 200..299 ->
        if html_content?(headers) do
          {:ok, truncate_body(body), url}
        else
          {:error, :non_html_content}
        end

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp html_content?(headers) when is_list(headers) do
    headers
    |> Enum.find(fn {key, _} -> String.downcase(key) == "content-type" end)
    |> case do
      nil ->
        true

      {_, values} ->
        values
        |> List.wrap()
        |> Enum.any?(fn value ->
          value
          |> String.downcase()
          |> String.starts_with?("text/html")
        end)
    end
  end

  defp html_content?(_), do: true

  defp truncate_body(body) when is_binary(body) and byte_size(body) > @max_body_size do
    binary_part(body, 0, @max_body_size)
  end

  defp truncate_body(body) when is_binary(body), do: body
  defp truncate_body(_), do: ""

  @doc """
  Parses HTML body and extracts Open Graph / fallback metadata.
  """
  def parse(body, final_url) when is_binary(body) do
    uri = URI.parse(final_url)

    title =
      og_tag(body, "og:title") ||
        first_tag_text(body, "title") ||
        ""

    description =
      og_tag(body, "og:description") ||
        meta_tag(body, "description") ||
        ""

    image_url = absolutize_url(og_tag(body, "og:image"), uri)
    site_name = og_tag(body, "og:site_name") || uri.host || ""
    favicon_url = absolutize_url(favicon(body), uri)

    %{
      title: truncate(title, 300),
      description: truncate(description, 500),
      image_url: image_url,
      site_name: site_name,
      favicon_url: favicon_url,
      status: "fetched"
    }
  end

  defp og_tag(body, property) do
    body
    |> Floki.parse_document!()
    |> Floki.find("meta[property='#{property}'], meta[property=\"#{property}\"]")
    |> maybe_meta_content()
  end

  defp meta_tag(body, name) do
    body
    |> Floki.parse_document!()
    |> Floki.find("meta[name='#{name}'], meta[name=\"#{name}\"]")
    |> maybe_meta_content()
  end

  defp first_tag_text(body, tag) do
    body
    |> Floki.parse_document!()
    |> Floki.find(tag)
    |> List.first()
    |> case do
      nil -> nil
      element -> element |> Floki.text() |> String.trim()
    end
  end

  defp favicon(body) do
    body
    |> Floki.parse_document!()
    |> Floki.find(
      "link[rel='icon'], link[rel=\"icon\"], link[rel='shortcut icon'], link[rel=\"shortcut icon\"]"
    )
    |> Enum.find_value(fn element ->
      Floki.attribute(element, "href") |> List.first()
    end)
  end

  defp maybe_meta_content(elements) do
    elements
    |> Enum.find_value(fn element ->
      Floki.attribute(element, "content") |> List.first()
    end)
    |> case do
      nil -> nil
      content -> String.trim(content)
    end
  end

  defp absolutize_url(nil, _uri), do: nil
  defp absolutize_url("" <> _ = url, uri), do: URI.merge(uri, url) |> URI.to_string()
  defp absolutize_url(_, _uri), do: nil

  defp truncate(nil, _len), do: nil
  defp truncate(text, len) when byte_size(text) <= len, do: text

  defp truncate(text, len) do
    String.slice(text, 0, len) <> "…"
  end

  @doc """
  Returns true if a preview is usable for rendering.
  """
  def usable?(%LinkPreview{status: status}) do
    status == "fetched"
  end

  def usable?(_), do: false
end
