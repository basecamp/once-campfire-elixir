defmodule Campfire.ResponseCache do
  @moduledoc "Bounded complete response representations with fresh authorization and cookies."
  use GenServer
  import Plug.Conn
  alias Campfire.{Auth, Chat}
  alias Exqlite.Sqlite3, as: SQL
  @fragment_epoch {__MODULE__, :fragment_epoch}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    {:ok, db} = SQL.open(Keyword.fetch!(opts, :path), mode: :readonly)
    :ok = SQL.execute(db, "PRAGMA query_only=ON")
    Process.flag(:trap_exit, true)

    {:ok,
     %{db: db, version: nil, incarnation: make_ref(), entries: %{}, queue: :queue.new(), bytes: 0}}
  end

  def call(conn, _) do
    # Every render, including flash/conditional and cache-disabled paths, must
    # namespace timestamp-only fragments before its first authenticated read.
    # Routes that never render message fragments skip the snapshot (a SQLite
    # query); fragment_epoch/0 still captures one lazily if needed.
    if fragments?(conn), do: Process.put(@fragment_epoch, snapshot())
    epoch = if eligible?(conn) && limit() > 0, do: fragment_epoch()

    if epoch do
      # Capture before authentication; a commit during auth must prevent reuse/admission.
      {conn, user, session} = Auth.session_user(conn)
      {conn, data} = Auth.browser_session(conn)

      if user && !data["flash"] && accessible?(conn, user) do
        conn =
          conn
          |> assign(:response_cache_auth, {user, session})
          |> assign(:response_cache_session, data)

        key =
          :crypto.hash(
            :sha256,
            :erlang.term_to_binary(
              {conn.scheme, conn.host, conn.port, conn.request_path, conn.query_string,
               conn.req_headers
               |> Enum.filter(fn {key, _} ->
                 key in [
                   "accept",
                   "accept-encoding",
                   "turbo-frame",
                   "user-agent",
                   "x-requested-with"
                 ]
               end), user["id"], session["id"], data, conn.cookies["last_room"],
               System.get_env("SECRET_KEY_BASE"), System.get_env("VAPID_PUBLIC_KEY")}
            )
          )

        case get(key, epoch) do
          nil ->
            assign(conn, :response_cache_capture, {key, epoch})

          entry ->
            conn =
              Enum.reduce(entry.headers, conn, fn {name, value}, acc ->
                put_resp_header(acc, name, value)
              end)

            conn =
              if "session_token" in entry.cookies,
                do: Auth.set_auth_cookie(conn, session),
                else: conn

            conn =
              if "_campfire_session" in entry.cookies,
                do: Auth.set_browser_session(conn, data),
                else: conn

            conn =
              if "last_room" in entry.cookies do
                [_, id] = Regex.run(~r{^/rooms/(\d+)}, conn.request_path)

                put_resp_cookie(conn, "last_room", id,
                  max_age: DateTime.diff(Auth.permanent_expiry(), Campfire.Clock.now())
                )
              else
                conn
              end

            conn |> assign(:response_cache_hit, true) |> send_resp(200, entry.body) |> halt()
        end
      else
        conn
      end
    else
      conn
    end
  end

  # HttpResponse calls this after validators/compression have selected the final
  # representation. Hits retain those complete bytes and leave live cookies alone.
  def complete(conn) do
    case conn.assigns[:response_cache_capture] do
      {key, epoch} when conn.status == 200 ->
        if Enum.any?(get_resp_header(conn, "content-type"), &String.starts_with?(&1, "text/html")) do
          body = IO.iodata_to_binary(conn.resp_body || "")

          headers =
            Enum.filter(conn.resp_headers, fn {name, _} ->
              name in [
                "content-type",
                "content-encoding",
                "content-length",
                "etag",
                "last-modified",
                "cache-control",
                "vary",
                "link"
              ]
            end)

          put(key, epoch, %{body: body, headers: headers, cookies: Map.keys(conn.resp_cookies)})
        end

        conn

      _ ->
        conn
    end
  end

  def fragment_epoch do
    case Process.get(@fragment_epoch, :uncaptured) do
      :uncaptured -> snapshot()
      epoch -> epoch
    end
  end

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

  defp fragments?(%{path_info: path}) do
    case path do
      ["up"] ->
        false

      ["cable"] ->
        false

      ["rails", "active_storage" | _] ->
        false

      ["users", _, "avatar"] ->
        false

      ["account", "logo"] ->
        false

      ["qr_code", _] ->
        false

      [asset] when asset in ~w(webmanifest service-worker webmanifest.json service-worker.js) ->
        false

      _ ->
        true
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

  defp accessible?(conn, user) do
    case Regex.run(~r{^/rooms/(\d+)}, conn.request_path) do
      [_, id] -> Chat.room(user, id) != nil
      nil -> true
    end
  end

  def snapshot, do: GenServer.call(__MODULE__, :snapshot)
  def epoch, do: GenServer.call(__MODULE__, :epoch)
  def get(key, epoch), do: GenServer.call(__MODULE__, {:get, key, epoch})
  def put(key, epoch, entry), do: GenServer.call(__MODULE__, {:put, key, epoch, entry})
  def clear, do: GenServer.call(__MODULE__, :clear)

  def handle_call(:snapshot, _, state) do
    state = observe(state)
    {:reply, if(state.version != nil, do: {state.incarnation, state.version}), state}
  end

  def handle_call(:epoch, _, state) do
    state = observe(state)

    {:reply, if(limit() > 0 && state.version != nil, do: {state.incarnation, state.version}),
     state}
  end

  def handle_call(:clear, _, state), do: {:reply, :ok, clear_state(state)}

  def handle_call({:get, key, epoch}, _, state) do
    state = observe(state)

    value =
      if state.version != nil && epoch == {state.incarnation, state.version} && limit() > 0,
        do: Map.get(state.entries, key)

    {:reply, value, state}
  end

  def handle_call({:put, key, epoch, entry}, _, state) do
    state = observe(state)
    bytes = :erlang.external_size({key, entry})

    state =
      if state.version != nil && epoch == {state.incarnation, state.version} && bytes <= limit() &&
           limit() > 0 &&
           !Map.has_key?(state.entries, key) do
        state = evict(state, bytes)

        %{
          state
          | entries: Map.put(state.entries, key, entry),
            queue: :queue.in({key, bytes}, state.queue),
            bytes: state.bytes + bytes
        }
      else
        state
      end

    {:reply, :ok, state}
  end

  defp observe(state) do
    version = database_version(state.db)
    state = if limit() == 0, do: clear_state(state), else: state

    if version == state.version && version != nil,
      do: state,
      else: %{clear_state(state) | version: version}
  end

  defp database_version(db) do
    case SQL.prepare(db, "PRAGMA data_version") do
      {:ok, stmt} ->
        try do
          case SQL.fetch_all(db, stmt) do
            {:ok, [[version]]} -> version
            _ -> nil
          end
        after
          SQL.release(db, stmt)
        end

      _ ->
        nil
    end
  end

  defp clear_state(state), do: %{state | entries: %{}, queue: :queue.new(), bytes: 0}
  defp evict(state, _bytes) when map_size(state.entries) == 0, do: state

  defp evict(state, bytes) do
    if state.bytes + bytes > limit() || map_size(state.entries) >= 4096 do
      {{:value, {key, old_bytes}}, queue} = :queue.out(state.queue)

      evict(
        %{
          state
          | entries: Map.delete(state.entries, key),
            queue: queue,
            bytes: state.bytes - old_bytes
        },
        bytes
      )
    else
      state
    end
  end

  defp limit do
    case Integer.parse(System.get_env("CAMPFIRE_RESPONSE_CACHE_MB", "64")) do
      {mb, ""} when mb >= 0 -> mb * 1024 * 1024
      _ -> 0
    end
  end

  def terminate(_, state), do: SQL.close(state.db)
end
