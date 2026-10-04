defmodule @@MODULE@@.MixProject do
  use Mix.Project
  def project, do: [app: :@@NAME@@, version: "0.1.0", elixir: "~> @@ELIXIR@@", deps: [{:bandit, "~> 1.8"}, {:plug, "~> 1.18"}]]
  def application, do: [extra_applications: [:logger], mod: {@@MODULE@@.Application, []}]
end
