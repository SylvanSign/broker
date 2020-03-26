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
      {:nostrum, "~> 0.4"},
      {:poison, "~> 3.0"},
      {:number, "~> 1.0"},
      {:table_rex, "~> 2.0.0"},
      {:quantum, "~> 3.0-rc"},
      {:tzdata, "~> 1.0.3"},
      {:remix, "~> 0.0.1", only: :dev}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
