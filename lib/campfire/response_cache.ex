defmodule Campfire.ResponseCache do
  @moduledoc """
  Complete responses for authenticated pages, remembered with their ETag and gzip body.

  Entries are keyed on everything a page depends on besides the database: the user, the
  CSRF session token, route inputs, base URL, User-Agent and Turbo-Frame header. Pages
  whose database inputs are not cheap to enumerate also key on `generation/0`, which
  every committed write advances, so a hit can never serve data older than the last write.
  Static files are remembered compressed with their metadata in a second table.
  """
  use GenServer
  import Plug.Conn
  @table __MODULE__
  @static Campfire.ResponseCache.Static
  @max_entries 512
  @max_bytes 128 * 1024 * 1024

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@static, [:named_table, :set, :public, read_concurrency: true])
    :persistent_term.put({__MODULE__, :counters}, :atomics.new(2, signed: false))
    {:ok, nil}
  end

  defp counters, do: :persistent_term.get({__MODULE__, :counters}, nil)

  @doc "The database write generation. Every committed write advances it."
  def generation do
    case counters() do
      nil -> 0
      ref -> :atomics.get(ref, 1)
    end
  end

  def bump do
    case counters() do
      nil -> :ok
      ref -> :atomics.add(ref, 1, 1)
    end
  end

  def clear do
    :ets.delete_all_objects(@table)
    if ref = counters(), do: :atomics.put(ref, 2, 0)
    :ok
  end

  @doc """
  Send a 200 response, from the cache when `terms` identify a remembered page.

  `terms` of nil disables caching for this response (flash messages, errors). The
  rendered body is remembered by `Campfire.HttpResponse` once its ETag and compressed
  form are known.
  """
  def send(conn, nil, render), do: send_resp(conn, 200, render.())

  def send(conn, terms, render) do
    key = :crypto.hash(:sha256, :erlang.term_to_binary(terms))

    case :ets.lookup(@table, key) do
      [{^key, entry}] ->
        conn |> assign(:response_cache_hit, entry) |> send_resp(200, entry.body)

      [] ->
        conn |> assign(:response_cache_store, key) |> send_resp(200, render.())
    end
  end

  def store(key, body, etag, gzip, preload) when is_binary(body) do
    ref = counters()
    bytes = byte_size(body) + if(gzip, do: byte_size(gzip), else: 0)

    if :ets.info(@table, :size) >= @max_entries ||
         (ref && :atomics.get(ref, 2) + bytes > @max_bytes),
       do: clear()

    if ref, do: :atomics.add(ref, 2, bytes)

    :ets.insert(
      @table,
      {key, %{key: key, body: body, etag: etag, gzip: gzip, preload: preload}}
    )

    :ok
  end

  def put_gzip(%{key: key} = entry, gzip) do
    :ets.insert(@table, {key, %{entry | gzip: gzip}})
    if ref = counters(), do: :atomics.add(ref, 2, byte_size(gzip))
    :ok
  end

  @doc "Remember an immutable static file derivative under `key`."
  def static(key, compute) do
    case :ets.lookup(@static, key) do
      [{^key, value}] ->
        value

      [] ->
        value = compute.()
        :ets.insert(@static, {key, value})
        value
    end
  end
end
