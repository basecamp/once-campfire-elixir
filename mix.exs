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
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:ex_unit],
        plt_core_path: Path.join(Mix.Project.build_path(), "dialyxir"),
        plt_local_path: Path.join(Mix.Project.build_path(), "dialyxir")
      ],
      aliases: aliases()
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto, :inets, :ssl], mod: {Campfire.Application, []}]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.8"},
      {:plug, "~> 1.18"},
      {:jason, "~> 1.4"},
      {:exqlite, "~> 0.33"},
      {:bcrypt_elixir, "~> 3.3"},
      {:floki, "~> 0.38"},
      {:gumbo,
       git: "https://github.com/gilbertwong96/gumbo.git",
       branch: "nokogiri-compat",
       submodules: true},
      {:redix, "~> 1.5"},
      {:qqr, "0.2.0"},
      {:vix, "~> 0.42"},
      {:torque, "~> 0.5"},
      {:elixir_make, "~> 0.9", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.5", only: [:dev, :test], runtime: false},
      {:vibe_kit, "~> 0.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases() do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer",
        # The row and route modules are generated from vectors/schema.json, so duplicated shape
        # between generated structs is not something to refactor by hand.
        "ex_dna --max-clones 0 --ignore lib/campfire/generated/**",
        "reach.check --arch --smells"
      ]
    ]
  end
end
