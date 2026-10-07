defmodule Campfire.ResponseCache do
  @moduledoc "Bounded response bodies with fresh authorization, cookies and masked CSRF tokens."
  use GenServer
  import Plug.Conn
  alias Campfire.{Auth, Chat, Rails}
  alias Exqlite.Sqlite3, as: SQL
  @capture {__MODULE__, :capture}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    {:ok, db} = SQL.open(Keyword.fetch!(opts, :path), mode: :readonly)
    :ok = SQL.execute(db, "PRAGMA query_only=ON")
    Process.flag(:trap_exit, true)

    {:ok,
     %{db: db, version: nil, incarnation: make_ref(), entries: %{}, queue: :queue.new(), bytes: 0}}
  end

  def call(conn, _) do
    epoch = if eligible?(conn), do: epoch()

    if epoch do
      # Capture before authentication; a commit during auth must prevent reuse/admission.
      {conn, user, session} = Auth.session_user(conn)
      {conn, data} = Auth.csrf_session(conn)

      if user && !data["flash"] && accessible?(conn, user) do
        conn =
          conn
          |> assign(:response_cache_auth, {user, session})
          |> assign(:response_cache_csrf, data)

        key =
          :crypto.hash(
            :sha256,
            :erlang.term_to_binary(
              {conn.scheme, conn.host, conn.port, conn.request_path, conn.query_string,
               conn.req_headers
               |> Enum.filter(fn {key, _} -> key in ["accept", "turbo-frame", "user-agent"] end),
               user["id"], session["id"], data, conn.cookies["last_room"],
               System.get_env("SECRET_KEY_BASE"), System.get_env("VAPID_PUBLIC_KEY")}
            )
          )

        case get(key, epoch) do
          nil ->
            Process.put(@capture, {"csrf-" <> Base.encode16(:crypto.strong_rand_bytes(16)), []})

            register_before_send(conn, fn response ->
              slots = finish()
              body = IO.iodata_to_binary(response.resp_body || "")

              entry = %{
                body: body,
                slots: slots,
                headers: response.resp_headers,
                cookies: Map.keys(response.resp_cookies)
              }

              if response.status == 200 &&
                   Enum.any?(
                     get_resp_header(response, "content-type"),
                     &String.starts_with?(&1, "text/html")
                   ),
                 do: put(key, epoch, entry)

              %{response | resp_body: render(entry)}
            end)

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
                do: Auth.set_csrf_session(conn, data),
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

            conn |> assign(:response_cache_hit, true) |> send_resp(200, render(entry)) |> halt()
        end
      else
        conn
      end
    else
      conn
    end
  end

  def mask(raw) do
    case Process.get(@capture) do
      {prefix, slots} ->
        slot = prefix <> "-" <> Integer.to_string(length(slots))
        Process.put(@capture, {prefix, [{slot, raw} | slots]})
        slot

      nil ->
        Rails.csrf_mask(raw)
    end
  end

  def capturing?, do: Process.get(@capture) != nil

  def finish do
    case Process.delete(@capture) do
      {_, slots} -> slots
      nil -> []
    end
  end

  defp render(entry),
    do:
      Enum.reduce(entry.slots, entry.body, fn {slot, raw}, body ->
        String.replace(body, slot, Rails.csrf_mask(raw))
      end)

  defp eligible?(conn) do
    conn.method == "GET" && get_req_header(conn, "if-none-match") == [] &&
      get_req_header(conn, "if-modified-since") == [] &&
      List.first(Campfire.ResponseFormats.requested(conn)) == "html" &&
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

  def epoch, do: GenServer.call(__MODULE__, :epoch)
  def get(key, epoch), do: GenServer.call(__MODULE__, {:get, key, epoch})
  def put(key, epoch, entry), do: GenServer.call(__MODULE__, {:put, key, epoch, entry})
  def clear, do: GenServer.call(__MODULE__, :clear)

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
    version = if limit() > 0, do: database_version(state.db)

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
