defmodule Recommendations.MixProject do
  use Mix.Project

  def project do
    [
      app: :recommendations,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Recommendations.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"},
      {:redix, "~> 1.3"},
      {:postgrex, "~> 0.17"},
      {:ecto_sql, "~> 3.11"},
      {:ecto, "~> 3.11"}
    ]
  end
end
