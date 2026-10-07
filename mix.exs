defmodule Campfire.MixProject do
  use Mix.Project

  def project do
    [
      app: :campfire,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      test_ignore_filters: [~r/test\/support\//],
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_cwd: "native",
      deps: [
        {:bandit,
         github: "zachdaniel/bandit", branch: "batched-websocket-writes", override: true},
        {:plug, "~> 1.18"},
        {:jason, "~> 1.4"},
        {:exqlite, "~> 0.33"},
        {:bcrypt_elixir, "~> 3.3"},
        {:floki, "~> 0.38"},
        {:qqr, "0.2.0"},
        {:site_encrypt, "~> 0.7"},
        {:elixir_make, "~> 0.9", runtime: false},
        {:nimble_pool, "~> 1.1"}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto, :inets, :ssl], mod: {Campfire.Application, []}]
  end
end
