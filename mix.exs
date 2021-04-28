defmodule ExBanking.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_banking,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ExBanking.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:dialyxir, "~> 1.0", only: [:dev], runtime: false}]
  end
end
