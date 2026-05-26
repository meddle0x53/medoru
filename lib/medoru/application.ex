defmodule Medoru.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    check_vapid_config()

    children = [
      MedoruWeb.Telemetry,
      Medoru.Repo,
      {DNSCluster, query: Application.get_env(:medoru, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Medoru.PubSub},
      # Presence tracking for online users and chat
      MedoruWeb.Presence,
      # Grammar validator cache for fast lookups
      Medoru.Grammar.ValidatorCache,
      # Start to serve requests, typically the last entry
      MedoruWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Medoru.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MedoruWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp check_vapid_config do
    case Application.get_env(:medoru, :vapid_details) do
      nil ->
        Logger.warning("VAPID config is missing. Push notifications will not work.")

      %{public_key: key} when key in [nil, ""] ->
        Logger.warning("VAPID public key is empty. Push notifications will not work.")

      _ ->
        :ok
    end
  end
end
