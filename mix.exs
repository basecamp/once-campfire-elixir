defmodule Campfire.MixProject do
  use Mix.Project

  def project do
    [
      app: :campfire,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      test_ignore_filters: [~r/test\/support\//],
      deps: [
        {:bandit, "~> 1.8"},
        {:plug, "~> 1.18"},
        {:jason, "~> 1.4"},
        {:exqlite, "~> 0.33"},
        {:db_connection, "~> 2.10"},
        {:bcrypt_elixir, "~> 3.3"},
        {:floki, "~> 0.38"},
        {:redix, "~> 1.5"},
        {:qqr, "0.2.0"}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto, :inets, :ssl], mod: {Campfire.Application, []}]
  end
end
