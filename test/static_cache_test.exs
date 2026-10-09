defmodule Campfire.StaticCacheTest do
  use ExUnit.Case, async: false
  import Plug.Test
  alias Campfire.{Assets, Router, StaticCache}

  @budget 32 * 1024 * 1024
  @compared ~w(content-type last-modified cache-control vary content-encoding content-length content-range)

  setup do
    StaticCache.configure(@budget)
    on_exit(fn -> StaticCache.configure(@budget) end)
    :ok
  end

  defp get(path, headers \\ [], method \\ :get) do
    conn = conn(method, path)
    conn = Enum.reduce(headers, conn, fn {k, v}, c -> Plug.Conn.put_req_header(c, k, v) end)
    Router.call(conn, Router.init([]))
  end

  defp headers(conn, names), do: Enum.map(names, &{&1, Plug.Conn.get_resp_header(conn, &1)})
  defp css, do: Assets.path("_reset.css")

  defp disk(path),
    do:
      File.read!(Path.join([:code.priv_dir(:campfire), "static", String.trim_leading(path, "/")]))

  defp gzip_entry?(path),
    do: match?([{_, %{gzip: g}}] when is_binary(g), :ets.lookup(StaticCache, path))

  test "identity and gzip responses are byte-identical before and after admission" do
    first = get(css())
    assert first.status == 200 and first.resp_body == disk(css())
    assert StaticCache.stats() == %{entries: 1, bytes: byte_size(disk(css())), limit: @budget}
    second = get(css())
    assert second.resp_body == first.resp_body
    assert headers(second, @compared) == headers(first, @compared)

    gz1 = get(css(), [{"accept-encoding", "gzip"}])
    gz2 = get(css(), [{"accept-encoding", "gzip"}])
    assert Plug.Conn.get_resp_header(gz1, "content-encoding") == ["gzip"]
    assert :zlib.gunzip(gz1.resp_body) == disk(css())
    # Only the gzip header's timestamp may differ between responses.
    assert binary_part(gz1.resp_body, 8, byte_size(gz1.resp_body) - 8) ==
             binary_part(gz2.resp_body, 8, byte_size(gz2.resp_body) - 8)

    assert headers(gz2, @compared) == headers(gz1, @compared)
    assert StaticCache.stats().bytes == byte_size(disk(css())) + byte_size(gz1.resp_body)
  end

  test "gzip is compressed only once gzip is negotiated" do
    path = Path.join([:code.priv_dir(:campfire), "static", String.trim_leading(css(), "/")])
    assert get(css()).status == 200
    assert get(css(), [{"range", "bytes=0-9"}]).status == 206
    refute gzip_entry?(path), "identity and range requests never compress"
    assert get(css(), [{"accept-encoding", "gzip"}]).status == 200
    assert gzip_entry?(path)
  end

  test "HEAD carries the GET headers and no body, cached or not" do
    for _ <- 1..2 do
      head = get(css(), [{"accept-encoding", "gzip"}], :head)
      full = get(css(), [{"accept-encoding", "gzip"}])
      assert head.status == 200 and head.resp_body == ""
      assert headers(head, @compared) == headers(full, @compared)
    end
  end

  test "HEAD without gzip keeps the identity headers and content length" do
    for _ <- 1..2 do
      head = get(css(), [], :head)
      full = get(css())
      assert head.status == 200 and head.resp_body == ""
      assert headers(head, @compared) == headers(full, @compared)

      assert Plug.Conn.get_resp_header(head, "content-length") == [
               to_string(byte_size(disk(css())))
             ]
    end
  end

  test "multipart range responses are computed from the cached bytes" do
    data = disk(css())
    assert get(css()).status == 200

    for headers <- [[], [{"accept-encoding", "gzip"}]] do
      response = get(css(), [{"range", "bytes=0-9,20-29"} | headers])
      assert response.status == 206
      body = if headers == [], do: response.resp_body, else: :zlib.gunzip(response.resp_body)
      assert body =~ "--AaB03x"
      assert body =~ "content-range: bytes 0-9/#{byte_size(data)}"
      assert body =~ binary_part(data, 20, 10)
    end
  end

  test "requests keep working while the cache owner is restarting" do
    assert get(css()).status == 200
    Process.exit(Process.whereis(StaticCache), :kill)
    assert get(css()).status == 200 and get(css()).resp_body == disk(css())
    assert :zlib.gunzip(get(css(), [{"accept-encoding", "gzip"}]).resp_body) == disk(css())
    Process.sleep(50)
    assert get(css()).status == 200
  end

  test "conditional and range requests behave as before and bypass the cached body" do
    first = get(css())
    modified = hd(Plug.Conn.get_resp_header(first, "last-modified"))
    fresh = get(css(), [{"if-modified-since", modified}])
    assert fresh.status == 304 and fresh.resp_body == ""
    assert Plug.Conn.get_resp_header(fresh, "content-length") == ["0"]

    data = disk(css())
    range = get(css(), [{"range", "bytes=10-29"}])
    assert range.status == 206 and range.resp_body == binary_part(data, 10, 20)
    assert Plug.Conn.get_resp_header(range, "content-range") == ["bytes 10-29/#{byte_size(data)}"]

    zipped = get(css(), [{"range", "bytes=10-29"}, {"accept-encoding", "gzip"}])
    assert zipped.status == 206 and :zlib.gunzip(zipped.resp_body) == binary_part(data, 10, 20)
    assert get(css(), [{"range", "bytes=#{byte_size(data) + 5}-"}]).status == 416
    assert StaticCache.stats().entries == 1
  end

  test "the budget admits what fits and evicts the oldest entry first" do
    small = css()
    other = Assets.path("application.js")
    gzip = [{"accept-encoding", "gzip"}]
    assert get(small, gzip).status == 200
    small_bytes = StaticCache.stats().bytes
    assert get(other, gzip).status == 200
    both_bytes = StaticCache.stats().bytes
    assert both_bytes > small_bytes

    StaticCache.configure(both_bytes)
    assert get(small, gzip).status == 200 and get(other, gzip).status == 200
    assert StaticCache.stats() == %{entries: 2, bytes: both_bytes, limit: both_bytes}

    big = Assets.path("lexxy.js")
    assert get(big).status == 200 and get(big).resp_body == disk(big)

    assert StaticCache.stats().entries == 2,
           "an entry larger than the budget is served but not admitted"

    StaticCache.configure(both_bytes - 1)
    assert get(small, gzip).status == 200
    assert get(other, gzip).status == 200
    stats = StaticCache.stats()
    assert stats.entries == 1 and stats.bytes == both_bytes - small_bytes
    assert get(small).resp_body == disk(small)
  end

  test "a gzip body that does not fit is served but not kept" do
    assert get(css()).status == 200
    body_bytes = StaticCache.stats().bytes
    StaticCache.configure(body_bytes + 16)
    assert get(css()).status == 200
    assert :zlib.gunzip(get(css(), [{"accept-encoding", "gzip"}]).resp_body) == disk(css())
    assert StaticCache.stats().bytes == body_bytes
  end

  test "a zero budget serves everything without admitting anything" do
    StaticCache.configure(0)
    assert get(css()).status == 200 and get(css()).resp_body == disk(css())
    assert :zlib.gunzip(get(css(), [{"accept-encoding", "gzip"}]).resp_body) == disk(css())
    assert StaticCache.stats() == %{entries: 0, bytes: 0, limit: 0}
  end
end
