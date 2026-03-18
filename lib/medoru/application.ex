defmodule Medoru.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Configure additional logging backends for production
    configure_logging()

    children = [
      MedoruWeb.Telemetry,
      Medoru.Repo,
      {DNSCluster, query: Application.get_env(:medoru, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Medoru.PubSub},
      # Start a worker by calling: Medoru.Worker.start_link(arg)
      # {Medoru.Worker, _arg},
      # Start to serve requests, typically the last entry
      MedoruWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Medoru.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Configure logging backends based on environment
  defp configure_logging do
    env = Application.get_env(:medoru, :env, :prod)

    if env == :prod do
      # Add file backend in production
      LoggerBackends.add({LoggerFileBackend, :file_log})

      # Configure the file backend
      Application.put_env(:logger, :file_log,
        path: "/var/log/medoru/app.log",
        level: :info,
        format: {LoggerJSON.Formatters.Basic, :format},
        metadata: :all,
        rotate: %{max_bytes: 10_000_000, keep: 5}
      )
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MedoruWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
