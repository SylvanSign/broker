defmodule Broker.MixProject do
  use Mix.Project

  def project do
    [
      app: :broker,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Broker.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # discord library
      {:nostrum, "~> 0.4"},
      # http client
      {:poison, "~> 3.0"},
      # number to currency pretty printing
      {:number, "~> 1.0"},
      # print nice tables
      {:table_rex, "~> 3.0.0"},
      # schedule jobs to run at a certain time
      {:quantum, "~> 3.0-rc"},
      # timezone data for quantum (above)
      {:tzdata, "~> 1.0.3"},
      # generic state machine, used for trades/orders
      {:gen_state_machine, "~> 2.1.0"},
      # automatically "live-reload" the dev code locally
      {:remix, "~> 0.0.1", only: :dev}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
