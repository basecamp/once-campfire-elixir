defmodule Campfire.Env do
  @moduledoc """
  Runtime environment for the application.

  `config/runtime.exs` reads the process environment once and stores it here; modules ask this
  module instead of calling `System.get_env/1`, so no code path depends on the OS environment and a
  value can be overridden in a test with `put/2`.
  """

  @key :env

  def all, do: Application.get_env(:campfire, @key, %{})

  def get(name, default \\ nil), do: Map.get(all(), name, default)

  def fetch!(name) do
    case Map.fetch(all(), name) do
      {:ok, nil} -> raise "environment variable #{name} is not set"
      {:ok, value} -> value
      :error -> raise "environment variable #{name} is not set"
    end
  end

  def set?(name), do: is_binary(get(name)) and get(name) != ""

  def put(name, value), do: Application.put_env(:campfire, @key, Map.put(all(), name, value))

  def delete(name), do: Application.put_env(:campfire, @key, Map.delete(all(), name))
end
