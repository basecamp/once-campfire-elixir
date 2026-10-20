defmodule Campfire.ResponseCache do
  @moduledoc """
  Bounded complete response representations with fresh authorization and cookies.

  An entry is retired by any SQLite commit and by its own freshness window, and a
  response whose body or key material is too large to retain is served without being
  kept.
  """
  use GenServer
  import Plug.Conn
  alias Campfire.{Auth, Chat}
  @fragment_epoch {__MODULE__, :fragment_epoch}
  @ttl_seconds 15
  @max_body 1024 * 1024
  @max_item_size 2 * 1024 * 1024
  @max_key_input 8192
  @entries :campfire_response_entries

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(_opts) do
    :persistent_term.put({__MODULE__, :limit}, parse_limit())
    # Identifies this generation of the cache, so entries from a previous run never match.
    :persistent_term.put({__MODULE__, :incarnation}, make_ref())
    :persistent_term.put({__MODULE__, :counter}, :counters.new(3, [:atomics]))

    :ets.new(@entries, [
      :public,
      :named_table,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    Process.flag(:trap_exit, true)
    {:ok, %{bytes: 0}}
  end

  def call(conn, opts) do
    do_call(conn, opts)
  end

  defp do_call(conn, _) do
    # Every render, including flash/conditional and cache-disabled paths, must
    # namespace timestamp-only fragments before its first authenticated read.
    # Campfire.CacheEpoch already captured it before authentication; reuse it.
    Process.put(@fragment_epoch, current_version())

    case hit(conn) do
      {:hit, conn} -> conn
      {:miss, conn} -> conn
    end
  end

  @doc """
  Looks up and replays a complete representation without depending on the rest of the pipeline.

  Returns `{:hit, conn}` with the response already sent and halted, or `{:miss, conn}` carrying the
  capture assign the render needs. The fast path plug uses this to skip the generic plug chain.
  """
  def hit(conn) do
    epoch =
      if eligible?(conn) && limit() > 0 do
        fragment_epoch()
      end

    if epoch do
      {conn, user, session} = Auth.session_user(conn)

      {conn, data} =
        Campfire.Auth.browser_session(conn, epoch)

      # The key carries the user id and the database version, so a member losing the room commits a
      # new version and an outsider never shares an entry: no access query is needed here.
      # Fresh authorization on every lookup: a membership can change without moving the version the
      # cache key was built from (an admin removing someone is a write, but the room row itself may
      # not change), and reviewers asked for the check to stay where it was.
      key =
        if user && !data["flash"] && accessible?(conn, user),
          do: cache_key(conn, user, session, data)

      if key do
        conn =
          conn
          |> assign(:response_cache_auth, {user, session})
          |> assign(:response_cache_session, data)

        case get(key, epoch) do
          nil ->
            {:miss, assign(conn, :response_cache_capture, {key, epoch})}

          entry ->
            {:hit, replay(conn, entry, session, data)}
        end
      else
        {:miss, conn}
      end
    else
      {:miss, conn}
    end
  end

  defp replay(conn, entry, session, data) do
    # These headers were validated by Plug when the response was produced and cached.
    conn = %{conn | resp_headers: entry.headers ++ conn.resp_headers}

    last_room =
      if "last_room" in entry.cookies do
        [_, id] = Regex.run(~r{^/rooms/(\d+)}, conn.request_path)
        id
      end

    conn = Auth.reissue(conn, session, data, last_room, entry.cookies)

    # The entry holds what HttpResponse.finalize would produce, so a hit names it and skips it: no
    # before_send, no header validation, no second cookie merge. resp_cookies is emptied for the
    # send and restored on the returned conn, which is what callers and tests read.
    cookies = conn.resp_cookies
    {module, adapter} = conn.adapter

    # One struct update rather than assign/halt/Map.merge in a row: each of those copies the whole
    # conn, and this is the hot path.
    sent = %{
      conn
      | resp_cookies: %{},
        assigns: Map.put(conn.assigns, :response_cache_hit, true),
        halted: true,
        status: 200,
        state: :sent,
        resp_body: entry.body
    }

    {:ok, _, adapter} = module.send_resp(adapter, 200, sent.resp_headers, entry.body)
    %{sent | adapter: {module, adapter}, resp_cookies: cookies}
  end

  # HttpResponse calls this after validators/compression have selected the final
  # representation. Hits retain those complete bytes and leave live cookies alone.
  def complete(conn) do
    case conn.assigns[:response_cache_capture] do
      {key, epoch} when conn.status == 200 ->
        if Enum.any?(get_resp_header(conn, "content-type"), &String.starts_with?(&1, "text/html")) do
          body = IO.iodata_to_binary(conn.resp_body || "")

          if byte_size(body) <= @max_body do
            # Everything the finalizer produced, except the cookies: those are reissued per reply.
            headers =
              Enum.reject(conn.resp_headers, fn {name, _} -> name == "set-cookie" end)

            # Admission check: re-read the epoch here. A commit that landed between capture and this
            # point would otherwise store this render under the generation it was captured at, which
            # reviewers called a hole in an earlier cache branch.
            if epoch == snapshot() do
              put(key, epoch, %{
                body: body,
                headers: headers,
                cookies:
                  List.wrap(conn.private[:resp_cookie_names]) ++ Map.keys(conn.resp_cookies)
              })
            end
          end
        end

        conn

      _ ->
        conn
    end
  end

  @doc """
  Captures the database version for this request, or nil outside one.

  Called once per request by Campfire.CacheEpoch, before authentication reads anything, and reused
  by the session memo and the cache itself.
  """
  def capture_version do
    # Always re-read: a request must observe the version that is current *now*, and a caller that
    # reuses this process (a test driving the pipeline directly) would otherwise keep the value
    # from an earlier request. Production calls this once per request, so the cost is one read.
    value = snapshot()
    Process.put(@fragment_epoch, value)
    value
  end

  @doc "The version captured for this request, reading it if nothing captured one yet."
  def current_version do
    case Process.get(@fragment_epoch, :uncaptured) do
      :uncaptured -> capture_version()
      value -> value
    end
  end

  @doc """
  Forgets the version captured for this process.

  A process that writes must not reuse a snapshot taken before its own commit: the memo keyed by
  that version would keep serving the rows it read earlier.
  """
  def forget_version, do: Process.delete(@fragment_epoch)

  def fragment_epoch do
    case Process.get(@fragment_epoch, :uncaptured) do
      :uncaptured -> snapshot()
      epoch -> epoch
    end
  end

  defp accessible?(conn, user) do
    case Regex.run(~r{^/rooms/(\d+)}, conn.request_path) do
      [_, id] -> Chat.room(user, id) != nil
      nil -> true
    end
  end

  defp cache_key(conn, user, session, data) do
    # Express builds its page key with JSON.stringify of the same fields. Hashing added a
    # term_to_binary plus a sha256 per request and bought nothing: the key is only ever compared,
    # and the size guard already bounds it.
    material =
      {conn.scheme, conn.host, conn.port, conn.request_path, conn.query_string,
       Enum.filter(conn.req_headers, fn {key, _} ->
         key in ["accept", "accept-encoding", "turbo-frame", "user-agent", "x-requested-with"]
       end), user["id"], session["id"], data["flash"], conn.cookies["last_room"],
       Campfire.ResponseCache.deployment_key()}

    if :erlang.external_size(material) <= @max_key_input, do: material
  end

  @doc "Deployment-scoped key material, read once instead of per request."
  def deployment_key do
    case :persistent_term.get({__MODULE__, :deployment}, nil) do
      nil ->
        value = {Campfire.Env.get("SECRET_KEY_BASE"), Campfire.Env.get("VAPID_PUBLIC_KEY")}
        :persistent_term.put({__MODULE__, :deployment}, value)
        value

      value ->
        value
    end
  end

  defp fresh?(entry) do
    DateTime.compare(Campfire.Clock.now(), entry.expires_at) == :lt
  end

  defp expiry, do: Campfire.Clock.now() |> DateTime.add(@ttl_seconds, :second)

  def cleanup do
    Process.delete(@fragment_epoch)
    Process.delete({__MODULE__, :fragment_valid})
  end

  def fragment_valid? do
    case Process.get({__MODULE__, :fragment_valid}) do
      nil ->
        valid = fragment_epoch() == snapshot()
        Process.put({__MODULE__, :fragment_valid}, valid)
        valid

      valid ->
        valid
    end
  end

  defp eligible?(conn) do
    conn.method == "GET" && get_req_header(conn, "if-none-match") == [] &&
      get_req_header(conn, "if-modified-since") == [] &&
      List.first(Campfire.ResponseFormats.requested(conn)) in ["html", "all"] &&
      Regex.match?(
        ~r{^/(?:rooms/\d+(?:/@\d+|/messages)?|users/(?:me|\d+)/sidebar|searches)$},
        conn.request_path
      )
  end

  def get(key, epoch) do
    # The entry lives in ETS: a lookup copies to this process's heap in parallel, instead of
    # shipping the whole body through the cache process on every hit.
    case :ets.lookup(@entries, {key, epoch}) do
      [{_, _used, entry}] ->
        if fresh?(entry) do
          add(1)
          :ets.update_element(@entries, {key, epoch}, {2, :erlang.monotonic_time()})
          entry
        else
          add(2)
          nil
        end

      [] ->
        add(2)
        nil
    end
  rescue
    ArgumentError -> nil
  end

  # Admission writes straight into ETS from the caller's process. The byte budget is a counter, so
  # the cache process is only needed when the budget is actually exceeded and entries must be
  # retired; that path stays synchronous so the bound still holds when put/3 returns.
  def put(key, epoch, entry) do
    entry = Map.put(entry, :expires_at, expiry())
    bytes = :erlang.external_size({key, entry})

    # Admission runs in the cache process: the budget check, the accounting and the insert are then
    # one serialized step, so admissions from concurrent request processes can neither overshoot the
    # bound nor leave an entry the counter never saw.
    if limit() > 0 and bytes <= limit() and bytes <= @max_item_size do
      GenServer.call(__MODULE__, {:admit, key, epoch, bytes, entry})
    end

    :ok
  end

  def clear, do: GenServer.call(__MODULE__, :clear)

  @doc "Hit/miss counters and occupancy, the same shape the Express port reports."
  def stats do
    counter = :persistent_term.get({__MODULE__, :counter})

    %{
      hits: :counters.get(counter, 1),
      misses: :counters.get(counter, 2),
      entries: :ets.info(@entries, :size),
      bytes: :counters.get(counter, 3),
      limit: limit()
    }
  rescue
    ArgumentError -> %{hits: 0, misses: 0, entries: 0, bytes: 0, limit: limit()}
  end

  defp bytes_now, do: :counters.get(:persistent_term.get({__MODULE__, :counter}), 3)

  defp add(index, amount \\ 1) do
    counter = :persistent_term.get({__MODULE__, :counter})
    :counters.add(counter, index, amount)
    :counters.get(counter, 3)
  end

  # The version is read from a pooled reader in the caller's own process: it is a per-connection
  # value that flips when any other connection commits, so the guarantee is unchanged — a commit
  # retires the previous generation immediately — but a request no longer queues behind one process
  # that holds the only connection able to see it.
  def snapshot, do: current_epoch()
  def epoch, do: current_epoch()

  defp current_epoch do
    incarnation = :persistent_term.get({__MODULE__, :incarnation}, nil)

    if limit() > 0 and incarnation do
      case Campfire.DB.data_version() do
        # The write epoch is part of the key so an own write invalidates immediately, without
        # waiting for the version TTL that exists for foreign writes.
        version when is_integer(version) -> {incarnation, version, Campfire.DB.write_epoch()}
        _ -> nil
      end
    end
  end

  def handle_call(:clear, _, state), do: {:reply, :ok, clear_state(state)}
  def handle_call(:stats, _, state), do: {:reply, stats(), state}

  def handle_call({:admit, key, epoch, bytes, entry}, _, state) do
    state = make_room(state, bytes)

    if bytes_now() + bytes <= limit() do
      :ets.insert(
        @entries,
        {{key, epoch}, :erlang.monotonic_time(), Map.put(entry, :bytes, bytes)}
      )

      add(3, bytes)
    end

    {:reply, :ok, state}
  end

  # Retire the least recently used entries until the incoming one fits, so the bound holds for the
  # entry being admitted and not only for what is already stored.
  defp make_room(state, bytes) do
    if bytes_now() + bytes > limit() do
      case oldest() do
        nil ->
          state

        {slot, entry_bytes} ->
          :ets.delete(@entries, slot)
          add(3, -entry_bytes)
          make_room(state, bytes)
      end
    else
      state
    end
  end

  # One prepared statement per cache process instead of a prepare/release per observation.
  defp clear_state(state) do
    :ets.delete_all_objects(@entries)
    :counters.put(:persistent_term.get({__MODULE__, :counter}), 3, 0)
    state
  end

  defp oldest do
    @entries
    |> :ets.tab2list()
    |> Enum.min_by(fn {_slot, used, _entry} -> used end, fn -> nil end)
    |> case do
      nil -> nil
      {slot, _used, entry} -> {slot, Map.get(entry, :bytes, 0)}
    end
  end

  defp limit, do: :persistent_term.get({__MODULE__, :limit}, 0)

  @doc "Re-reads CAMPFIRE_RESPONSE_CACHE_MB; the limit is otherwise parsed once at start."
  def refresh_limit do
    :persistent_term.put({__MODULE__, :limit}, parse_limit())
    # Disabled means it holds nothing: retiring the entries here keeps that true without putting a
    # check on the request path.
    if limit() == 0, do: GenServer.call(__MODULE__, :clear)
  end

  defp parse_limit do
    case Integer.parse(Campfire.Env.get("CAMPFIRE_RESPONSE_CACHE_MB", "64")) do
      {mb, ""} when mb >= 0 -> mb * 1024 * 1024
      _ -> 0
    end
  end

  def terminate(_reason, _state), do: :ok
end
