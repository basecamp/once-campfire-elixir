defmodule Campfire.SQLite do
  @moduledoc """
  SQLite connections as NIF resources, linked against the system SQLite.

  Rows are maps from column name to the stored value: integers, floats,
  text and blobs as binaries, and `nil`. Parameters are a list or a map of
  named parameters; binaries bind as text, `{:blob, iodata}` as blobs, `nil`
  and `:undefined` as NULL and other atoms as their name. Each connection
  caches up to `:statements` prepared statements and serializes its callers.
  """
  @on_load :load

  @doc false
  def load do
    :campfire
    |> :code.priv_dir()
    |> Path.join("native/campfire_sqlite")
    |> String.to_charlist()
    |> :erlang.load_nif(0)
  end

  def open(path, opts \\ []) do
    open_nif(
      path,
      Keyword.get(opts, :readonly, false),
      Keyword.get(opts, :busy_timeout, 5_000),
      Keyword.get(opts, :statements, 64)
    )
  end

  @doc """
  Runs `sql` with `params`. Returns `{:ok, rows}` or `{:error, message}`
  from SQLite, and raises `ArgumentError` for parameters it cannot bind.
  """
  def query(conn, sql, params \\ []) do
    case query_nif(conn, sql, params) do
      {:ok, _} = ok ->
        ok

      {:error, _} = error ->
        error

      {:arity, expected} when is_map(params) ->
        raise ArgumentError,
              "expected #{expected} named arguments, got #{map_size(params)}: #{inspect(Map.keys(params))}"

      {:arity, expected} ->
        raise ArgumentError, "expected #{expected} arguments, got #{length(params)}"

      {:unsupported, value} ->
        raise ArgumentError, "unsupported type: #{inspect(value)}"

      {:unknown_parameter, name} ->
        raise ArgumentError, "unknown named parameter: #{inspect(name)}"
    end
  end

  @doc "Runs one or more statements that return no rows."
  def execute(_conn, _sql), do: :erlang.nif_error(:not_loaded)

  def close(_conn), do: :erlang.nif_error(:not_loaded)

  @doc "Whether a transaction is open on the connection."
  def transaction?(_conn), do: :erlang.nif_error(:not_loaded)

  @doc false
  def statements(_conn), do: :erlang.nif_error(:not_loaded)

  defp open_nif(_path, _readonly, _busy_timeout, _statements),
    do: :erlang.nif_error(:not_loaded)

  defp query_nif(_conn, _sql, _params), do: :erlang.nif_error(:not_loaded)
end
