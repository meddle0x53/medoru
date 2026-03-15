defmodule MedoruWeb.Plugs.SetLocale do
  @moduledoc """
  Plug to set the locale for the current request.

  Priority of locale detection:
  1. URL parameter (?locale=bg)
  2. Cookie (medoru_locale)
  3. Browser Accept-Language header
  4. Default locale (en)

  Note: User preference storage is planned for future implementation.
  """

  import Plug.Conn

  @default_locale "en"
  @supported_locales ["en", "bg", "ja"]
  @cookie_name "medoru_locale"
  # 1 year
  @cookie_max_age 365 * 24 * 60 * 60

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = detect_locale(conn)

    # Set Gettext locale
    Gettext.put_locale(MedoruWeb.Gettext, locale)

    # Store locale in conn assigns for access in controllers/templates
    conn = assign(conn, :locale, locale)

    # Store locale in session for LiveViews
    conn = put_session(conn, :locale, locale)

    # Set/refresh cookie
    put_resp_cookie(conn, @cookie_name, locale,
      max_age: @cookie_max_age,
      http_only: true,
      same_site: "Lax"
    )
  end

  defp detect_locale(conn) do
    # Priority 1: URL parameter
    case conn.params["locale"] do
      locale when locale in @supported_locales ->
        locale

      _ ->
        # Priority 2: User preference
        case get_user_locale(conn) do
          nil ->
            # Priority 3: Cookie
            case conn.cookies[@cookie_name] do
              locale when locale in @supported_locales ->
                locale

              _ ->
                # Priority 4: Accept-Language header
                accept_language_locale(conn) || @default_locale
            end

          locale ->
            locale
        end
    end
  end

  defp get_user_locale(conn) do
    # User settings field not yet implemented - always return nil
    # Future: check user profile or settings table for locale preference
    _ = conn
    nil
  end

  defp accept_language_locale(conn) do
    case get_req_header(conn, "accept-language") do
      [header | _] ->
        header
        |> parse_accept_language()
        |> Enum.find(&(&1 in @supported_locales))

      _ ->
        nil
    end
  end

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(fn lang ->
      case String.split(lang, ";") do
        [code | _] -> String.trim(code) |> String.downcase() |> extract_primary_tag()
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_primary_tag(tag) do
    case String.split(tag, "-") do
      [primary | _] -> primary
      _ -> tag
    end
  end

  @doc """
  Gets the current locale from the connection.
  """
  def get_locale(conn), do: conn.assigns[:locale] || @default_locale

  @doc """
  Checks if a locale is supported.
  """
  def supported_locale?(locale), do: locale in @supported_locales

  @doc """
  Returns the list of supported locales.
  """
  def supported_locales, do: @supported_locales

  @doc """
  Returns the default locale.
  """
  def default_locale, do: @default_locale
end
