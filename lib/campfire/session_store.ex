defmodule Campfire.SessionStore do
  @moduledoc """
  Per-version memo for session, user and membership reads.

  Entries are keyed by the database version the response cache already observes, so any commit
  makes the previous generation unreachable: a revoked session or a changed membership can never
  be served from an older entry. Outside a request there is no version and the memo is skipped.
  """

  @table :campfire_session_store
  @doc "The table this memo uses; owned by Campfire.Tables."
  def table, do: @table

  def fetch(nil, _key, fun), do: fun.()

  def fetch(version, key, fun) do
    ensure_table()

    case lookup(version, key) do
      {:ok, value} ->
        value

      :miss ->
        value = fun.()
        store(version, key, value)
        value
    end
  end

  defp lookup(version, key) do
    case :ets.lookup(@table, {version, key}) do
      [{_, value}] -> {:ok, value}
      [] -> :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp store(version, key, value) do
    :ets.insert(@table, {{version, key}, value})
  rescue
    ArgumentError -> :ok
  end

  @doc "Drops every generation except `version`; called when the observed version changes."
  def sweep(version) do
    if :ets.whereis(@table) != :undefined do
      for {{stored, _key} = slot, _} <- :ets.tab2list(@table),
          stored != version,
          do: :ets.delete(@table, slot)
    end

    :ok
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
