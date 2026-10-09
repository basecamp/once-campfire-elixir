defmodule Campfire.ResponseCache do
  @moduledoc """
  Bounded complete response representations with fresh authorization and cookies.

  The owning process holds the dedicated SQLite connection that observes commits
  (`PRAGMA data_version`), admits and evicts entries, and keeps the byte accounting. The
  entries themselves live in a public ETS table tagged with the epoch they were admitted
  under: a request captures its epoch with one owner call before authentication, reads the
  entry itself, and confirms with a second, equally small call that the epoch is still
  current before acting on anything it read. Authentication and room authorization rows
  read on that path are remembered under the same epoch, so a warm request does no SQLite
  query at all; any commit by any writer advances the epoch and retires both tables.
  """
  use GenServer
  import Plug.Conn
  alias Campfire.{Auth, Chat, Rails}
  alias Exqlite.Sqlite3, as: SQL
  @fragment_epoch {__MODULE__, :fragment_epoch}
  @entries __MODULE__.Entries
  @authorization __MODULE__.Authorization
  @authorization_capacity 4096

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    {:ok, db} = SQL.open(Keyword.fetch!(opts, :path), mode: :readonly)
    :ok = SQL.execute(db, "PRAGMA query_only=ON")
    {:ok, statement} = SQL.prepare(db, "PRAGMA data_version")
    Process.flag(:trap_exit, true)

    for table <- [@entries, @authorization] do
      :ets.new(table, [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    {:ok,
     %{
       db: db,
       statement: statement,
       version: nil,
       incarnation: make_ref(),
       queue: :queue.new(),
       bytes: 0
     }}
  end

  def call(conn, _) do
    # Every render, including flash/conditional and cache-disabled paths, must
    # namespace timestamp-only fragments before its first authenticated read, which for
    # eligible requests already happened in `authenticate/1`. Routes that never render
    # fragments skip the owner entirely.
    if fragments?(conn) and not captured?(), do: Process.put(@fragment_epoch, snapshot())
    serve(conn, true)
  end

  @doc """
  The request's session for plugs that run before the cache. An eligible request captures
  its epoch here, resolves the rows under it and keeps them for `call/2` and the handler,
  so a page is authenticated once; any other request is authenticated as before.
  """
  def authenticate(conn) do
    if eligible?(conn) && limit() > 0 do
      if not captured?(), do: Process.put(@fragment_epoch, snapshot())
      {conn, user, session} = session_user(conn, fragment_epoch(), true)
      conn = if user, do: assign(conn, :response_cache_auth, {user, session}), else: conn
      {conn, user, session}
    else
      Auth.session_user(conn)
    end
  end

  @doc "The rows from `authenticate/1` read again from the database, for a response sent before `call/2`."
  def reauthenticate(%{assigns: %{response_cache_auth: _}} = conn, _user, _session),
    do: Auth.session_user(%{conn | assigns: Map.delete(conn.assigns, :response_cache_auth)})

  def reauthenticate(conn, user, session), do: {conn, user, session}

  defp captured?, do: Process.get(@fragment_epoch, :uncaptured) != :uncaptured

  # Rows and entries are acted on only once the owner confirms, after they were read, that
  # the request's epoch is still current. If a commit landed in between, the request
  # captures the new epoch and authenticates from the database once more.
  defp serve(conn, remembered?) do
    epoch = if eligible?(conn) && limit() > 0, do: fragment_epoch()

    if epoch do
      # Capture before authentication; a commit during auth must prevent reuse/admission.
      {conn, user, session} =
        case conn.assigns do
          %{response_cache_auth: {user, session}} when remembered? -> {conn, user, session}
          _ -> session_user(conn, epoch, remembered?)
        end

      {conn, data} = Auth.browser_session(conn)

      if user && !data["flash"] && accessible?(conn, user, epoch, remembered?) do
        authorized =
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

        entry = get(key, epoch)

        cond do
          current?(epoch) ->
            if entry,
              do: serve_hit(authorized, entry, session, data),
              else: assign(authorized, :response_cache_capture, {key, epoch})

          remembered? ->
            Process.put(@fragment_epoch, snapshot())
            serve(%{conn | assigns: Map.delete(conn.assigns, :response_cache_auth)}, false)

          true ->
            assign(authorized, :response_cache_capture, {key, epoch})
        end
      else
        conn
      end
    else
      conn
    end
  end

  defp serve_hit(conn, entry, session, data) do
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

  defp eligible?(conn) do
    conn.method == "GET" && get_req_header(conn, "if-none-match") == [] &&
      get_req_header(conn, "if-modified-since") == [] &&
      List.first(Campfire.ResponseFormats.requested(conn)) in ["html", "all"] &&
      Regex.match?(
        ~r{^/(?:rooms/\d+(?:/@\d+|/messages)?|users/(?:me|\d+)/sidebar|searches)$},
        conn.request_path
      )
  end

  # Health, Cable, avatar, logo and QR reads render no fragments and need no epoch.
  defp fragments?(%{method: "GET", request_path: path}) do
    path not in ["/up", "/cable"] and
      not String.starts_with?(path, "/account/logo") and
      not String.starts_with?(path, "/qr_code/") and
      not Regex.match?(~r{^/users/[^/]+/avatar$}, path)
  end

  defp fragments?(_conn), do: true

  # The session and user rows for a verified cookie, remembered under the request's epoch.
  # Resuming still runs so an idle session is touched exactly as before.
  defp session_user(conn, epoch, remembered?) do
    conn = fetch_cookies(conn)

    with raw when is_binary(raw) <- conn.cookies["session_token"],
         token when is_binary(token) <- Rails.verify_cookie("session_token", URI.decode(raw)) do
      case remembered? && lookup(@authorization, {epoch, :session, token}) do
        [{_, {user, session}}] ->
          {conn, user, Auth.resume_session(conn, session)}

        _ ->
          case Auth.session_user(conn) do
            {conn, user, session} when is_map(user) ->
              remember({epoch, :session, token}, {user, session})
              {conn, user, session}

            {conn, _, _} ->
              {conn, nil, nil}
          end
      end
    else
      _ -> {conn, nil, nil}
    end
  end

  defp accessible?(conn, user, epoch, remembered?) do
    case user && Regex.run(~r{^/rooms/(\d+)}, conn.request_path) do
      [_, id] ->
        key = {epoch, :room, user["id"], id}

        case remembered? && lookup(@authorization, key) do
          [{^key, room}] ->
            room != nil

          _ ->
            room = Chat.room(user, id)
            remember(key, room)
            room != nil
        end

      _ ->
        true
    end
  end

  # A full table stops remembering until the next commit retires it; every commit does.
  defp remember(key, value) do
    if :ets.info(@authorization, :size) < @authorization_capacity,
      do: :ets.insert(@authorization, {key, value})
  rescue
    ArgumentError -> false
  end

  # While the owner is restarting its tables are gone; that is a miss, not an error.
  defp lookup(table, key) do
    :ets.lookup(table, key)
  rescue
    ArgumentError -> []
  end

  def snapshot, do: GenServer.call(__MODULE__, :snapshot)
  def epoch, do: GenServer.call(__MODULE__, :epoch)

  @doc "Whether `epoch` is still the database's current epoch, observed now."
  def current?(epoch), do: GenServer.call(__MODULE__, {:current?, epoch})

  @doc "The entry admitted under `epoch`, read from the table without the owner."
  def get(key, epoch) do
    case lookup(@entries, key) do
      [{^key, ^epoch, entry}] when epoch != nil -> if limit() > 0, do: entry
      _ -> nil
    end
  end

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

  def handle_call({:current?, epoch}, _, state) do
    state = observe(state)

    {:reply, limit() > 0 && state.version != nil && epoch == {state.incarnation, state.version},
     state}
  end

  # Clearing also retires every epoch captured so far, so nothing read before it is acted on.
  def handle_call(:clear, _, state),
    do: {:reply, :ok, %{clear_state(state) | incarnation: make_ref()}}

  def handle_call({:put, key, epoch, entry}, _, state) do
    state = observe(state)
    bytes = :erlang.external_size({key, entry})

    state =
      if state.version != nil && epoch == {state.incarnation, state.version} && bytes <= limit() &&
           limit() > 0 &&
           !:ets.member(@entries, key) do
        state = evict(state, bytes)
        :ets.insert(@entries, {key, epoch, entry})
        %{state | queue: :queue.in({key, bytes}, state.queue), bytes: state.bytes + bytes}
      else
        state
      end

    {:reply, :ok, state}
  end

  defp observe(state) do
    {version, state} = database_version(state)
    state = if limit() == 0, do: clear_state(state), else: state

    if version == state.version && version != nil,
      do: state,
      else: %{clear_state(state) | version: version}
  end

  # The statement stays prepared across calls; one that fails to step is replaced.
  defp database_version(%{db: db, statement: statement} = state) do
    case SQL.step(db, statement) do
      {:row, [version]} ->
        SQL.reset(statement)
        {version, state}

      _ ->
        SQL.release(db, statement)
        {:ok, statement} = SQL.prepare(db, "PRAGMA data_version")
        {nil, %{state | statement: statement}}
    end
  end

  defp clear_state(state) do
    :ets.delete_all_objects(@entries)
    :ets.delete_all_objects(@authorization)
    %{state | queue: :queue.new(), bytes: 0}
  end

  defp evict(state, bytes) do
    if (state.bytes + bytes > limit() || :ets.info(@entries, :size) >= 4096) &&
         not :queue.is_empty(state.queue) do
      {{:value, {key, old_bytes}}, queue} = :queue.out(state.queue)
      :ets.delete(@entries, key)
      evict(%{state | queue: queue, bytes: state.bytes - old_bytes}, bytes)
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

  def terminate(_, %{db: db, statement: statement}) do
    SQL.release(db, statement)
    SQL.close(db)
  end
end
