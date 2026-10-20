defmodule Campfire.Memo do
  @moduledoc """
  ETS memo for values that are expensive to derive and cheap to key.

  `:persistent_term` is the wrong home for these: a write copies the term into the literal area and
  forces a global GC, so every new key — a user agent, a cookie salt, an asset path — is a
  system-wide event. ETS writes are local to the table, and reads are lock-free with
  `read_concurrency`.
  """

  @table :campfire_memo
  @doc "The table this memo uses; owned by Campfire.Tables."
  def table, do: @table

  def fetch(key, fun) do
    ensure_table()

    case lookup(key) do
      {:ok, value} ->
        value

      :miss ->
        value = fun.()
        store(key, value)
        value
    end
  end

  defp lookup(key) do
    case :ets.lookup(@table, key) do
      [{_, value}] -> {:ok, value}
      [] -> :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp store(key, value) do
    :ets.insert(@table, {key, value})
  rescue
    ArgumentError -> :ok
  end

  def get(key, default \\ nil) do
    ensure_table()

    case :ets.lookup(@table, key) do
      [{_, value}] -> value
      [] -> default
    end
  rescue
    ArgumentError -> default
  end

  def clear do
    if :ets.whereis(@table) != :undefined, do: :ets.delete_all_objects(@table)
    :ok
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [
        :public,
        :named_table,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])
    end
  rescue
    ArgumentError -> :ok
  end
end
