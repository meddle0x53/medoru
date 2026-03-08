defmodule MedoruWeb.Plugs.RequestLogger do
  @moduledoc """
  Logs HTTP requests with metadata for debugging and audit purposes.

  This plug should be added to your router pipeline:

      pipeline :browser do
        plug :accepts, ["html"]
        plug MedoruWeb.Plugs.RequestLogger
        # ... other plugs
      end

  """

  alias Medoru.Logger, as: AppLogger

  require Logger

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    start_time = System.monotonic_time()

    # Extract and set metadata for this request
    request_id = generate_request_id()
    user_id = get_user_id(conn)
    ip = format_ip(conn.remote_ip)

    Logger.metadata(
      request_id: request_id,
      user_id: user_id,
      ip: ip,
      method: conn.method,
      path: conn.request_path
    )

    # Register callback to log when response is sent
    Plug.Conn.register_before_send(conn, fn conn ->
      duration_ms =
        System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

      log_level = get_log_level(conn.status)

      AppLogger.log(log_level, "Request #{conn.method} #{conn.request_path}", %{
        request_id: request_id,
        status: conn.status,
        duration_ms: duration_ms,
        user_id: user_id,
        ip: ip,
        method: conn.method,
        path: conn.request_path,
        query_string: conn.query_string,
        user_agent: get_user_agent(conn)
      })

      conn
    end)
  end

  # Generate a unique request ID
  defp generate_request_id do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  # Extract user ID from the connection if authenticated
  defp get_user_id(conn) do
    case conn.assigns[:current_scope] do
      %{current_user: %{id: id}} -> id
      _ -> nil
    end
  end

  # Format IP address as string
  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip({a, b, c, d, e, f, g, h}), do: "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
  defp format_ip(ip) when is_binary(ip), do: ip
  defp format_ip(_), do: "unknown"

  # Get user agent header
  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      _ -> nil
    end
  end

  # Determine log level based on response status
  defp get_log_level(status) when is_integer(status) do
    cond do
      status >= 500 -> :error
      status >= 400 -> :warning
      true -> :info
    end
  end

  defp get_log_level(_), do: :info
end
