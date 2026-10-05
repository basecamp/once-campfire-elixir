defmodule Campfire.MixProject do
  use Mix.Project

  def project do
    [
      app: :campfire,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      test_ignore_filters: [~r/test\/support\//],
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_cwd: "native",
      deps: [
        {:bandit, "~> 1.8"},
        {:plug, "~> 1.18"},
        {:jason, "~> 1.4"},
        {:exqlite, "~> 0.33"},
        {:bcrypt_elixir, "~> 3.3"},
        {:floki, "~> 0.38"},
        {:redix, "~> 1.5"},
        {:qqr, "0.2.0"},
        {:elixir_make, "~> 0.9", runtime: false},
        {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
        {:dialyxir, "~> 1.4", only: :dev, runtime: false}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto, :inets, :ssl], mod: {Campfire.Application, []}]
  end
end
