defmodule Campfire.Front.Cache do
  @moduledoc """
  Thruster's response cache (`cache_handler.go`, `memory_cache.go`, `variant.go`) in ETS.

  GET and HEAD responses that say `public` with a positive `s-max-age` (sic) or `max-age`,
  and no `no-cache`, are kept until they expire and served again with `X-Cache: hit` to
  requests with the same method, path, query, host and `Vary`ing header values. `CACHE_SIZE`
  bounds the total, counting keys, headers and bodies. A gzipped copy of an entry is kept
  once made, since compression is deterministic for a body.
  """
  use GenServer
  @max_uri 2048
  @overhead 256

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    :ets.new(__MODULE__, [:named_table, :set, :public, read_concurrency: true])
    :persistent_term.put({__MODULE__, :size}, :atomics.new(1, signed: true))
    {:ok, nil}
  end

  def clear do
    :ets.delete_all_objects(__MODULE__)
    :atomics.put(size_ref(), 1, 0)
    :ok
  end

  @doc "Whether a request may be served from, or stored in, the cache (`shouldCacheRequest`)."
  def cacheable_request?(conn) do
    conn.method in ["GET", "HEAD"] and
      header(conn.req_headers, "connection") != "Upgrade" and
      header(conn.req_headers, "upgrade") != "websocket" and
      header(conn.req_headers, "range") == "" and
      byte_size(conn.request_path) + byte_size(conn.query_string) < @max_uri
  end

  def base_key(conn),
    do: [conn.method, ?\n, conn.request_path, ?\n, conn.query_string, ?\n, host(conn)]

  @doc "The fresh entry for a request, trying the stored response's `Vary` variant."
  def lookup(conn, base, now) do
    case get(IO.iodata_to_binary(base), now) do
      nil ->
        nil

      {_key, _, _, _, headers, _, variant, _} = entry ->
        names = vary_names(headers)

        if names == [] or variant == variant_values(conn, names),
          do: entry,
          else: get(key(base, conn, names), now)
    end
  end

  defp get(key, now) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, expires, _, _, _, _, _, _} = entry] when expires > now -> entry
      _ -> nil
    end
  end

  @doc "How long a response may be cached, in milliseconds (`CacheStatus`), or nil."
  def lifetime(status, headers) do
    cache_control = header(headers, "cache-control")

    with true <- status in 200..399 and status != 304,
         false <- String.contains?(header(headers, "vary"), "*"),
         true <- Regex.match?(~r/\bpublic\b/, cache_control),
         false <- Regex.match?(~r/\bno-cache\b/, cache_control),
         [_, seconds] <-
           Regex.run(~r/\bs-max-age=(\d+)\b/, cache_control) ||
             Regex.run(~r/\bmax-age=(\d+)\b/, cache_control),
         {seconds, ""} when seconds > 0 <- Integer.parse(seconds) do
      seconds * 1000
    else
      _ -> nil
    end
  end

  def store(conn, base, status, headers, body, lifetime, now, config) do
    body = IO.iodata_to_binary(body)
    # Stored under the base key with the request's varying values, as Thruster does: a
    # lookup finds it there and serves it when those values match.
    names = vary_names(headers)
    key = IO.iodata_to_binary(base)

    size =
      byte_size(key) + byte_size(body) + @overhead +
        Enum.reduce(headers, 0, fn {k, v}, sum -> sum + byte_size(k) + byte_size(v) end)

    if byte_size(body) <= config.max_cache_item_size and size <= config.cache_size do
      make_room(size, config.cache_size, now)

      entry =
        {key, now + lifetime, size, status, headers, body, variant_values(conn, names), nil}

      case :ets.lookup(__MODULE__, key) do
        [{^key, _, old, _, _, _, _, _}] -> :atomics.sub(size_ref(), 1, old)
        [] -> :ok
      end

      :ets.insert(__MODULE__, entry)
      :atomics.add(size_ref(), 1, size)
    end

    :ok
  end

  @doc "Remembers the gzipped body of an entry."
  def put_gzip({key, _, _, _, _, _, _, nil}, gzipped),
    do: :ets.update_element(__MODULE__, key, {8, gzipped})

  def put_gzip(_, _), do: true

  defp make_room(size, capacity, now) do
    ref = size_ref()

    if :atomics.get(ref, 1) + size > capacity do
      expired =
        :ets.select(__MODULE__, [
          {{:"$1", :"$2", :"$3", :_, :_, :_, :_, :_}, [{:"=<", :"$2", now}], [{{:"$1", :"$3"}}]}
        ])

      for {key, old} <- expired, do: delete(key, old)
      evict(:ets.first(__MODULE__), size, capacity)
    end
  end

  defp evict(:"$end_of_table", _, _), do: :ok

  defp evict(key, size, capacity) do
    if :atomics.get(size_ref(), 1) + size > capacity do
      next = :ets.next(__MODULE__, key)

      case :ets.lookup(__MODULE__, key) do
        [{^key, _, old, _, _, _, _, _}] -> delete(key, old)
        [] -> :ok
      end

      evict(next, size, capacity)
    end
  end

  defp delete(key, size) do
    if :ets.take(__MODULE__, key) != [], do: :atomics.sub(size_ref(), 1, size)
  end

  defp size_ref, do: :persistent_term.get({__MODULE__, :size})

  defp key(base, _conn, []), do: IO.iodata_to_binary(base)

  defp key(base, conn, names),
    do:
      IO.iodata_to_binary([
        base | Enum.map(variant_values(conn, names), fn {n, v} -> [?\n, n, ?=, v] end)
      ])

  defp vary_names(headers) do
    case header(headers, "vary") do
      "" ->
        []

      vary ->
        vary
        |> String.split(",")
        |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
        |> Enum.sort()
    end
  end

  defp variant_values(conn, names), do: Enum.map(names, &{&1, header(conn.req_headers, &1)})

  defp host(conn) do
    case header(conn.req_headers, "host") do
      "" -> conn.host
      host -> host
    end
  end

  def header(headers, name) do
    case List.keyfind(headers, name, 0) do
      {_, value} -> value
      nil -> ""
    end
  end
end
