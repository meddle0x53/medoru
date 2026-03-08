defmodule Medoru.Logger do
  @moduledoc """
  Structured logging interface for Medoru.

  Provides a consistent API for logging throughout the application
  with support for structured metadata.

  ## Examples

      # Simple logging
      Medoru.Logger.info("User logged in", %{user_id: user.id})

      # With context
      Medoru.Logger.with_context(%{request_id: request_id}, fn ->
        Medoru.Logger.info("Processing payment")
        # ... code ...
        Medoru.Logger.info("Payment completed", %{amount: 100})
      end)

  """

  require Logger

  @typedoc "Log metadata as a map or keyword list"
  @type metadata :: map() | keyword()

  @doc """
  Logs a debug message with optional metadata.
  """
  @spec debug(String.t(), metadata()) :: :ok
  def debug(message, metadata \\ %{}) do
    Logger.debug(message, metadata: normalize_metadata(metadata))
  end

  @doc """
  Logs an info message with optional metadata.
  """
  @spec info(String.t(), metadata()) :: :ok
  def info(message, metadata \\ %{}) do
    Logger.info(message, metadata: normalize_metadata(metadata))
  end

  @doc """
  Logs a warning message with optional metadata.
  """
  @spec warning(String.t(), metadata()) :: :ok
  def warning(message, metadata \\ %{}) do
    Logger.warning(message, metadata: normalize_metadata(metadata))
  end

  @doc """
  Logs an error message with optional metadata.
  """
  @spec error(String.t(), metadata()) :: :ok
  def error(message, metadata \\ %{}) do
    Logger.error(message, metadata: normalize_metadata(metadata))
  end

  @doc """
  Logs an error with exception details.

  ## Examples

      try do
        risky_operation()
      rescue
        e ->
          Medoru.Logger.exception(e, __STACKTRACE__, "Operation failed", %{user_id: user.id})
      end

  """
  @spec exception(Exception.t(), Exception.stacktrace(), String.t(), metadata()) :: :ok
  def exception(exception, stacktrace, message \\ nil, metadata \\ %{}) do
    full_message =
      if message do
        "#{message}: #{Exception.message(exception)}"
      else
        Exception.message(exception)
      end

    error(
      full_message,
      Map.merge(metadata, %{
        error_type: exception.__struct__,
        stacktrace: Exception.format_stacktrace(stacktrace)
      })
    )
  end

  @doc """
  Executes a function with the given context metadata.

  The context is automatically cleared after the function executes.

  ## Examples

      Medoru.Logger.with_context(%{request_id: "abc123", user_id: 42}, fn ->
        Medoru.Logger.info("Starting process")
        # All logs inside here will include request_id and user_id
        process_data()
        Medoru.Logger.info("Process complete")
      end)
      # Context is cleared here

  """
  @spec with_context(metadata(), (-> result)) :: result when result: any()
  def with_context(context, fun) when is_function(fun, 0) do
    original_metadata = Logger.metadata()

    try do
      Logger.metadata(normalize_metadata(context))
      fun.()
    after
      Logger.metadata(original_metadata)
    end
  end

  @doc """
  Logs a message at the specified level.
  """
  @spec log(:debug | :info | :warning | :error, String.t(), metadata()) :: :ok
  def log(level, message, metadata \\ %{}) do
    case level do
      :debug -> debug(message, metadata)
      :info -> info(message, metadata)
      :warning -> warning(message, metadata)
      :error -> error(message, metadata)
    end
  end

  @doc """
  Adds metadata to the current process without executing a function.

  ## Examples

      Medoru.Logger.put_context(%{user_id: user.id})
      # Later in the same process...
      Medoru.Logger.info("Action taken") # includes user_id

  """
  @spec put_context(metadata()) :: :ok
  def put_context(context) do
    Logger.metadata(normalize_metadata(context))
  end

  @doc """
  Creates audit log entry for security-sensitive operations.

  ## Examples

      Medoru.Logger.audit("user.login", %{user_id: user.id, ip: conn.remote_ip})
      Medoru.Logger.audit("admin.user_promoted", %{admin_id: admin.id, target_id: user.id})

  """
  @spec audit(String.t(), metadata()) :: :ok
  def audit(action, metadata \\ %{}) do
    info("[AUDIT] #{action}", Map.merge(metadata, %{audit: true, action: action}))
  end

  # Private functions

  defp normalize_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.map(fn {k, v} -> {k, normalize_value(v)} end)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  defp normalize_metadata(metadata) when is_list(metadata) do
    metadata
    |> Enum.map(fn {k, v} -> {k, normalize_value(v)} end)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  # Convert tuple IPs to strings
  defp normalize_value({a, b, c, d})
       when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) do
    "#{a}.#{b}.#{c}.#{d}"
  end

  defp normalize_value({a, b, c, d, e, f, g, h})
       when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) and is_integer(e) and
              is_integer(f) and is_integer(g) and is_integer(h) do
    "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
  end

  # Keep other values as-is
  defp normalize_value(value), do: value
end
