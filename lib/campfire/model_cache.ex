defmodule Campfire.ModelCache do
  @moduledoc "Active Record cache keys and controller model validators."
  import Plug.Conn
  @external_resource "vectors/image-etags.json"
  @avatar_digest Jason.decode!(File.read!(@external_resource))["Users::AvatarsController"][
                   "digest"
                 ]

  @external_resource "vectors/message-etags.json"
  @messages_digest Jason.decode!(File.read!("vectors/message-etags.json"))["digest"]

  def collection(conn, records) do
    {_, data} = Campfire.Auth.csrf_session(conn)
    flash = get_in(data, ["flash", "flashes"]) || %{}
    keys = Enum.map(records, &cache_key("messages", &1))

    keys =
      if Enum.any?(Campfire.ResponseFormats.requested(conn), &(&1 in ["html", "all"])),
        do: keys ++ [@messages_digest],
        else: keys

    keys = keys ++ Enum.flat_map(flash, fn {name, value} -> [name, to_string(value)] end)

    digest =
      :crypto.hash(:sha256, Enum.join(keys, "/"))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 32)

    modified =
      records |> Enum.map(& &1["updated_at"]) |> Enum.reject(&is_nil/1) |> Enum.max(fn -> nil end)

    conn =
      conn
      |> assign(:controller_validator, true)
      |> put_resp_header("etag", ~s(W/"#{digest}"))
      |> put_resp_header("cache-control", "max-age=0, private, must-revalidate")

    if modified do
      {:ok, datetime, _} = DateTime.from_iso8601(String.replace(modified, " ", "T") <> "Z")

      put_resp_header(
        conn,
        "last-modified",
        Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S GMT")
      )
    else
      conn
    end
  end

  defp cache_key(table, record) do
    version = record["updated_at"] || record["created_at"]

    if version do
      stamp = version |> String.replace(~r/[^0-9]/, "") |> String.pad_trailing(20, "0")
      "#{table}/#{record["id"]}-#{stamp}"
    else
      "#{table}/#{record["id"]}"
    end
  end

  def stale(conn, table, record)
  def stale(conn, _, nil), do: {:stale, conn}

  def stale(conn, table, record) do
    {_, data} = Campfire.Auth.csrf_session(conn)
    flash = get_in(data, ["flash", "flashes"]) || %{}
    svg? = Enum.any?(get_req_header(conn, "accept"), &String.contains?(&1, "image/svg+xml"))
    etag = etag(table, record, svg?, flash)

    conn =
      conn
      |> put_resp_header("etag", etag)
      |> put_resp_header("cache-control", "max-age=0, private, must-revalidate")

    matches =
      get_req_header(conn, "if-none-match")
      |> Enum.join(",")
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    fresh = etag in matches || "*" in matches

    if fresh,
      do: {:fresh, conn |> put_resp_header("cache-control", "no-cache") |> send_resp(304, "")},
      else: {:stale, conn}
  end

  def etag(table, record, svg? \\ false, flash \\ %{}) do
    key = cache_key(table, record)
    key = if table == "users" && svg?, do: key <> "/" <> @avatar_digest, else: key

    key =
      Enum.reduce(flash, key, fn {name, value}, acc ->
        acc <> "/" <> name <> "/" <> to_string(value)
      end)

    digest = :crypto.hash(:sha256, key) |> Base.encode16(case: :lower) |> binary_part(0, 32)
    ~s(W/"#{digest}")
  end
end
