defmodule AwsAsh.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AwsAshWeb.Telemetry,
      AwsAsh.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:aws_ash, :ecto_repos),
       skip: skip_migrations?(),
       log_migrator_sql: true},
      {DNSCluster, query: Application.get_env(:aws_ash, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AwsAsh.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: AwsAsh.Finch},
      # Start a worker by calling: AwsAsh.Worker.start_link(arg)
      # {AwsAsh.Worker, arg},
      # Start to serve requests, typically the last entry
      AwsAshWeb.Endpoint,
      AwsAsh.SdkMetrics.Server
    ]

    children =
      if Application.get_env(:aws_ash, :env) == :prod do
        children ++
          [
            {Desktop.Window,
             [
               app: :aws_ash,
               id: AwsAshWindow,
               url: &AwsAshWeb.Endpoint.url/0
             ]}
          ]
      else
        children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AwsAsh.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AwsAshWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    Application.get_env(:aws_ash, :env) != :prod
  end
end
