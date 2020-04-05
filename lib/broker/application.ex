defmodule Broker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Broker.Worker.start_link(arg)
      # {Broker.Worker, arg}
      Broker.Portfolio.Database,
      Broker.Portfolio.OrderProcessor,
      Broker.Bot,
      Broker.Report.Scheduler
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Broker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
